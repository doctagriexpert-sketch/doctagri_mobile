"""Payment regressions executable with the Python standard library only."""
import unittest

from terra_orbit.fintech.parametric_insurance import ParametricInsuranceEngine


class TestSimulationDisclosure(unittest.TestCase):
    def test_all_languages_remain_unpaid_previews(self):
        for language in ("Français", "Éwé (Mina)", "Kabyè"):
            with self.subTest(language=language):
                result = ParametricInsuranceEngine.evaluate_claim_trigger(
                    -32, 3.4, 16, language=language
                )
                self.assertTrue(result["sinistre_declenche"])
                self.assertGreater(result["montant_indemnise_fcfa"], 0)
                self.assertIn("SIMULATION", result["statut_indemnisation"])
                self.assertIn("Aucun virement exécuté", result["sms_transaction"])
                self.assertNotIn("effectué", result["sms_transaction"])
                self.assertEqual(
                    result["mobile_money_payload"]["settlement_status"],
                    "SIMULATION_ONLY",
                )

    def test_simulated_reference_includes_thermal_anomaly(self):
        first = ParametricInsuranceEngine.evaluate_claim_trigger(-32, 3.4, 16)
        second = ParametricInsuranceEngine.evaluate_claim_trigger(-32, 3.5, 16)
        self.assertNotEqual(first["transaction_id"], second["transaction_id"])


if __name__ == "__main__":
    unittest.main()
