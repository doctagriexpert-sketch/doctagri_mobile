"""
Unit tests for TERRA-ORBIT FinTech & Business De-risking Engines:
- ClimateCreditScorer (terra_orbit/fintech/credit_risk_scorer.py)
- ParametricInsuranceEngine (terra_orbit/fintech/parametric_insurance.py)
"""

import pytest
from terra_orbit.fintech.credit_risk_scorer import ClimateCreditScorer
from terra_orbit.fintech.parametric_insurance import ParametricInsuranceEngine


class TestClimateCreditScorer:
    """Tests unitaires pour le moteur de notation et de dé-risquage du crédit agricole."""

    def test_legacy_backward_compatibility(self):
        """Vérifie la compatibilité ascendante avec les appels existants de app.py."""
        res = ClimateCreditScorer.evaluate_loan_application(
            agronomic_resilience_score=78.0,
            paw_percent=45.0,
            requested_amount_fcfa=250000
        )
        # Vérification des clés requises par app.py
        expected_keys = [
            "statut_credit", "decision_code", "taux_defaut_historique_pct",
            "taux_defaut_projete_pct", "reduction_risque_pct",
            "taux_interet_recommande_pct", "montant_demande_fcfa",
            "montant_accorde_fcfa", "perte_financiere_evitee_fcfa",
            "avis_analyste_mifa"
        ]
        for key in expected_keys:
            assert key in res, f"Clé manquante: {key}"

        assert res["decision_code"] == "GREEN_LIGHT"
        assert res["montant_accorde_fcfa"] == 250000
        assert res["taux_interet_recommande_pct"] <= 9.5
        assert res["taux_defaut_projete_pct"] < res["taux_defaut_historique_pct"]

    def test_prime_green_certified_rotation(self):
        """Scénario optimal : rotation certifiée Maïs -> Soja Bio -> Sorgho."""
        res = ClimateCreditScorer.evaluate_loan_application(
            agronomic_resilience_score=85.0,
            paw_percent=52.0,
            requested_amount_fcfa=250000,
            crop_rotation_plan=["Maïs", "Soja Biologique", "Sorgho"],
            region_name="Plateaux",
            has_offtaker_contract=True,
            farmer_coop_member=True,
            mfi_partner="FUCEC Togo",
            delta_nitrogen_kg_ha=50.0
        )
        assert res["decision_code"] == "GREEN_LIGHT"
        assert res["mifa_garantie_taux_pct"] == 75.0
        assert res["mifa_montant_garanti_fcfa"] == 187500
        assert res["mfi_exposition_nette_fcfa"] == 62500
        assert res["taux_defaut_projete_pct"] <= 6.0
        assert res["reduction_risque_pct"] >= 70.0
        assert res["taux_interet_recommande_pct"] <= 9.0
        assert res["economie_provisions_bceao_fcfa"] > 0

    def test_orange_conditional_approval(self):
        """Scénario intermédiaire : score moyen, condition agronomique requise."""
        res = ClimateCreditScorer.evaluate_loan_application(
            agronomic_resilience_score=58.0,
            paw_percent=28.0,
            requested_amount_fcfa=250000,
            crop_rotation_plan=["Maïs", "Maïs", "Niébé"],
            region_name="Centrale",
            has_offtaker_contract=False,
            farmer_coop_member=True,
            mfi_partner="WAGES"
        )
        assert res["decision_code"] == "ORANGE_LIGHT"
        assert res["mifa_garantie_taux_pct"] == 50.0
        assert res["montant_accorde_fcfa"] == 200000  # 80% accordé
        assert 11.0 <= res["taux_interet_recommande_pct"] <= 13.0
        assert 8.0 <= res["taux_defaut_projete_pct"] <= 16.0

    def test_red_high_risk_rejection(self):
        """Scénario critique : monoculture continue et sol sec -> refus pour protéger l'agriculteur."""
        res = ClimateCreditScorer.evaluate_loan_application(
            agronomic_resilience_score=35.0,
            paw_percent=12.0,
            requested_amount_fcfa=250000,
            crop_rotation_plan=["Maïs", "Maïs", "Maïs"],
            region_name="Savanes",
            has_offtaker_contract=False,
            farmer_coop_member=False
        )
        assert res["decision_code"] == "RED_LIGHT"
        assert res["montant_accorde_fcfa"] == 0
        assert res["mifa_garantie_taux_pct"] == 0.0
        assert res["taux_defaut_projete_pct"] >= 18.0

    def test_portfolio_simulation(self):
        """Test de la simulation de portefeuille pour FUCEC et WAGES."""
        port = ClimateCreditScorer.simulate_mfi_portfolio(
            total_farmers=1000,
            average_loan_fcfa=250000,
            mfi_partner="FUCEC Togo",
            adoption_rate_terra_orbit_pct=80.0
        )
        assert port["volume_portefeuille_total_fcfa"] == 250000000
        assert port["taux_defaut_nouveau_portefeuille_pct"] < port["taux_defaut_historique_pct"]
        assert port["impayes_historiques_evites_fcfa"] > 30000000
        assert port["volume_garanti_mifa_fcfa"] == 150000000


