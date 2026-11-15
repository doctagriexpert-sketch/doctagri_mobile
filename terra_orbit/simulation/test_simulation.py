"""
TERRA-ORBIT TOGO - Agronomic & Rotation Simulation Test Suite
Validation des modèles FAO-56 et des 3 scénarios de rotation pour le Togo.
"""

import unittest
from terra_orbit.simulation.crop_models import CROP_DATABASE, TropicalCropModel
from terra_orbit.simulation.rotation_engine import CropRotationEngine
from terra_orbit.pipeline.togo_regions import TOGO_REGIONS


class TestAgronomicModels(unittest.TestCase):
    """Vérification des constantes et méthodes FAO-56."""

    def test_crop_database_presence(self):
        expected_crops = ["Maïs", "Soja Biologique", "Sorgho", "Niébé (Haricot)", "Arachide", "Coton", "Manioc"]
        for crop in expected_crops:
            self.assertIn(crop, CROP_DATABASE)
            c = CROP_DATABASE[crop]
            self.assertIn("kc_ini", c)
            self.assertIn("kc_mid", c)
            self.assertIn("kc_end", c)
            self.assertIn("profondeur_racinaire_m", c)
            self.assertIn("besoin_eau_cycle_mm", c)
            self.assertIn("sensibilite_stress_ky", c)
            self.assertIn("bilan_azote_kg_ha", c)

    def test_dynamic_kc_curve(self):
        # Maïs : cycle 105j, initial 20j (0.35), dev 30j (0.35->1.18), mid 40j (1.18), late 15j (1.18->0.60)
        kc_day_10 = TropicalCropModel.get_daily_kc("Maïs", 10)
        self.assertAlmostEqual(kc_day_10, 0.35, places=2)

        kc_day_70 = TropicalCropModel.get_daily_kc("Maïs", 70)
        self.assertAlmostEqual(kc_day_70, 1.18, places=2)

        kc_day_105 = TropicalCropModel.get_daily_kc("Maïs", 105)
        self.assertAlmostEqual(kc_day_105, 0.60, places=2)

    def test_dynamic_root_depth(self):
        zr_day_0 = TropicalCropModel.get_dynamic_root_depth("Maïs", 0)
        self.assertAlmostEqual(zr_day_0, 0.20, places=2)

        zr_max = TropicalCropModel.get_dynamic_root_depth("Maïs", 100)
        self.assertAlmostEqual(zr_max, 0.85, places=2)


class TestCropRotationScenarios(unittest.TestCase):
    """Validation des 3 scénarios sur les 5 régions du Togo."""

    def test_scenarios_across_all_five_regions(self):
        for region in TOGO_REGIONS.keys():
            scenarios = CropRotationEngine.compare_standard_scenarios(region)

            mono = scenarios["Monoculture Maïs (Pratique Dégradante)"]
            bio_soy = scenarios["Rotation Soja Bio (Recommandée Agro-Filière)"]
            shield = scenarios["Bouclier Climat Extrême (Résilience Sécheresse)"]

            # 1. Monoculture doit être sévèrement pénalisée (< 30)
            self.assertLess(mono["resilience_score"], 30.0, f"Monoculture score trop élevé en {region}")
            self.assertEqual(mono["bilan_azote_total_kg_ha"], -255)
            self.assertEqual(mono["credit_azote_restitue_kg_ha"], 0)

            # 2. Rotation Soja Bio doit être certifiée optimale (>= 75)
            self.assertGreaterEqual(bio_soy["resilience_score"], 75.0, f"Soja bio score insuffisant en {region}")
            self.assertGreater(bio_soy["credit_azote_restitue_kg_ha"], 25)
            self.assertGreater(bio_soy["economie_engrais_azote_fcfa"], 20000)

            # 3. Bouclier sécheresse doit avoir la plus faible consommation d'eau et score >= 75
            self.assertGreaterEqual(shield["resilience_score"], 75.0, f"Bouclier score insuffisant en {region}")
            self.assertLessEqual(shield["besoin_eau_total_mm"], bio_soy["besoin_eau_total_mm"])
            self.assertGreater(shield["wue_fcfa_par_mm_eau"], mono["wue_fcfa_par_mm_eau"])


if __name__ == "__main__":
    unittest.main()
