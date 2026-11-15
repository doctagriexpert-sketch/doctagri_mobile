"""
TERRA-ORBIT TOGO - NASA SMAP & ECOSTRESS Downscaling Engine
Algorithme de désagrégation spatiale (downscaling) physique de l'humidité du sol
de 9-36 km à 30 m par fusion multi-capteurs :
- NASA SMAP L3 (Humidité micro-ondes Bande L, 9-36 km, profondeur 0-5 cm)
- NASA ECOSTRESS L2/L4 (Température de surface Ts à 70 m & Indice ESI ET/PET)
- Copernicus Sentinel-2 / Landsat (NDVI / NDWI à 10-30 m)
- NASA SRTM (Modèle numérique de terrain, pente, indice d'humidité TWI, 30 m)

Fondements physiques :
1. Triangle Température-Végétation (TVDI - Sandholt et al. 2002, Carlson et al. 1994)
2. Efficacité évaporative du sol (SEE / DISPATCH - Merlin et al. 2008, 2013)
3. Indice topographique d'humidité (TWI - Beven & Kirkby 1979)
4. Conservation de masse coarse-to-fine sur l'empreinte SMAP
5. Calibration pédologique adaptée aux 5 régions agro-écologiques du Togo.
"""

from typing import Dict, Optional, Union
import numpy as np
import pandas as pd


# Calibration agro-pédologique des 5 régions du Togo
REGION_PEDOLOGY: Dict[str, dict] = {
    "Savanes": {
        "soil_type": "Sols ferrugineux tropicaux lessivés (faible rétention)",
        "pwp": 0.07,         # Point de flétrissement permanent (m3/m3)
        "fc": 0.23,          # Capacité au champ (m3/m3)
        "sat": 0.38,         # Porosité / saturation (m3/m3)
        "tvdi_ref": 0.52,    # TVDI moyen régional
        "twi_ref": 7.8,      # TWI médian régional (pente moyenne 2.1°)
        "lst_min": 24.0,     # Température ligne humide (°C)
        "lst_max": 48.0,     # Température ligne sèche sol nu (°C)
        "dry_slope": 17.0,   # Pente de la ligne sèche (Ts_max - b * NDVI)
        "wet_slope": 1.5,    # Pente de la ligne humide
    },
    "Kara": {
        "soil_type": "Vertisols et lithosols sur roches cristallines",
        "pwp": 0.13,
        "fc": 0.33,
        "sat": 0.44,
        "tvdi_ref": 0.48,
        "twi_ref": 7.2,      # Pente forte 5.8°, ruissellement plus rapide
        "lst_min": 22.0,
        "lst_max": 46.0,
        "dry_slope": 16.0,
        "wet_slope": 1.5,
    },
    "Centrale": {
        "soil_type": "Sols ferrugineux tropicaux profonds",
        "pwp": 0.09,
        "fc": 0.27,
        "sat": 0.40,
        "tvdi_ref": 0.46,
        "twi_ref": 8.2,
        "lst_min": 22.0,
        "lst_max": 44.0,
        "dry_slope": 15.5,
        "wet_slope": 1.5,
    },
    "Plateaux": {
        "soil_type": "Sols ferrallitiques rouges et bruns profonds",
        "pwp": 0.12,
        "fc": 0.34,
        "sat": 0.46,
        "tvdi_ref": 0.42,
        "twi_ref": 8.8,
        "lst_min": 20.0,
        "lst_max": 42.0,
        "dry_slope": 15.0,
        "wet_slope": 1.8,
    },
    "Maritime": {
        "soil_type": "Terres de barre (sols ferrallitiques sablo-argileux)",
        "pwp": 0.08,
        "fc": 0.26,
        "sat": 0.40,
        "tvdi_ref": 0.50,
        "twi_ref": 8.6,
        "lst_min": 23.0,
        "lst_max": 44.0,
        "dry_slope": 16.0,
        "wet_slope": 1.5,
    }
}

# Baseline universelle tropicale par défaut
DEFAULT_PEDOLOGY = {
    "soil_type": "Sol tropical standard non différencié",
    "pwp": 0.10,
    "fc": 0.30,
    "sat": 0.42,
    "tvdi_ref": 0.50,
    "twi_ref": 8.5,
    "lst_min": 24.0,
    "lst_max": 46.0,
    "dry_slope": 16.5,
    "wet_slope": 1.5,
}


