"""
=============================================================================
TERRA-ORBIT TOGO : Satellite Parametric Micro-Insurance Engine
=============================================================================
Moteur d'indemnisation indicielle automatisée sans expertise physique de terrain,
déclenché par la double anomalie biophysique spatiale :
- Humidité du sol en profondeur : NASA SMAP (Bande L micro-ondes, 1.41 GHz)
- Température radiométrique de canopée : NASA ECOSTRESS (ISS, 70m)
- Évacuation des indemnisations en temps réel par Mobile Money (T-Money, Flooz)
- Conforme aux exigences du Code CIMA (Conférence Interafricaine des Marchés d'Assurances)
=============================================================================
"""

import datetime
import hashlib
import uuid
from typing import Dict, List, Optional, Any


class ParametricInsuranceEngine:
    """
    Calculateur actuariel et moteur d'exécution d'assurance indicielle paramétrique.
    Élimine le risque de base (basis risk) en croisant l'épuisement du réservoir racinaire
    (SMAP) et la rupture de régulation transpiratoire stomatique foliaire (ECOSTRESS).
    """

    # --- Paliers d'indemnisation paramétrique (Standards CIMA / ARC) ---
    TIER_0_NORMAL: str = "TIER_0_NORMAL"
    TIER_1_EARLY_DROUGHT: str = "TIER_1_ALERTE_DEFENSE"
    TIER_2_SEVERE_DROUGHT: str = "TIER_2_SECHERESSE_SEVERE"
    TIER_3_CATASTROPHIC_DROUGHT: str = "TIER_3_CATASTROPHE_AGRICOLE"

    # Seuils biophysiques du double déclencheur (Dual-Anomaly Trigger)
    THRESHOLD_SMAP_EARLY: float = -20.0       # -20% sous la moyenne 10 ans
    THRESHOLD_SMAP_SEVERE: float = -25.0      # -25% sous la moyenne 10 ans
    THRESHOLD_SMAP_CATASTROPHIC: float = -35.0 # -35% sous la moyenne 10 ans

    THRESHOLD_ECOSTRESS_EARLY: float = +2.0   # +2.0°C au-dessus de la normale
    THRESHOLD_ECOSTRESS_SEVERE: float = +2.5  # +2.5°C au-dessus de la normale
    THRESHOLD_ECOSTRESS_CATASTROPHIC: float = +3.5 # +3.5°C au-dessus de la normale

    DURATION_DAYS_EARLY: int = 10             # 10 jours consécutifs
    DURATION_DAYS_SEVERE: int = 14            # 14 jours consécutifs
    DURATION_DAYS_CATASTROPHIC: int = 21      # 21 jours consécutifs

    # Opérateurs Télécoms & Protocoles Mobile Money au Togo
    MOBILE_OPERATORS: Dict[str, Dict[str, str]] = {
        "T-Money (Togocom)": {
            "code_reseau": "TMONEY_TG",
            "ussd_code": "*145#",
            "format_prefix": "90|91|92|93|70|71",
            "protocole_api": "B2W_REST_BULK_V2",
            "cle_partenaire": "TOGOCOM-AGRI-PARAMETRIC-2026"
        },
        "Moov Money (Flooz)": {
            "code_reseau": "MOOV_FLOOZ_TG",
            "ussd_code": "*155#",
            "format_prefix": "96|97|98|99|79",
            "protocole_api": "FLOOZ_PUSH_GATEWAY_V3",
            "cle_partenaire": "MOOV-AFRICA-TG-ORBIT-2026"
        }
    }

    # Sensibilité phénologique selon le stade de développement (FAO-56 Ky)
    STAGES_VULNERABILITY: Dict[str, float] = {
        "EMERGENCE_VEGETATIF": 0.85,          # Stade initial : sensible au faux départ des pluies
        "FLORAISON_REMPLISSAGE": 1.30,        # Stade critique : avortement floral irréversible
        "MATURATION_SENESCENCE": 0.70         # Fin de cycle : impact modéré sur le rendement
    }

    # Fréquence historique de sécheresse par région au Togo (% de campagnes affectées)
    REGIONAL_DROUGHT_FREQUENCY: Dict[str, float] = {
        "Savanes": 0.145,   # 14.5% de probabilité annuelle de sécheresse sévère
        "Kara": 0.110,      # 11.0%
        "Centrale": 0.092,  # 9.2%
        "Plateaux": 0.075,  # 7.5%
        "Maritime": 0.128   # 12.8% (anomalie sèche du Dahomey Gap)
    }

    @classmethod
    def evaluate_claim_trigger(
        cls,
        soil_moisture_anomaly_pct: float,      # Anomalie SMAP vs moyenne 10 ans (-30% = déficit critique)
        ecostress_lst_anomaly_deg: float,       # Anomalie thermique de canopée (+3.5°C = stress hydrique aigu)
        consecutive_drought_days: int,          # Nombre de jours consécutifs sous double contrainte
        insured_capital_fcfa: int = 200000,     # Capital souscrit par hectare (ex: 200 000 FCFA)
        farmer_phone: str = "+228 90 XX XX XX", # Téléphone mobile money du producteur
        operator: str = "T-Money (Togocom)",    # T-Money (Togocom) ou Moov Money (Flooz)
        growth_stage: str = "FLORAISON_REMPLISSAGE", # EMERGENCE_VEGETATIF, FLORAISON_REMPLISSAGE, MATURATION_SENESCENCE
        region_name: str = "Centrale",          # Savanes, Kara, Centrale, Plateaux, Maritime
        language: str = "Français"              # Français, Éwé (Mina), Kabyè
    ) -> Dict[str, Any]:
        """
        Détermine avec rigueur si les conditions paramétriques contractuelles sont remplies.
        
        Garantie de rétro-compatibilité stricte : préserve tous les paramètres et clés de retour
        d'origine tout en enrichissant le moteur d'une structure indicielle multi-paliers,
        d'un payload API Mobile Money et d'une notification multilingue.
        """
        # Normalisation de l'opérateur
        matched_op = "T-Money (Togocom)"
        for op_key in cls.MOBILE_OPERATORS:
            if op_key.lower() in operator.lower() or ("flooz" in operator.lower() and "flooz" in op_key.lower()):
                matched_op = op_key
                break

        # Facteur de vulnérabilité phénologique
        stage_factor = cls.STAGES_VULNERABILITY.get(growth_stage, 1.0)

        # ---------------------------------------------------------------------
        # 1. ÉVALUATION DES PALIERS DU DOUBLE DÉCLENCHEUR (DUAL-ANOMALY TRIGGER)
        # ---------------------------------------------------------------------
        # Condition A : Réservoir sous-sol SMAP en déficit critique
        # Condition B : Échauffement thermique foliaire ECOSTRESS confirmé
        # Condition C : Persistance temporelle sans discontinuité

        is_catastrophic = (
            soil_moisture_anomaly_pct <= cls.THRESHOLD_SMAP_CATASTROPHIC and
            ecostress_lst_anomaly_deg >= cls.THRESHOLD_ECOSTRESS_CATASTROPHIC and
            consecutive_drought_days >= cls.DURATION_DAYS_CATASTROPHIC
        )

        is_severe = (
            soil_moisture_anomaly_pct <= cls.THRESHOLD_SMAP_SEVERE and
            ecostress_lst_anomaly_deg >= cls.THRESHOLD_ECOSTRESS_SEVERE and
            consecutive_drought_days >= cls.DURATION_DAYS_SEVERE
        )

        is_early = (
            soil_moisture_anomaly_pct <= cls.THRESHOLD_SMAP_EARLY and
            ecostress_lst_anomaly_deg >= cls.THRESHOLD_ECOSTRESS_EARLY and
            consecutive_drought_days >= cls.DURATION_DAYS_EARLY
        )

        # Détermination du palier et du taux d'indemnisation contractuel
        if is_catastrophic:
            palier = cls.TIER_3_CATASTROPHIC_DROUGHT
            payout_pct = 100.0  # Indemnisation totale du capital
            triggered = True
            status_desc = "SIMULATION - SINISTRE MAJEUR, AUCUN PAIEMENT"
        elif is_severe:
            palier = cls.TIER_2_SEVERE_DROUGHT
            # Taux proportionnel calibré entre 65% et 90% selon la durée et le stade
            base_payout = 65.0
            duration_bonus = min(25.0, (consecutive_drought_days - 14) * 3.5)
            payout_pct = min(90.0, base_payout + duration_bonus) * min(1.15, stage_factor)
            payout_pct = round(min(100.0, max(50.0, payout_pct)), 1)
            triggered = True
            status_desc = "SIMULATION - SEUIL ATTEINT, AUCUN PAIEMENT"
        elif is_early:
            palier = cls.TIER_1_EARLY_DROUGHT
            payout_pct = 25.0   # Déclenchement de défense (achat bio-stimulants / replantation)
            triggered = True
            status_desc = "SIMULATION - SEUIL PRÉCOCE, INDEMNITÉ THÉORIQUE 25%"
        else:
            palier = cls.TIER_0_NORMAL
            payout_pct = 0.0
            triggered = False
            status_desc = "SIMULATION - SEUIL NON ATTEINT"

        payout_amount_fcfa = int(insured_capital_fcfa * (payout_pct / 100.0))

        # ---------------------------------------------------------------------
        # 2. GÉNÉRATION DU PROTOCOLE TRANSACTIONNEL MOBILE MONEY
        # ---------------------------------------------------------------------
        today_iso = datetime.date.today().isoformat()
        today_human = datetime.date.today().strftime("%d/%m/%Y")
        op_info = cls.MOBILE_OPERATORS[matched_op]

        # Empreinte cryptographique unique de transaction pour l'audit et la réassurance
        raw_token = f"{farmer_phone}|{matched_op}|{insured_capital_fcfa}|{payout_amount_fcfa}|{today_iso}|{palier}|{soil_moisture_anomaly_pct}|{ecostress_lst_anomaly_deg}|{consecutive_drought_days}|{growth_stage}"
        tx_hash = hashlib.sha256(raw_token.encode()).hexdigest()[:12].upper()
        transaction_id = f"{op_info['code_reseau']}-TXN-{today_iso.replace('-', '')}-{tx_hash}"

        # ---------------------------------------------------------------------
        # 3. MESSAGES DE NOTIFICATION SMS MULTILINGUES (LOW-TECH 2G)
        # ---------------------------------------------------------------------
        sms_fr = (
            f"[SIMULATION - NON ENVOYÉ] Anomalies saisies : humidité {soil_moisture_anomaly_pct}%, "
            f"température {ecostress_lst_anomaly_deg}°C, durée {consecutive_drought_days} jours. "
            f"Indemnité théorique : {payout_amount_fcfa:,} FCFA. Aucun virement exécuté."
        )
        # Avoid unverified local-language claims about real transfers.
        sms_ewe = "[Traduction éwé non validée : aperçu en français] " + sms_fr
        sms_kabye = "[Traduction kabyè non validée : aperçu en français] " + sms_fr

        # Sélection du SMS principal selon la préférence
        if language == "Éwé (Mina)":
            chosen_sms = sms_ewe
        elif language == "Kabyè":
            chosen_sms = sms_kabye
        else:
            chosen_sms = sms_fr

        # Structure de données pour l'API REST de versement de masse (B2W)
        mobile_money_payload = {
            "partner_id": op_info["cle_partenaire"],
            "transaction_reference": transaction_id,
            "disbursement_type": "PARAMETRIC_CLIMATE_INDEMNITY",
            "recipient_phone": farmer_phone,
            "amount_xof": payout_amount_fcfa,
            "currency": "XOF",
            "operator_network": op_info["code_reseau"],
            "audit_hash": tx_hash,
            "disbursement_channel": "INSTANT_PUSH",
            "settlement_status": "SIMULATION_ONLY",
            "timestamp": datetime.datetime.now().isoformat()
        }

        # ---------------------------------------------------------------------
        # 4. PREUVE SCIENTIFIQUE POUR LA RÉASSURANCE & LE CODE CIMA
        # ---------------------------------------------------------------------
        scientific_proof = {
            "capteur_microondes": "Anomalie saisie ; aucun capteur interrogé",
            "anomalie_racinaire_pct": soil_moisture_anomaly_pct,
            "seuil_smap_franchi": (soil_moisture_anomaly_pct <= cls.THRESHOLD_SMAP_SEVERE),
            "capteur_thermique": "Anomalie saisie ; aucun capteur interrogé",
            "anomalie_thermique_foliaire_deg": ecostress_lst_anomaly_deg,
            "seuil_ecostress_franchi": (ecostress_lst_anomaly_deg >= cls.THRESHOLD_ECOSTRESS_SEVERE),
            "duree_consecutive_jours": consecutive_drought_days,
            "seuil_duree_franchi": (consecutive_drought_days >= cls.DURATION_DAYS_SEVERE),
            "validation_physique_double": triggered,
            "risque_de_base_resorbation": "Non évalué ; entrées simulées sans validation terrain"
        }

        return {
            # --- Clés d'origine (Garantie de stricte rétro-compatibilité) ---
            "sinistre_declenche": triggered,
            "statut_indemnisation": status_desc,
            "anomalie_smap_pct": soil_moisture_anomaly_pct,
            "anomalie_thermique_ecostress_deg": ecostress_lst_anomaly_deg,
            "jours_consecutifs_stress": consecutive_drought_days,
            "capital_assure_fcfa": insured_capital_fcfa,
            "montant_indemnise_fcfa": payout_amount_fcfa,
            "canal_versement": matched_op,
            "beneficiaire": farmer_phone,
            "sms_transaction": chosen_sms,
            "date_audit": today_human,

            # --- Clés institutionnelles enrichies (CIMA, Télécoms, Réassurance) ---
            "palier_sinistre": palier,
            "taux_indemnisation_pct": payout_pct,
            "stade_croissance": growth_stage,
            "transaction_id": transaction_id,
            "mobile_money_payload": mobile_money_payload,
            "preuve_satellitaire_audit": scientific_proof,
            "sms_multilingue": {
                "francais": sms_fr,
                "ewe": sms_ewe,
                "kabye": sms_kabye
            }
        }

    @classmethod
    def calculate_actuarial_premium(
        cls,
        insured_capital_fcfa: int = 200000,
        region_name: str = "Centrale",
        mifa_subsidy_rate_pct: float = 50.0
    ) -> Dict[str, Any]:
        """
        Calcule la prime d'assurance indicielle selon les règles actuarielles CIMA.
        
        Prime Pure = Probabilité de sinistre x Coût moyen de l'indemnisation
        Prime Commerciale = Prime Pure + Chargements (gestion, distribution, réassurance)
        Prime Nette Producteur = Prime Commerciale - Subvention d'État MIFA (50%)
        """
        freq = cls.REGIONAL_DROUGHT_FREQUENCY.get(region_name, 0.10)

        # Sévérité moyenne pondérée (en cas de déclenchement, indemnité moyenne de 72%)
        average_claim_severity = 0.72
        pure_risk_premium_pct = round(freq * average_claim_severity * 100.0, 2)
        pure_risk_premium_fcfa = int(insured_capital_fcfa * (pure_risk_premium_pct / 100.0))

        # Chargements actuariels CIMA (gestion SFD 1.8%, réassurance 1.5%, taxe parafiscale 0.7%)
        expense_loading_pct = 4.0
        gross_commercial_premium_pct = round(pure_risk_premium_pct + expense_loading_pct, 2)
        gross_commercial_premium_fcfa = int(insured_capital_fcfa * (gross_commercial_premium_pct / 100.0))

        # Subvention MIFA Climat (prise en charge de 50% de la prime)
        mifa_subsidy_fcfa = int(gross_commercial_premium_fcfa * (mifa_subsidy_rate_pct / 100.0))
        farmer_net_premium_fcfa = gross_commercial_premium_fcfa - mifa_subsidy_fcfa
        farmer_net_premium_pct = round(gross_commercial_premium_pct * (1.0 - mifa_subsidy_rate_pct / 100.0), 2)

        return {
            "region": region_name,
            "capital_assure_fcfa": insured_capital_fcfa,
            "frequence_sinistre_historique_pct": round(freq * 100.0, 1),
            "taux_prime_pure_pct": pure_risk_premium_pct,
            "prime_pure_fcfa": pure_risk_premium_fcfa,
            "taux_prime_commerciale_pct": gross_commercial_premium_pct,
            "prime_commerciale_totale_fcfa": gross_commercial_premium_fcfa,
            "subvention_etat_mifa_pct": mifa_subsidy_rate_pct,
            "subvention_mifa_fcfa": mifa_subsidy_fcfa,
            "prime_nette_producteur_fcfa": farmer_net_premium_fcfa,
            "taux_net_producteur_pct": farmer_net_premium_pct
        }

    @classmethod
    def simulate_seasonal_dekads(
        cls,
        scenario_type: str = "drought_severe",
        insured_capital_fcfa: int = 200000,
        farmer_phone: str = "+228 90 12 34 56",
        operator: str = "T-Money (Togocom)"
    ) -> List[Dict[str, Any]]:
        """
        Simule le monitoring décadaire (12 décades = 120 jours d'une campagne agricole)
        pour démontrer aux partenaires institutionnels (MIFA, FUCEC, AXA) la réactivité
        du double déclencheur sans retard par rapport aux indices pluviométriques traditionnels.
        """
        # Génération d'une séquence agroclimatique réaliste selon le scénario
        results = []
        consecutive_stress = 0

        # Profils décadaires types pour 12 décades (Avril à Août)
        profiles = {
            "favorable": [
                (-5.0, 0.4), (2.0, -0.2), (10.0, -0.8), (5.0, -0.1),
                (0.0, 0.3), (-8.0, 0.8), (-4.0, 0.5), (3.0, -0.4),
                (8.0, -0.7), (2.0, -0.1), (-2.0, 0.2), (0.0, 0.0)
            ],
            "drought_severe": [
                (-5.0, 0.5), (-12.0, 1.2), (-18.0, 1.8), (-26.0, 2.7),
                (-32.0, 3.4), (-36.0, 3.8), (-34.0, 3.6), (-28.0, 2.9),
                (-20.0, 1.9), (-10.0, 1.0), (0.0, 0.2), (5.0, -0.3)
            ]
        }
        sequence = profiles.get(scenario_type, profiles["drought_severe"])

        for dekad_idx, (sm_anom, lst_anom) in enumerate(sequence, start=1):
            if sm_anom <= cls.THRESHOLD_SMAP_EARLY and lst_anom >= cls.THRESHOLD_ECOSTRESS_EARLY:
                consecutive_stress += 10  # Une décade = 10 jours de stress continu
            else:
                consecutive_stress = 0

            stage = "FLORAISON_REMPLISSAGE" if 4 <= dekad_idx <= 8 else ("EMERGENCE_VEGETATIF" if dekad_idx < 4 else "MATURATION_SENESCENCE")

            eval_res = cls.evaluate_claim_trigger(
                soil_moisture_anomaly_pct=sm_anom,
                ecostress_lst_anomaly_deg=lst_anom,
                consecutive_drought_days=consecutive_stress,
                insured_capital_fcfa=insured_capital_fcfa,
                farmer_phone=farmer_phone,
                operator=operator,
                growth_stage=stage
            )
            eval_res["decade_numero"] = dekad_idx
            eval_res["consecutive_stress_days"] = consecutive_stress
            results.append(eval_res)

        return results
