"""
TERRA-ORBIT TOGO - NASA Competition Independent Verification Suite
Lead Verifier & Judge Audit Suite: Testing all modules for NASA Space Apps Challenge compliance.
"""

import unittest
import numpy as np
import pandas as pd

from terra_orbit.pipeline.togo_regions import TOGO_REGIONS
from terra_orbit.pipeline.nasa_power_client import NASAPowerClient
from terra_orbit.pipeline.earthdata_smap_ecostress import MultiSensorDownscaler
from terra_orbit.simulation.crop_models import CROP_DATABASE
from terra_orbit.simulation.rotation_engine import CropRotationEngine
from terra_orbit.fintech.credit_risk_scorer import ClimateCreditScorer
from terra_orbit.fintech.parametric_insurance import ParametricInsuranceEngine


class TestNASACompliance(unittest.TestCase):
    """Suite d'audit rigoureuse selon les 5 critères de la NASA."""

    # ================= 1. RELEVANCE & GEOSPATIAL VALIDITY (TOGO REGIONS) =================
    def test_togo_regions_completeness(self):
        """Vérifie la complétude des 5 régions économiques et agro-écologiques du Togo."""
        expected_regions = ["Savanes", "Kara", "Centrale", "Plateaux", "Maritime"]
        self.assertEqual(sorted(list(TOGO_REGIONS.keys())), sorted(expected_regions))

        for name, r in TOGO_REGIONS.items():
            self.assertIn("lat", r)
            self.assertIn("lon", r)
            self.assertIn("pluviometrie_annuelle_moy", r)
            self.assertIn("reserve_utile_sol_mm", r)
            self.assertIn("pente_moyenne_deg", r)
            self.assertIn("cultures_principales", r)

            # Pluviométrie cohérente avec la climatologie ouest-africaine
            self.assertGreaterEqual(r["pluviometrie_annuelle_moy"], 800)
            self.assertLessEqual(r["pluviometrie_annuelle_moy"], 1600)
            # Latitude du Togo entre 6°N et 11.2°N
            self.assertTrue(6.0 <= r["lat"] <= 11.2, f"Latitude {r['lat']} hors limites Togo")
            # Longitude du Togo entre -0.2°W et 1.8°E
            self.assertTrue(-0.2 <= r["lon"] <= 1.8, f"Longitude {r['lon']} hors limites Togo")

    # ================= 2. SCIENTIFIC VALIDITY: PHYSICAL DOWNSCALING =================
    def test_tvdi_behavior(self):
        """Vérifie le comportement physique du TVDI (trapeze LST-NDVI)."""
        # À NDVI constant (0.5), plus LST est chaud, plus TVDI doit être élevé (sol sec)
        tvdi_cool = MultiSensorDownscaler.compute_tvdi(lst_ecostress=26.0, ndvi=0.5)
        tvdi_hot = MultiSensorDownscaler.compute_tvdi(lst_ecostress=40.0, ndvi=0.5)
        self.assertGreater(tvdi_hot, tvdi_cool)
        self.assertTrue(0.0 <= tvdi_cool <= 1.0)
        self.assertTrue(0.0 <= tvdi_hot <= 1.0)

        # À LST constant (35°C), plus NDVI est haut, plus le stress relatif TVDI augmente car dry_edge baisse
        tvdi_low_veg = MultiSensorDownscaler.compute_tvdi(lst_ecostress=35.0, ndvi=0.2)
        tvdi_high_veg = MultiSensorDownscaler.compute_tvdi(lst_ecostress=35.0, ndvi=0.7)
        self.assertGreater(tvdi_high_veg, tvdi_low_veg)

    def test_twi_behavior(self):
        """Vérifie que le Topographic Wetness Index diminue avec la pente (drainage rapide)."""
        twi_flat = MultiSensorDownscaler.compute_twi(slope_deg=1.0)
        twi_steep = MultiSensorDownscaler.compute_twi(slope_deg=15.0)
        self.assertGreater(twi_flat, twi_steep)
        self.assertTrue(4.0 <= twi_flat <= 14.0)
        self.assertTrue(4.0 <= twi_steep <= 14.0)

    def test_downscale_bounds_and_paw(self):
        """Vérifie la robustesse numérique et les bornes physiques de l'humidité désagrégée."""
        # Test conditions normales
        res = MultiSensorDownscaler.downscale_soil_moisture(
            smap_sm_coarse=0.18, ecostress_lst=36.0, ndvi=0.50, slope_deg=2.5
        )
        self.assertTrue(0.04 <= res["sm_fine_30m_m3m3"] <= 0.42)
        self.assertTrue(0.0 <= res["paw_percent"] <= 100.0)

        # Test conditions extrêmes (sécheresse maximale)
        res_dry = MultiSensorDownscaler.downscale_soil_moisture(
            smap_sm_coarse=0.05, ecostress_lst=48.0, ndvi=0.10, slope_deg=12.0
        )
        self.assertFalse(res_dry["seed_safe"])
        self.assertIn("SÉVÈRE", res_dry["stress_level"])
        self.assertLess(res_dry["paw_percent"], 25.0)

        # Test conditions optimales (sols hydratés)
        res_wet = MultiSensorDownscaler.downscale_soil_moisture(
            smap_sm_coarse=0.32, ecostress_lst=26.0, ndvi=0.75, slope_deg=0.8
        )
        self.assertTrue(res_wet["seed_safe"])
        self.assertIn("OPTIMAL", res_wet["stress_level"])
        self.assertGreater(res_wet["paw_percent"], 50.0)

    # ================= 3. AGRONOMIC SIMULATION VALIDITY (FAO-56) =================
    def test_crop_database_consistency(self):
        """Vérifie les paramètres agronomiques de toutes les cultures."""
        for name, c in CROP_DATABASE.items():
            self.assertGreater(c["cycle_jours"], 50)
            self.assertGreater(c["besoin_eau_cycle_mm"], 250)
            self.assertGreater(c["kc_mid"], c["kc_ini"])
            self.assertGreater(c["rendement_moyen_t_ha"], 0.5)
            self.assertGreater(c["valeur_commerciale_kg_fcfa"], 100)

        # Vérification clé : Soja et Niébé doivent fixer de l'azote (N > 0)
        self.assertGreater(CROP_DATABASE["Soja Biologique"]["bilan_azote_kg_ha"], 0)
        self.assertGreater(CROP_DATABASE["Niébé (Haricot)"]["bilan_azote_kg_ha"], 0)

        # Le Maïs et le Coton sont épuisants pour le sol (N < 0)
        self.assertLess(CROP_DATABASE["Maïs"]["bilan_azote_kg_ha"], 0)
        self.assertLess(CROP_DATABASE["Coton"]["bilan_azote_kg_ha"], 0)

    def test_rotation_scenarios_comparison(self):
        """Vérifie que la rotation diversifiée surpasse nettement la monoculture continue."""
        res_monoculture = CropRotationEngine.simulate_rotation(
            crop_sequence=["Maïs", "Maïs", "Maïs"],
            region_name="Savanes"
        )
        res_bio_soy = CropRotationEngine.simulate_rotation(
            crop_sequence=["Maïs", "Soja Biologique", "Sorgho"],
            region_name="Savanes"
        )

        # La rotation diversifiée doit avoir un score supérieur
        self.assertGreater(res_bio_soy["resilience_score"], res_monoculture["resilience_score"])

        # Le bilan azote de la monoculture doit être fortement déficitaire (-255 kg N/ha)
        self.assertEqual(res_monoculture["bilan_azote_total_kg_ha"], -255)
        # La rotation avec légumineuse doit améliorer substantiellement le bilan azote
        self.assertGreater(res_bio_soy["bilan_azote_total_kg_ha"], res_monoculture["bilan_azote_total_kg_ha"])

        # La protection contre l'érosion doit être supérieure avec le soja
        self.assertGreater(res_bio_soy["score_protection_erosion"], res_monoculture["score_protection_erosion"])

    # ================= 4. FINTECH & DE-RISKING VALIDITY =================
    def test_credit_scoring_logic(self):
        """Vérifie l'attribution du statut de crédit et du taux bonifié."""
        # Cas 1: Rotation certifiée optimale
        opt = ClimateCreditScorer.evaluate_loan_application(
            agronomic_resilience_score=82.0, paw_percent=65.0, requested_amount_fcfa=250000
        )
        self.assertEqual(opt["decision_code"], "GREEN_LIGHT")
        self.assertEqual(opt["statut_credit"], "APPROUVÉ - CRÉDIT VERT BONIFIÉ")
        self.assertTrue(8.0 <= opt["taux_interet_recommande_pct"] <= 10.0)
        self.assertEqual(opt["montant_accorde_fcfa"], 250000)
        self.assertLess(opt["taux_defaut_projete_pct"], 15.0)

        # Cas 2: Monoculture à haut risque
        bad = ClimateCreditScorer.evaluate_loan_application(
            agronomic_resilience_score=35.0, paw_percent=20.0, requested_amount_fcfa=250000
        )
        self.assertEqual(bad["decision_code"], "RED_LIGHT")
        self.assertEqual(bad["statut_credit"], "REFUSÉ - RISQUE CLIMATIQUE CRITIQUE")
        self.assertEqual(bad["montant_accorde_fcfa"], 0)

    def test_parametric_insurance_trigger(self):
        """Vérifie le double seuil de déclenchement d'indemnisation indicielle."""
        # Seuil contractuel non atteint (anomalie SMAP insuffisante)
        no_claim = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-15.0,
            ecostress_lst_anomaly_deg=+3.5,
            consecutive_drought_days=18
        )
        self.assertFalse(no_claim["sinistre_declenche"])
        self.assertEqual(no_claim["montant_indemnise_fcfa"], 0)

        # Seuil contractuel non atteint (durée trop courte < 10j)
        short_drought = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-35.0,
            ecostress_lst_anomaly_deg=+3.5,
            consecutive_drought_days=5
        )
        self.assertFalse(short_drought["sinistre_declenche"])

        # Double anomalie confirmée sur 16 jours
        valid_claim = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-32.0,
            ecostress_lst_anomaly_deg=+3.2,
            consecutive_drought_days=16,
            insured_capital_fcfa=200000
        )
        self.assertTrue(valid_claim["sinistre_declenche"])
        self.assertGreater(valid_claim["montant_indemnise_fcfa"], 50000)
        self.assertIn("T-Money", valid_claim["canal_versement"])


if __name__ == "__main__":
    unittest.main()