class MultiSensorDownscaler:
    """
    Moteur de super-résolution spatiale basé sur le principe physique
    de l'Inertie Thermique Apparente (ATI), du Triangle Température-Végétation (TVDI)
    et de la redistribution hydrologique de pente (TWI SRTM 30m).
    """

    @classmethod
    def get_pedology(cls, region_name: Optional[str] = None) -> dict:
        """Retourne les paramètres pédologiques régionaux calibrés pour le Togo."""
        if region_name and region_name in REGION_PEDOLOGY:
            return REGION_PEDOLOGY[region_name]
        return DEFAULT_PEDOLOGY

    @staticmethod
    def compute_tvdi(
        lst_ecostress: Union[float, np.ndarray],
        ndvi: Union[float, np.ndarray],
        lst_min: float = 24.0,
        lst_max: float = 46.0,
        dry_slope: float = 16.5,
        wet_slope: float = 1.5,
        ecostress_esi: Optional[Union[float, np.ndarray]] = None,
        esi_weight: float = 0.30
    ) -> Union[float, np.ndarray]:
        """
        Calcule le Temperature-Vegetation Dryness Index (TVDI) de Sandholt et al. (2002).
        Formule physique : TVDI = (Ts - Ts_min(NDVI)) / (Ts_max(NDVI) - Ts_min(NDVI))
        - Ts_min : Ligne humide (évapotranspiration potentielle, eau non limitante)
        - Ts_max : Ligne sèche (évapotranspiration nulle, fermeture stomatique complète)

        Paramètres enrichis :
        - dry_slope : gradient thermique de la ligne sèche (refroidissement du feuillage vs sol nu)
        - wet_slope : gradient thermique de la ligne humide
        - ecostress_esi : Indice de stress évaporatif L4 ECOSTRESS (ET/PET) optionnel pour fusion directe
        """
        is_scalar = np.isscalar(lst_ecostress) and np.isscalar(ndvi)
        lst_arr = np.atleast_1d(np.asarray(lst_ecostress, dtype=float))
        ndvi_arr = np.atleast_1d(np.asarray(ndvi, dtype=float))

        # Borne physique de l'indice de végétation
        ndvi_clipped = np.clip(ndvi_arr, 0.0, 0.95)

        # Équations des bordures sèche et humide du trapèze
        dry_edge = lst_max - (dry_slope * ndvi_clipped)
        wet_edge = lst_min + (wet_slope * ndvi_clipped)

        # Marge thermodynamique minimale pour éviter singularité ou division par zéro
        min_delta_t = 1.5
        dry_edge = np.maximum(dry_edge, wet_edge + min_delta_t)

        tvdi_thermal = (lst_arr - wet_edge) / (dry_edge - wet_edge)
        tvdi_thermal = np.clip(tvdi_thermal, 0.0, 1.0)

        # Fusion optionnelle avec l'indice de stress évaporatif ECOSTRESS L4 (ESI = ET / PET)
        # Si ESI est fourni : TVDI_esi = 1 - ESI
        if ecostress_esi is not None:
            esi_arr = np.atleast_1d(np.asarray(ecostress_esi, dtype=float))
            tvdi_esi = np.clip(1.0 - esi_arr, 0.0, 1.0)
            w = float(np.clip(esi_weight, 0.0, 1.0))
            tvdi_final = (1.0 - w) * tvdi_thermal + w * tvdi_esi
        else:
            tvdi_final = tvdi_thermal

        tvdi_final = np.clip(tvdi_final, 0.0, 1.0)
        return float(tvdi_final[0]) if is_scalar else tvdi_final

    @staticmethod
    def compute_twi(
        slope_deg: Union[float, np.ndarray],
        catchment_area_m2: Union[float, np.ndarray] = 2500.0,
        contour_width_m: float = 30.0,
        min_slope_deg: float = 0.1
    ) -> Union[float, np.ndarray]:
        """
        Calcule l'indice topographique d'humidité (Topographic Wetness Index - TWI) issu de SRTM 30m.
        Formule rigoureuse de Beven & Kirkby (1979) :
        TWI = ln( a / tan(beta) )
        - a : Aire drainée spécifique en mètres = A_amont / largeur de contour (w = 30m pour SRTM 1 arc-second)
        - beta : Angle de pente locale en radians
        - min_slope_deg : Seuil hydrologique minimal (0.1°) pour éviter la divergence sur plaines inondables.
        """
        is_scalar = np.isscalar(slope_deg) and np.isscalar(catchment_area_m2)
        slope_arr = np.atleast_1d(np.asarray(slope_deg, dtype=float))
        area_arr = np.atleast_1d(np.asarray(catchment_area_m2, dtype=float))

        # Aire spécifique a (m2 / m = m). Si une cellule draine au moins elle-même : A >= w^2 ou w
        w = max(1.0, float(contour_width_m))
        a_specific = np.maximum(w, area_arr) / w

        # Angle de pente borné hydrologiquement
        slope_eff_deg = np.maximum(min_slope_deg, slope_arr)
        slope_rad = np.radians(slope_eff_deg)

        # Calcul TWI
        tan_slope = np.maximum(1e-4, np.tan(slope_rad))
        twi = np.log(a_specific / tan_slope)
        twi = np.clip(twi, 3.0, 16.0)

        return float(twi[0]) if is_scalar else twi

    @staticmethod
    def compute_see(tvdi: Union[float, np.ndarray]) -> Union[float, np.ndarray]:
        """
        Efficacité Évaporative du Sol (Soil Evaporative Efficiency - SEE).
        Principe DISPATCH (Merlin et al., 2008) : SEE = 1 - TVDI.
        """
        return np.clip(1.0 - tvdi, 0.0, 1.0)

    @classmethod
    def downscale_soil_moisture(
        cls,
        smap_sm_coarse: float,               # Humidité volumique SMAP (m3/m3, typiquement 0.05 à 0.45)
        ecostress_lst: float,                # Température de surface LST (°C)
        ndvi: float,                         # Indice de végétation Sentinel-2 / Landsat (0.05 à 0.85)
        slope_deg: float,                    # Pente en degrés (SRTM 30m)
        region_name: Optional[str] = None,   # Nom de région togolaise pour calibration pédologique
        catchment_area_m2: float = 2500.0,   # Aire contributive amont SRTM (m2)
        ecostress_esi: Optional[float] = None, # Indice ESI ECOSTRESS optionnel
        alpha: float = 0.35,                 # Poids de l'anomalie thermique évaporative
        beta: float = 0.12,                  # Poids de l'effet topographique de redistribution
        pwp_override: Optional[float] = None,# Surcharge manuelle du point de flétrissement
        fc_override: Optional[float] = None  # Surcharge manuelle de la capacité au champ
    ) -> dict:
        """
        Désagrège l'humidité SMAP à la parcelle (résolution 30m).
        Formule physique unifiée :
        theta_30m = theta_SMAP * [ 1 - alpha * (TVDI - TVDI_ref) + beta * (TWI - TWI_ref) / TWI_ref ]

        Garantit :
        - Prise en compte de la pédologie régionale togolaise (Savanes, Kara, Centrale, Plateaux, Maritime).
        - Respect des bornes thermodynamiques de flétrissement et de saturation.
        - Calcul de l'Eau Disponible pour la Plante (PAW) et diagnostic du risque de faux départ de semis.
        """
        pedo = cls.get_pedology(region_name)

        pwp = float(pwp_override if pwp_override is not None else pedo["pwp"])
        fc = float(fc_override if fc_override is not None else pedo["fc"])
        sat = float(pedo["sat"])

        tvdi_ref = float(pedo["tvdi_ref"])
        twi_ref = float(pedo["twi_ref"])

        # Calculs des prédicteurs physiques haute résolution
        tvdi = cls.compute_tvdi(
            lst_ecostress=ecostress_lst,
            ndvi=ndvi,
            lst_min=pedo["lst_min"],
            lst_max=pedo["lst_max"],
            dry_slope=pedo["dry_slope"],
            wet_slope=pedo["wet_slope"],
            ecostress_esi=ecostress_esi
        )

        twi = cls.compute_twi(
            slope_deg=slope_deg,
            catchment_area_m2=catchment_area_m2,
            contour_width_m=30.0
        )

        # Facteur de correction physique unifié
        twi_anomaly = (twi - twi_ref) / max(0.1, twi_ref)
        correction_factor = 1.0 - alpha * (tvdi - tvdi_ref) + beta * twi_anomaly
        sm_fine = smap_sm_coarse * correction_factor

        # Contraintes physiques de saturation et de sécheresse résiduelle du sol
        min_sm = max(0.02, 0.5 * pwp)
        max_sm = sat
        sm_fine = float(np.clip(sm_fine, min_sm, max_sm))

        # Eau Disponible pour la Plante (Plant Available Water - PAW en %)
        # PAW = 100 * (theta - PWP) / (FC - PWP)
        denom_paw = max(0.02, fc - pwp)
        paw_percent = max(0.0, min(100.0, ((sm_fine - pwp) / denom_paw) * 100.0))

        # Évaluation agronomique de la fenêtre de semis sécurisée
        if paw_percent < 25.0 or sm_fine <= pwp:
            stress_level = "SÉVÈRE (Risque élevé de brûlure des jeunes pousses)"
            seed_safe = False
            agronomic_advice = "Semis déconseillé : réserve utile critique. Risque d'incinération des semences en cas de pause pluviométrique."
        elif paw_percent < 50.0:
            stress_level = "MODÉRÉ (Surveillance requise)"
            seed_safe = (paw_percent >= 40.0)
            agronomic_advice = "Semis conditionnel : acceptable pour céréales rustiques (Sorgho) ou légumineuses précoces, surveiller le cumul sous 48h."
        elif sm_fine >= (sat * 0.95):
            stress_level = "SATURÉ (Risque d'asphyxie racinaire sur bas-fonds non drainés)"
            seed_safe = True
            agronomic_advice = "Sol à saturation hydrique : favorable au riz ou igname, risque d'hypoxie racinaire pour le maïs en zone mal drainée."
        else:
            stress_level = "OPTIMAL (Sol hydraté en profondeur)"
            seed_safe = True
            agronomic_advice = "Fenêtre de semis idéale : humidité adéquate pour levée vigoureuse et développement racinaire initial."

        see = cls.compute_see(tvdi)

        return {
            "smap_coarse_m3m3": round(smap_sm_coarse, 3),
            "sm_fine_30m_m3m3": round(sm_fine, 3),
            "sm_percentage": round(sm_fine * 100.0, 1),
            "tvdi": round(tvdi, 3),
            "twi": round(twi, 2),
            "paw_percent": round(paw_percent, 1),
            "stress_level": stress_level,
            "seed_safe": seed_safe,
            "evaporative_efficiency": round(float(see), 3),
            "correction_factor": round(float(correction_factor), 3),
            "region": region_name or "Standard (Togo)",
            "soil_parameters": {
                "soil_type": pedo["soil_type"],
                "pwp": round(pwp, 3),
                "fc": round(fc, 3),
                "sat": round(sat, 3)
            },
            "agronomic_advice": agronomic_advice
        }

    @classmethod
    def downscale_spatial_grid(
        cls,
        smap_sm_coarse: float,
        lst_grid: np.ndarray,
        ndvi_grid: np.ndarray,
        slope_grid: np.ndarray,
        region_name: Optional[str] = None,
        catchment_grid: Optional[np.ndarray] = None,
        alpha: float = 0.35,
        beta: float = 0.12,
        enforce_mass_conservation: bool = True
    ) -> dict:
        """
        Désagrégation spatiale complète sur grille 2D (raster 30m couvrant une maille SMAP ou un bassin-versant).
        Applique le principe de conservation de la masse coarse-to-fine :
        moyenne(theta_30m) == theta_SMAP.
        """
        pedo = cls.get_pedology(region_name)
        pwp = float(pedo["pwp"])
        fc = float(pedo["fc"])
        sat = float(pedo["sat"])

        tvdi_grid = cls.compute_tvdi(
            lst_ecostress=lst_grid,
            ndvi=ndvi_grid,
            lst_min=pedo["lst_min"],
            lst_max=pedo["lst_max"],
            dry_slope=pedo["dry_slope"],
            wet_slope=pedo["wet_slope"]
        )

        catchment = catchment_grid if catchment_grid is not None else np.full_like(slope_grid, 2500.0)
        twi_grid = cls.compute_twi(
            slope_deg=slope_grid,
            catchment_area_m2=catchment,
            contour_width_m=30.0
        )

        tvdi_ref = float(np.mean(tvdi_grid))
        twi_ref = float(np.mean(twi_grid))

        twi_anom = (twi_grid - twi_ref) / max(0.1, twi_ref)
        correction = 1.0 - alpha * (tvdi_grid - tvdi_ref) + beta * twi_anom
        sm_fine_raw = smap_sm_coarse * correction

        if enforce_mass_conservation:
            mean_raw = float(np.mean(sm_fine_raw))
            if mean_raw > 1e-4:
                sm_fine = sm_fine_raw * (smap_sm_coarse / mean_raw)
            else:
                sm_fine = sm_fine_raw
        else:
            sm_fine = sm_fine_raw

        sm_fine = np.clip(sm_fine, max(0.02, 0.5 * pwp), sat)
        paw_grid = np.clip(((sm_fine - pwp) / max(0.02, fc - pwp)) * 100.0, 0.0, 100.0)

        return {
            "sm_fine_grid": sm_fine,
            "paw_grid": paw_grid,
            "tvdi_grid": tvdi_grid,
            "twi_grid": twi_grid,
            "coarse_smap": smap_sm_coarse,
            "mean_sm_fine": round(float(np.mean(sm_fine)), 4),
            "std_sm_fine": round(float(np.std(sm_fine)), 4),
            "min_sm_fine": round(float(np.min(sm_fine)), 4),
            "max_sm_fine": round(float(np.max(sm_fine)), 4),
            "mean_paw_percent": round(float(np.mean(paw_grid)), 1),
            "mass_balance_residual": round(float(abs(np.mean(sm_fine) - smap_sm_coarse)), 6)
        }
