"""
TERRA-ORBIT TOGO - NASA POWER Agroclimatology Client
Récupération des séries temporelles réelles d'insolation, température,
évapotranspiration et précipitations via l'API officielle NASA POWER.

Implémente :
1. Extraction NRT (Near Real-Time) multi-paramètres (PRECTOTCORR, T2M, T2M_MAX, T2M_MIN, ALLSKY_SFC_SW_DWN, RH2M, WS2M)
2. Filtrage rigoureux des valeurs sentinelles NASA (-999.0) et imputation sans biais
3. Calcul physique de l'évapotranspiration de référence ET0 (FAO-56 Hargreaves-Samani & Penman-Monteith)
4. Générateur climatologique de secours (Fallback) fidèlement calibré sur les 5 régimes agro-écologiques du Togo.
"""

from typing import Optional
import datetime
import requests
import numpy as np
import pandas as pd


class NASAPowerClient:
    """Client d'accès aux données agroclimatiques ouvertes NASA POWER pour l'Afrique de l'Ouest."""

    BASE_URL = "https://power.larc.nasa.gov/api/temporal/daily/point"

    @staticmethod
    def calculate_extraterrestrial_radiation(lat_deg: float, day_of_year: int) -> float:
        """
        Calcule le rayonnement extraterrestre journalier Ra (MJ/m2/jour) selon la norme FAO-56.
        Formules astronomiques (Allen et al. 1998, FAO Irrigation and Drainage Paper No. 56) :
        - Déclinaison solaire delta
        - Distance relative Terre-Soleil dr
        - Angle horaire au coucher du soleil ws
        """
        lat_rad = np.radians(lat_deg)
        dr = 1.0 + 0.033 * np.cos(2.0 * np.pi * day_of_year / 365.0)
        delta = 0.409 * np.sin((2.0 * np.pi * day_of_year / 365.0) - 1.39)

        # Cosinus de l'angle horaire au coucher
        x = -np.tan(lat_rad) * np.tan(delta)
        ws = np.arccos(np.clip(x, -1.0, 1.0))

        # Constante solaire Gsc = 0.0820 MJ/m2/min
        gsc = 0.0820
        ra = (24.0 * 60.0 / np.pi) * gsc * dr * (
            ws * np.sin(lat_rad) * np.sin(delta) + np.cos(lat_rad) * np.cos(delta) * np.sin(ws)
        )
        return float(max(10.0, ra))

    @classmethod
    def _calculate_et0_hargreaves(
        cls,
        t_mean: float,
        t_max: float,
        t_min: float,
        solar_rad: Optional[float] = None,
        lat_deg: Optional[float] = None,
        day_of_year: Optional[int] = None
    ) -> float:
        """
        Formule FAO-56 Hargreaves-Samani pour l'ET0 journalière en zone tropicale :
        ET0 = 0.0023 * (0.408 * Ra) * (T_mean + 17.8) * sqrt(T_max - T_min)
        - Ra : Rayonnement extraterrestre (MJ/m2/jour), équivalent évaporatif = Ra * 0.408 mm/jour.
        Si lat_deg ou day_of_year n'est pas fourni, utilise un Ra tropical standard ou solar_rad ajusté.
        """
        try:
            td = max(0.2, float(t_max) - float(t_min))
            tm = float(t_mean)

            if lat_deg is not None and day_of_year is not None:
                ra = cls.calculate_extraterrestrial_radiation(lat_deg, day_of_year)
            elif solar_rad is not None and solar_rad > 0:
                # Approximation : Ra tropical moyen ~ solar_rad / 0.55 à 0.65
                ra = float(solar_rad) / 0.60
            else:
                ra = 34.5  # Moyenne tropicale Ouest-Africaine (~8°N)

            ra_mm = ra * 0.408  # Conversion MJ/m2/jour en mm/jour équivalent évaporatif
            et0 = 0.0023 * ra_mm * (tm + 17.8) * np.sqrt(td)
            return float(np.clip(et0, 1.5, 8.5))
        except Exception:
            return 4.5  # Moyenne sahélienne/tropicale par défaut

    @classmethod
    def calculate_et0_penman_monteith(
        cls,
        t_mean: float,
        t_max: float,
        t_min: float,
        solar_rad_mj: float,
        rh_percent: float,
        wind_speed_m_s: float = 1.5,
        altitude_m: float = 250.0
    ) -> float:
        """
        Calcul standard FAO-56 Penman-Monteith de référence (WMO / FAO-56).
        Combine le bilan radiatif et le pouvoir asséchant de l'air.
        """
        try:
            tm = float(t_mean)
            tmax = float(t_max)
            tmin = float(t_min)
            rs = max(2.0, float(solar_rad_mj))
            rh = float(np.clip(rh_percent, 5.0, 100.0))
            u2 = max(0.5, float(wind_speed_m_s))

            # Pression atmosphérique locale (kPa)
            p = 101.3 * (((293.0 - 0.0065 * altitude_m) / 293.0) ** 5.26)
            # Constante psychrométrique (kPa/°C)
            gamma = 0.000665 * p

            # Pente de la courbe de pression de vapeur saturante Delta (kPa/°C)
            delta = (4098.0 * (0.6108 * np.exp((17.27 * tm) / (tm + 237.3)))) / ((tm + 237.3) ** 2)

            # Pression de vapeur saturante es (kPa)
            e_tmax = 0.6108 * np.exp((17.27 * tmax) / (tmax + 237.3))
            e_tmin = 0.6108 * np.exp((17.27 * tmin) / (tmin + 237.3))
            es = (e_tmax + e_tmin) / 2.0

            # Pression de vapeur réelle ea (kPa)
            ea = es * (rh / 100.0)

            # Rayonnement net Rns (albédo sol/culture standard ~ 0.23)
            rns = (1.0 - 0.23) * rs
            # Rayonnement net de grandes ondes Rnl estimé (simplifié FAO-56)
            sigma = 4.903e-9  # Constante Stefan-Boltzmann en MJ/K4/m2/jour
            tmax_k4 = (tmax + 273.16) ** 4
            tmin_k4 = (tmin + 273.16) ** 4
            rnl = sigma * ((tmax_k4 + tmin_k4) / 2.0) * (0.34 - 0.14 * np.sqrt(max(0.1, ea))) * 0.75
            rn = max(0.0, rns - rnl)

            # Flux thermique du sol G ~ 0 sur pas journalier
            g = 0.0

            # Équation FAO-56 Penman-Monteith
            num = 0.408 * delta * (rn - g) + gamma * (900.0 / (tm + 273.0)) * u2 * (es - ea)
            den = delta + gamma * (1.0 + 0.34 * u2)
            et0 = num / den
            return float(np.clip(et0, 1.5, 8.5))
        except Exception:
            return cls._calculate_et0_hargreaves(t_mean, t_max, t_min, solar_rad_mj)

    @classmethod
    def fetch_climate_data(
        cls,
        lat: float,
        lon: float,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        timeout: int = 8,
        region_name: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Interroge l'API NASA POWER pour une coordonnée GPS donnée.
        Paramètres agroclimatiques récupérés :
        - PRECTOTCORR : Précipitations quotidiennes corrigées (mm/jour)
        - T2M : Température moyenne à 2m (°C)
        - T2M_MAX / T2M_MIN : Températures extrêmes (°C)
        - ALLSKY_SFC_SW_DWN : Rayonnement solaire global incident (MJ/m²/jour)
        - RH2M : Humidité relative à 2m (%)
        - WS2M : Vitesse du vent à 2m (m/s)

        Effectue un nettoyage complet des valeurs manquantes NASA (-999.0) et
        calcule l'ET0 selon les règles FAO-56.
        """
        today = datetime.date.today()
        if not end_date:
            # Latence standard NASA POWER Near-Real-Time : ~4-5 jours
            end_date = (today - datetime.timedelta(days=5)).strftime("%Y%m%d")
        if not start_date:
            # 120 jours d'historique de campagne par défaut
            start_date = (today - datetime.timedelta(days=125)).strftime("%Y%m%d")

        params = {
            "parameters": "PRECTOTCORR,T2M,T2M_MAX,T2M_MIN,ALLSKY_SFC_SW_DWN,RH2M,WS2M",
            "community": "AG",
            "longitude": lon,
            "latitude": lat,
            "start": start_date,
            "end": end_date,
            "format": "JSON"
        }

        # Tentative avec gestion des sessions et retry
        session = requests.Session()
        adapter = requests.adapters.HTTPAdapter(max_retries=2)
        session.mount("https://", adapter)

        try:
            resp = session.get(cls.BASE_URL, params=params, timeout=timeout)
            if resp.status_code == 200:
                data = resp.json()
                properties = data.get("properties", {}).get("parameter", {})
                dates_str = sorted(list(properties.get("T2M", {}).keys()))

                if dates_str:
                    # Extraction et filtrage des valeurs sentinelles -999.0
                    def clean_series(param_name: str, fill_default: float, min_val: float, max_val: float):
                        values = []
                        for d in dates_str:
                            val = properties.get(param_name, {}).get(d)
                            if val is None or val <= -900.0 or np.isnan(val):
                                values.append(np.nan)
                            else:
                                values.append(float(val))
                        s = pd.Series(values, dtype=float)
                        # Imputation par interpolation linéaire / bfill / ffill
                        s = s.interpolate(method="linear").bfill().ffill().fillna(fill_default)
                        return np.clip(s.values, min_val, max_val)

                    dates = pd.to_datetime(dates_str, format="%Y%m%d")
                    temp_mean = clean_series("T2M", 27.0, 10.0, 48.0)
                    temp_max = clean_series("T2M_MAX", 33.0, 15.0, 52.0)
                    temp_min = clean_series("T2M_MIN", 21.0, 5.0, 38.0)
                    # Cohérence thermodynamique des extrêmes
                    temp_max = np.maximum(temp_max, temp_mean + 0.5)
                    temp_min = np.minimum(temp_min, temp_mean - 0.5)

                    precipitation = clean_series("PRECTOTCORR", 0.0, 0.0, 300.0)
                    solar_radiation = clean_series("ALLSKY_SFC_SW_DWN", 19.0, 3.0, 35.0)
                    humidity = clean_series("RH2M", 65.0, 10.0, 100.0)
                    wind_speed = clean_series("WS2M", 1.5, 0.1, 25.0)

                    df = pd.DataFrame({
                        "date": dates,
                        "temp_mean": np.round(temp_mean, 2),
                        "temp_max": np.round(temp_max, 2),
                        "temp_min": np.round(temp_min, 2),
                        "precipitation": np.round(precipitation, 2),
                        "solar_radiation": np.round(solar_radiation, 2),
                        "humidity": np.round(humidity, 1),
                        "wind_speed": np.round(wind_speed, 2)
                    })

                    # Calcul de l'évapotranspiration journalière FAO-56
                    et0_list = []
                    for idx, row in df.iterrows():
                        doy = int(row["date"].dayofyear)
                        et0_val = cls.calculate_et0_penman_monteith(
                            t_mean=row["temp_mean"],
                            t_max=row["temp_max"],
                            t_min=row["temp_min"],
                            solar_rad_mj=row["solar_radiation"],
                            rh_percent=row["humidity"],
                            wind_speed_m_s=row["wind_speed"]
                        )
                        et0_list.append(round(et0_val, 2))

                    df["et0_mm"] = et0_list
                    df["source"] = "NASA POWER Live API"
                    return df
        except Exception:
            pass

        # Fallback hors-ligne en cas de panne réseau ou latence NRT
        return cls._generate_fallback_data(lat, lon, start_date, end_date, region_name)

    @classmethod
    def _generate_fallback_data(
        cls,
        lat: float,
        lon: float,
        start_date: str,
        end_date: str,
        region_name: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Générateur synthétique hors-ligne basé sur les normales trentenaires du Togo (Simulation non observée).
        À n'utiliser qu'en cas d'absence totale de connexion aux serveurs de la NASA.
        Respecte la typologie bimodal (Sud) vs monomodal (Nord) :
        - Savanes (lat > 10.0) / Kara (9.0 < lat <= 10.0) : Monomodal (Mai - Octobre), saison sèche rude (Harmattan)
        - Centrale (8.0 < lat <= 9.0) : Transition Guinéenne de savane
        - Plateaux (6.8 < lat <= 8.0) : Bimodal (Avril - Juillet & Septembre - Novembre), zone de forêt humide
        - Maritime (lat <= 6.8) : Bimodal littoral, anomalie sèche du Dahomey Gap (~900 mm/an).
        """
        dt_start = datetime.datetime.strptime(start_date, "%Y%m%d")
        dt_end = datetime.datetime.strptime(end_date, "%Y%m%d")
        dates = pd.date_range(dt_start, dt_end)
        n = len(dates)

        # Graine stable par coordonnées
        seed = int(abs(lat * 1000 + lon * 100)) % (2**31 - 1)
        rng = np.random.RandomState(seed)

        months = dates.month
        is_northern = (lat > 8.8) or (region_name in ["Savanes", "Kara"])
        is_coastal = (lat <= 6.8) or (region_name == "Maritime")
        is_mountain = (6.8 < lat <= 8.0) or (region_name == "Plateaux")

        # Régimes de température de base (°C)
        if is_northern:
            base_temp = 29.0
            temp_var = 2.2
            diurnal_range = 10.5
        elif is_mountain:
            base_temp = 25.5
            temp_var = 1.4
            diurnal_range = 7.5
        elif is_coastal:
            base_temp = 27.2
            temp_var = 1.6
            diurnal_range = 6.8
        else:
            base_temp = 27.5
            temp_var = 1.8
            diurnal_range = 8.5

        temps = base_temp + rng.normal(0, temp_var, n)
        t_max = temps + (diurnal_range / 2.0) + rng.uniform(0.5, 2.0, n)
        t_min = temps - (diurnal_range / 2.0) - rng.uniform(0.5, 1.8, n)

        # Modélisation des probabilités pluviométriques selon le régime
        if is_northern:
            # Monomodal (Mai à Octobre, pic Août-Septembre)
            rain_prob = np.where(
                (months >= 5) & (months <= 10),
                np.where((months == 8) | (months == 9), 0.55, 0.35),
                0.04
            )
            scale_rain = 16.0
        elif is_coastal:
            # Bimodal avec anomalie sèche du Dahomey Gap
            # Grande saison : Avril - Juillet ; Petite saison : Septembre - Novembre ; Petit sec en Août
            rain_prob = np.where(
                (months >= 4) & (months <= 7), 0.40,
                np.where((months == 8), 0.12,
                         np.where((months >= 9) & (months <= 11), 0.32, 0.06))
            )
            scale_rain = 11.0
        elif is_mountain:
            # Bimodal abondant (Plateaux, forêts de Kpalimé / Atakpamé)
            rain_prob = np.where(
                (months >= 3) & (months <= 7), 0.50,
                np.where((months == 8), 0.25,
                         np.where((months >= 9) & (months <= 11), 0.48, 0.10))
            )
            scale_rain = 18.0
        else:
            # Centrale (Intermédiaire)
            rain_prob = np.where((months >= 4) & (months <= 10), 0.42, 0.08)
            scale_rain = 14.0

        is_rain = rng.rand(n) < rain_prob
        rain_amounts = np.where(is_rain, rng.exponential(scale_rain, n), 0.0)

        # Rayonnement solaire incident (MJ/m2/jour)
        solar_base = 21.0 if is_northern else 18.5
        solar = np.where(is_rain, rng.uniform(12.0, 17.0, n), rng.uniform(solar_base - 2.0, solar_base + 3.5, n))

        # Humidité relative (%)
        rh = np.where(is_rain, rng.uniform(75.0, 95.0, n), rng.uniform(40.0, 72.0, n))
        wind = rng.uniform(1.0, 2.5, n)

        df = pd.DataFrame({
            "date": dates,
            "temp_mean": np.round(temps, 2),
            "temp_max": np.round(t_max, 2),
            "temp_min": np.round(t_min, 2),
            "precipitation": np.round(rain_amounts, 2),
            "solar_radiation": np.round(solar, 2),
            "humidity": np.round(rh, 1),
            "wind_speed": np.round(wind, 2)
        })

        et0_list = []
        for idx, row in df.iterrows():
            doy = int(row["date"].dayofyear)
            et0_val = cls._calculate_et0_hargreaves(
                t_mean=row["temp_mean"],
                t_max=row["temp_max"],
                t_min=row["temp_min"],
                solar_rad=row["solar_radiation"],
                lat_deg=lat,
                day_of_year=doy
            )
            et0_list.append(round(et0_val, 2))

        df["et0_mm"] = et0_list
        df["source"] = "Simulation synthétique hors-ligne (Normales 30 ans - Non Observé)"
        return df
