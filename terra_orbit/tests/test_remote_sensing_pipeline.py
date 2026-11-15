"""
TERRA-ORBIT TOGO - Remote Sensing & Geospatial AI Pipeline Tests
Validation approfondie du moteur de super-résolution spatiale SMAP-ECOSTRESS
et du client agroclimatique NASA POWER.
"""

import pytest
import numpy as np
import pandas as pd

from terra_orbit.pipeline.earthdata_smap_ecostress import (
    MultiSensorDownscaler,
    REGION_PEDOLOGY,
    DEFAULT_PEDOLOGY
)
from terra_orbit.pipeline.nasa_power_client import NASAPowerClient


class TestTVDI:
    """Validation mathématique et physique du Temperature-Vegetation Dryness Index (TVDI)."""

    def test_tvdi_bounds_and_extremes(self):
        # Température sur la ligne humide (Ts <= wet_edge) => TVDI = 0.0
        tvdi_wet = MultiSensorDownscaler.compute_tvdi(lst_ecostress=24.0, ndvi=0.5, lst_min=24.0, lst_max=46.0)
        assert tvdi_wet == 0.0

        # Température sur la ligne sèche (Ts >= dry_edge) => TVDI = 1.0
        # Pour ndvi=0.5, dry_edge = 46.0 - (16.5 * 0.5) = 37.75 °C
        tvdi_dry = MultiSensorDownscaler.compute_tvdi(lst_ecostress=45.0, ndvi=0.5, lst_min=24.0, lst_max=46.0)
        assert tvdi_dry == 1.0

        # Température médiane => TVDI ~ 0.5
        tvdi_mid = MultiSensorDownscaler.compute_tvdi(lst_ecostress=31.25, ndvi=0.5, lst_min=24.0, lst_max=46.0)
        assert 0.40 <= tvdi_mid <= 0.60

    def test_tvdi_cooling_with_vegetation(self):
        # À même LST (35°C), un sol nu (NDVI=0.1) est plus proche de sa ligne humide qu'un couvert dense (NDVI=0.8)
        tvdi_bare = MultiSensorDownscaler.compute_tvdi(lst_ecostress=35.0, ndvi=0.1)
        tvdi_dense = MultiSensorDownscaler.compute_tvdi(lst_ecostress=35.0, ndvi=0.8)
        # Un couvert végétal dense à 35°C est en fort stress thermique foliaire
        assert tvdi_dense > tvdi_bare

    def test_tvdi_with_ecostress_esi_fusion(self):
        # ESI élevé (ET/PET proche de 1.0) réduit le TVDI final (humidité transpiratoire)
        tvdi_no_esi = MultiSensorDownscaler.compute_tvdi(lst_ecostress=36.0, ndvi=0.5)
        tvdi_with_high_esi = MultiSensorDownscaler.compute_tvdi(
            lst_ecostress=36.0, ndvi=0.5, ecostress_esi=0.90, esi_weight=0.35
        )
        assert tvdi_with_high_esi < tvdi_no_esi

    def test_tvdi_vectorized(self):
        lst_arr = np.array([25.0, 32.0, 42.0])
        ndvi_arr = np.array([0.2, 0.5, 0.8])
        tvdi_arr = MultiSensorDownscaler.compute_tvdi(lst_arr, ndvi_arr)
        assert isinstance(tvdi_arr, np.ndarray)
        assert len(tvdi_arr) == 3
        assert np.all((tvdi_arr >= 0.0) & (tvdi_arr <= 1.0))