class TestParametricInsuranceEngine:
    """Tests unitaires pour le moteur d'assurance indicielle paramétrique à double déclencheur."""

    def test_legacy_backward_compatibility(self):
        """Vérifie la compatibilité ascendante avec app.py."""
        res = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-32.0,
            ecostress_lst_anomaly_deg=3.4,
            consecutive_drought_days=16,
            insured_capital_fcfa=200000,
            farmer_phone="+228 90 12 34 56",
            operator="T-Money (Togocom)"
        )
        expected_keys = [
            "sinistre_declenche", "statut_indemnisation", "anomalie_smap_pct",
            "anomalie_thermique_ecostress_deg", "jours_consecutifs_stress",
            "capital_assure_fcfa", "montant_indemnise_fcfa", "canal_versement",
            "beneficiaire", "sms_transaction", "date_audit"
        ]
        for key in expected_keys:
            assert key in res, f"Clé manquante: {key}"

        assert res["sinistre_declenche"] is True
        assert res["montant_indemnise_fcfa"] > 0
        assert "T-Money" in res["canal_versement"]
        assert "+228 90 12 34 56" in res["beneficiaire"]

    def test_dual_anomaly_trigger_logic(self):
        """
        Vérification physique : le sinistre ne doit se déclencher QUE si :
        - SMAP est critique (déficit sous-sol)
        - ET ECOSTRESS est critique (échauffement thermique canopée)
        - ET la durée minimale de 14 jours est atteinte.
        """
        # Cas 1 : SMAP sec (-30%) mais ECOSTRESS frais (+0.5°C) -> PAS de déclenchement (fausse alerte résolue)
        res_false1 = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-30.0,
            ecostress_lst_anomaly_deg=+0.5,
            consecutive_drought_days=16
        )
        assert res_false1["sinistre_declenche"] is False
        assert res_false1["montant_indemnise_fcfa"] == 0

        # Cas 2 : ECOSTRESS très chaud (+3.8°C) mais SMAP humide (-5%) -> PAS de déclenchement (coup de chaud passager)
        res_false2 = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-5.0,
            ecostress_lst_anomaly_deg=+3.8,
            consecutive_drought_days=16
        )
        assert res_false2["sinistre_declenche"] is False

        # Cas 3 : SMAP sec (-30%) et ECOSTRESS chaud (+3.0°C) mais seulement 5 jours -> PAS de déclenchement sévère
        res_false3 = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-30.0,
            ecostress_lst_anomaly_deg=+3.0,
            consecutive_drought_days=5
        )
        assert res_false3["sinistre_declenche"] is False

        # Cas 4 : Vraie sécheresse biophysique confirmée (SMAP: -28%, ECOSTRESS: +2.8°C, 15 jours) -> Déclenchement!
        res_true = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-28.0,
            ecostress_lst_anomaly_deg=+2.8,
            consecutive_drought_days=15
        )
        assert res_true["sinistre_declenche"] is True
        assert res_true["palier_sinistre"] == ParametricInsuranceEngine.TIER_2_SEVERE_DROUGHT

    def test_catastrophic_tier_full_payout(self):
        """Sécheresse extrême (> 21 jours, SMAP < -35%, ECOSTRESS > +3.5°C) -> 100% versement."""
        res = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-38.0,
            ecostress_lst_anomaly_deg=+4.2,
            consecutive_drought_days=25,
            insured_capital_fcfa=200000
        )
        assert res["sinistre_declenche"] is True
        assert res["palier_sinistre"] == ParametricInsuranceEngine.TIER_3_CATASTROPHIC_DROUGHT
        assert res["taux_indemnisation_pct"] == 100.0
        assert res["montant_indemnise_fcfa"] == 200000

    def test_mobile_money_payload_and_flooz(self):
        """Vérifie la génération du payload d'API pour Moov Money Flooz."""
        res = ParametricInsuranceEngine.evaluate_claim_trigger(
            soil_moisture_anomaly_pct=-26.0,
            ecostress_lst_anomaly_deg=2.6,
            consecutive_drought_days=14,
            insured_capital_fcfa=150000,
            farmer_phone="+228 98 76 54 32",
            operator="Moov Money (Flooz)",
            language="Éwé (Mina)"
        )
        payload = res["mobile_money_payload"]
        assert payload["recipient_phone"] == "+228 98 76 54 32"
        assert payload["operator_network"] == "MOOV_FLOOZ_TG"
        assert payload["amount_xof"] == res["montant_indemnise_fcfa"]
        assert "FLOOZ_TG-TXN-" in res["transaction_id"]
        assert "SIMULATION - NON ENVOYÉ" in res["sms_transaction"]
        assert res["mobile_money_payload"]["settlement_status"] == "SIMULATION_ONLY"

    def test_actuarial_premium_calculation(self):
        """Vérifie la conformité du calcul de prime selon les normes CIMA."""
        prem = ParametricInsuranceEngine.calculate_actuarial_premium(
            insured_capital_fcfa=200000,
            region_name="Savanes",
            mifa_subsidy_rate_pct=50.0
        )
        assert prem["capital_assure_fcfa"] == 200000
        assert prem["subvention_etat_mifa_pct"] == 50.0
        assert prem["prime_nette_producteur_fcfa"] == prem["subvention_mifa_fcfa"]
        assert prem["prime_nette_producteur_fcfa"] + prem["subvention_mifa_fcfa"] == prem["prime_commerciale_totale_fcfa"]
        assert prem["taux_prime_commerciale_pct"] > prem["taux_prime_pure_pct"]

    def test_seasonal_dekads_simulation(self):
        """Vérifie le monitoring sur 12 décades."""
        dekads = ParametricInsuranceEngine.simulate_seasonal_dekads(
            scenario_type="drought_severe",
            insured_capital_fcfa=200000
        )
        assert len(dekads) == 12
        triggers = [d for d in dekads if d["sinistre_declenche"]]
        assert len(triggers) > 0