class TestTWI:
    """Validation de l'indice topographique d'humidité (TWI) issu de SRTM 30m."""

    def test_twi_formula_rigor(self):
        # Pente douce (Savanes 2.1°) avec aire contributive standard
        twi_savanes = MultiSensorDownscaler.compute_twi(slope_deg=2.1, catchment_area_m2=2500.0, contour_width_m=30.0)
        # a = 2500/30 = 83.33m ; tan(2.1°) = 0.03668 => ln(83.33 / 0.03668) ~ 7.73
        assert 7.5 <= twi_savanes <= 8.0

        # Pente forte de montagne (Monts Kabyè à Kara 15.0°) => drainage rapide, TWI plus faible
        twi_kara = MultiSensorDownscaler.compute_twi(slope_deg=15.0, catchment_area_m2=2500.0, contour_width_m=30.0)
        assert twi_kara < twi_savanes
        assert 5.0 <= twi_kara <= 6.5

        # Dépression / bas-fond alluvionnaire (0.3° de pente, grande aire amont 15000 m2) => TWI élevé
        twi_depression = MultiSensorDownscaler.compute_twi(slope_deg=0.3, catchment_area_m2=15000.0, contour_width_m=30.0)
        assert twi_depression > 10.0

    def test_twi_near_zero_slope_safety(self):
        # Pente nulle ou négative ne doit pas causer d'erreur mathématique (division par zéro)
        twi_flat = MultiSensorDownscaler.compute_twi(slope_deg=0.0)
        assert not np.isnan(twi_flat)
        assert not np.isinf(twi_flat)
        assert twi_flat <= 16.0

    def test_twi_vectorized(self):
        slopes = np.array([1.5, 5.0, 12.0, 25.0])
        twis = MultiSensorDownscaler.compute_twi(slopes)
        assert isinstance(twis, np.ndarray)
        assert len(twis) == 4
        # TWI doit décroître avec la pente
        assert np.all(np.diff(twis) < 0)


class TestDownscalingEngine:
    """Validation du moteur de désagrégation spatiale SMAP 9-36km -> 30m."""

    def test_downscale_regional_pedology(self):
        for region in ["Savanes", "Kara", "Centrale", "Plateaux", "Maritime"]:
            res = MultiSensorDownscaler.downscale_soil_moisture(
                smap_sm_coarse=0.18,
                ecostress_lst=35.0,
                ndvi=0.55,
                slope_deg=3.0,
                region_name=region
            )
            assert "smap_coarse_m3m3" in res
            assert "sm_fine_30m_m3m3" in res
            assert "sm_percentage" in res
            assert "tvdi" in res
            assert "twi" in res
            assert "paw_percent" in res
            assert "stress_level" in res
            assert "seed_safe" in res
            assert "soil_parameters" in res
            assert res["region"] == region

            # Vérification des bornes physiques pédologiques
            pwp = res["soil_parameters"]["pwp"]
            sat = res["soil_parameters"]["sat"]
            assert res["sm_fine_30m_m3m3"] >= 0.02
            assert res["sm_fine_30m_m3m3"] <= sat

    def test_sowing_safety_logic(self):
        # Cas 1 : Sol très sec (smap=0.06, LST élevé 43°C, NDVI bas 0.15) => Risque faux départ
        res_dry = MultiSensorDownscaler.downscale_soil_moisture(
            smap_sm_coarse=0.06,
            ecostress_lst=43.0,
            ndvi=0.15,
            slope_deg=3.0,
            region_name="Savanes"
        )
        assert res_dry["seed_safe"] is False
        assert "SÉVÈRE" in res_dry["stress_level"]
        assert res_dry["paw_percent"] < 25.0

        # Cas 2 : Sol bien hydraté (smap=0.22, LST tempéré 27°C, bon NDVI 0.65) => Semis optimal
        res_wet = MultiSensorDownscaler.downscale_soil_moisture(
            smap_sm_coarse=0.22,
            ecostress_lst=27.0,
            ndvi=0.65,
            slope_deg=2.0,
            region_name="Savanes"
        )
        assert res_wet["seed_safe"] is True
        assert "OPTIMAL" in res_wet["stress_level"]
        assert res_wet["paw_percent"] >= 50.0

    def test_spatial_grid_mass_conservation(self):
        smap_coarse = 0.19
        np.random.seed(123)
        h, w = 20, 20  # 400 pixels 30m représentant ~600m x 600m
        lst_grid = 36.0 + np.random.normal(0, 2.5, (h, w))
        ndvi_grid = np.clip(0.50 + np.random.normal(0, 0.12, (h, w)), 0.1, 0.85)
        slope_grid = np.clip(3.0 + np.random.exponential(2.0, (h, w)), 0.2, 20.0)

        grid_res = MultiSensorDownscaler.downscale_spatial_grid(
            smap_sm_coarse=smap_coarse,
            lst_grid=lst_grid,
            ndvi_grid=ndvi_grid,
            slope_grid=slope_grid,
            region_name="Plateaux",
            enforce_mass_conservation=True
        )

        assert grid_res["sm_fine_grid"].shape == (h, w)
        # La moyenne spatiale à 30m doit correspondre au pixel grossier SMAP (conservation de masse)
        assert abs(grid_res["mean_sm_fine"] - smap_coarse) < 1e-4
        assert grid_res["mass_balance_residual"] < 1e-4
        # Présence d'hétérogénéité spatiale à la parcelle (std > 0)
        assert grid_res["std_sm_fine"] > 0.005


class TestNASAPowerClient:
    """Validation du client agroclimatique NASA POWER et des calculs FAO-56."""

    def test_fao56_extraterrestrial_radiation(self):
        # Lomé (6.4°N) au solstice d'été (DOY 172)
        ra_lome = NASAPowerClient.calculate_extraterrestrial_radiation(lat_deg=6.4, day_of_year=172)
        assert 35.0 <= ra_lome <= 39.0

        # Dapaong (10.86°N) en janvier (DOY 15)
        ra_dapaong = NASAPowerClient.calculate_extraterrestrial_radiation(lat_deg=10.86, day_of_year=15)
        assert 30.0 <= ra_dapaong <= 34.0

    def test_hargreaves_et0_bounds(self):
        # Températures sahéliennes typiques
        et0 = NASAPowerClient._calculate_et0_hargreaves(
            t_mean=28.5,
            t_max=36.0,
            t_min=21.0,
            lat_deg=9.5,
            day_of_year=120
        )
        assert 4.0 <= et0 <= 6.5

    def test_penman_monteith_calculation(self):
        et0_pm = NASAPowerClient.calculate_et0_penman_monteith(
            t_mean=27.0,
            t_max=33.0,
            t_min=21.0,
            solar_rad_mj=20.0,
            rh_percent=65.0,
            wind_speed_m_s=1.8,
            altitude_m=310.0
        )
        assert 3.5 <= et0_pm <= 6.0

    def test_fallback_data_generator_regimes(self):
        # Savanes : Régime monomodal
        df_savanes = NASAPowerClient._generate_fallback_data(
            lat=10.86, lon=0.20,
            start_date="20240101", end_date="20241231",
            region_name="Savanes"
        )
        assert len(df_savanes) == 366
        assert "et0_mm" in df_savanes.columns
        assert "wind_speed" in df_savanes.columns
        # Pluviométrie en août (coeur de saison des pluies) doit être supérieure à janvier (Harmattan)
        rain_aug = df_savanes[df_savanes["date"].dt.month == 8]["precipitation"].sum()
        rain_jan = df_savanes[df_savanes["date"].dt.month == 1]["precipitation"].sum()
        assert rain_aug > rain_jan

        # Maritime : Régime bimodal
        df_maritime = NASAPowerClient._generate_fallback_data(
            lat=6.42, lon=1.21,
            start_date="20240101", end_date="20241231",
            region_name="Maritime"
        )
        assert len(df_maritime) == 366
        # La grande saison (Juin) a plus de pluie qu'août (petit sec littoral)
        rain_jun = df_maritime[df_maritime["date"].dt.month == 6]["precipitation"].sum()
        rain_aug_mar = df_maritime[df_maritime["date"].dt.month == 8]["precipitation"].sum()
        assert rain_jun > rain_aug_mar
