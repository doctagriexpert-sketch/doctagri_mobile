"""
TERRA-ORBIT TOGO - Tropical Crop Agronomic Models (FAO-56 & ITRA Calibrated)
Paramètres physiologiques, besoins hydriques et bilans agro-pédologiques
des cultures vivrières et de rente adaptées aux 5 régions du Togo.
Références scientifiques : FAO Irrigation and Drainage Paper No. 56,
FAO-33 (Doorenbos & Kassam), ITRA (Institut Togolais de Recherche Agronomique),
ICAT et fiches techniques CIRAD pour l'Afrique de l'Ouest.
"""

from typing import Dict, Any, Optional

CROP_DATABASE: Dict[str, Dict[str, Any]] = {
    "Maïs": {
        "nom_scientifique": "Zea mays",
        "famille_botanique": "Poaceae (Céréale)",
        "est_legumineuse": False,
        "cycle_jours": 105,
        "stades_croissance_jours": {
            "initial": 20,
            "developpement": 30,
            "mi_saison": 40,
            "tardif": 15
        },
        "kc_ini": 0.35,
        "kc_mid": 1.18,
        "kc_end": 0.60,
        "fraction_depletion_p": 0.55,       # FAO-56 Table 22 (seuil d'épuisement sans stress hydrique)
        "profondeur_racinaire_initiale_m": 0.20,
        "profondeur_racinaire_m": 0.85,    # Enracinement fasciculé dans sols ferrugineux tropicaux
        "besoin_eau_cycle_mm": 550,        # Besoin total ETc en climat soudano-guinéen
        "sensibilite_stress_ky": 1.25,     # Ky saisonnier global FAO-33 (Ky > 1 : très vulnérable)
        "ky_stades": {
            "vegetatif": 0.40,
            "floraison": 1.50,             # Période critique de pollinisation/soie : risque d'avortement d'épis
            "remplissage_grain": 0.50,
            "maturation": 0.20
        },
        "bilan_azote_kg_ha": -85,          # Prélèvement net d'azote pour un rendement de ~2.2 t/ha
        "credit_azote_suivant_kg_ha": 0,    # Ne fournit pas de crédit azote
        "effet_suppression_striga_pct": -20.0, # Favorise la multiplication de Striga hermonthica en monoculture
        "couverture_sol_max_pct": 80,
        "usle_c_factor": 0.38,             # Facteur de couvert végétal USLE (protection moyenne contre l'érosion)
        "valeur_commerciale_kg_fcfa": 220, # Cours moyen bord champ sur les marchés togolais (Cereal Index)
        "rendement_moyen_t_ha": 2.2,
        "rendement_potentiel_t_ha": 4.5,
        "varietes_vulgarisees_togo": ["TZEE-W-SR (extra-précoce)", "Sotubaka", "EV 8435-SR"],
        "aptitude_regionale": {
            "Savanes": 0.75,   # Risque élevé de rupture pluviométrique à la floraison
            "Kara": 0.85,
            "Centrale": 0.95,  # Excellente zone maïsicole
            "Plateaux": 1.00,  # Zone optimale à deux saisons (bimodale)
            "Maritime": 0.80   # Dahomey Gap : déficit pluviométrique sur 2ème saison
        },
        "description": (
            "Aliment de base majeur au Togo. Exigeant en azote et extrêmement sensible au stress hydrique "
            "pendant la floraison (Ky=1.5). En monoculture continue, il épuise la fertilité et multiplie "
            "les graines de l'adventice parasite Striga hermonthica."
        )
    },
    "Soja Biologique": {
        "nom_scientifique": "Glycine max (Bio)",
        "famille_botanique": "Fabaceae (Légumineuse)",
        "est_legumineuse": True,
        "cycle_jours": 90,
        "stades_croissance_jours": {
            "initial": 15,
            "developpement": 25,
            "mi_saison": 35,
            "tardif": 15
        },
        "kc_ini": 0.40,
        "kc_mid": 1.05,
        "kc_end": 0.50,
        "fraction_depletion_p": 0.50,
        "profondeur_racinaire_initiale_m": 0.15,
        "profondeur_racinaire_m": 0.70,
        "besoin_eau_cycle_mm": 450,
        "sensibilite_stress_ky": 0.85,     # Tolérance modérée, reprise végétative après stress temporaire
        "ky_stades": {
            "vegetatif": 0.25,
            "floraison": 0.90,
            "remplissage_grain": 0.70,
            "maturation": 0.20
        },
        "bilan_azote_kg_ha": +50,          # Fixation biologique atmosphérique nette (BNF) par Bradyrhizobium
        "credit_azote_suivant_kg_ha": +35,  # Azote minéralisable résiduel disponible pour la céréale suivante
        "effet_suppression_striga_pct": 75.0, # Germination suicidaire des graines dormantes de Striga hermonthica
        "couverture_sol_max_pct": 85,
        "usle_c_factor": 0.20,             # Feuillage dense limitant fortement le ruissellement
        "valeur_commerciale_kg_fcfa": 380, # Forte prime certifiée bio à l'exportation (PIA / Europe)
        "rendement_moyen_t_ha": 1.5,
        "rendement_potentiel_t_ha": 2.8,
        "varietes_vulgarisees_togo": ["TGx 1448-2E", "TGx 1904-6F", "IRAT 274"],
        "aptitude_regionale": {
            "Savanes": 0.85,
            "Kara": 0.90,
            "Centrale": 1.00,  # Bassin historique soja (Sokodé, Tchamba)
            "Plateaux": 0.95,  # Région leader en production certifiée bio
            "Maritime": 0.75
        },
        "description": (
            "Culture d'exportation stratégique au Togo (1er exportateur africain de soja bio vers l'UE). "
            "Grâce à la symbiose avec Bradyrhizobium japonicum, elle enrichit le sol en azote (+50 kg/ha) "
            "et déclenche la germination suicidaire de Striga, nettoyant la parcelle pour le maïs suivant."
        )
    },
    "Sorgho": {
        "nom_scientifique": "Sorghum bicolor",
        "famille_botanique": "Poaceae (Céréale)",
        "est_legumineuse": False,
        "cycle_jours": 115,
        "stades_croissance_jours": {
            "initial": 20,
            "developpement": 35,
            "mi_saison": 40,
            "tardif": 20
        },
        "kc_ini": 0.30,
        "kc_mid": 1.00,
        "kc_end": 0.55,
        "fraction_depletion_p": 0.65,       # p élevé : extrait jusqu'à 65% de la RU sans réduction de transpiration
        "profondeur_racinaire_initiale_m": 0.25,
        "profondeur_racinaire_m": 1.25,    # Racines profondes explorant les horizons inférieurs du sol
        "besoin_eau_cycle_mm": 400,
        "sensibilite_stress_ky": 0.90,     # Haute résilience à la sécheresse (ajustement osmotique, cuticule cireuse)
        "ky_stades": {
            "vegetatif": 0.20,
            "floraison": 0.95,
            "remplissage_grain": 0.55,
            "maturation": 0.20
        },
        "bilan_azote_kg_ha": -40,          # Prélèvement azoté modéré, valorise l'azote résiduel des légumineuses
        "credit_azote_suivant_kg_ha": 0,
        "effet_suppression_striga_pct": -10.0,
        "couverture_sol_max_pct": 75,
        "usle_c_factor": 0.30,
        "valeur_commerciale_kg_fcfa": 250,
        "rendement_moyen_t_ha": 1.8,
        "rendement_potentiel_t_ha": 3.6,
        "varietes_vulgarisees_togo": ["Sorgho rouge (Kadok)", "Chokwe", "S 35"],
        "aptitude_regionale": {
            "Savanes": 1.00,   # Culture reine de sécurité alimentaire dans le grand Nord
            "Kara": 0.95,
            "Centrale": 0.85,
            "Plateaux": 0.65,
            "Maritime": 0.60
        },
        "description": (
            "Pilier de la sécurité alimentaire au Nord Togo (Savanes et Kara). Doté d'un système racinaire "
            "profond (1.25 m) et d'une régulation stomatique efficace sous Harmattan, il survit à 3 semaines "
            "d'arrêt des pluies sans effondrement de rendement."
        )
    },
    "Niébé (Haricot)": {
        "nom_scientifique": "Vigna unguiculata",
        "famille_botanique": "Fabaceae (Légumineuse)",
        "est_legumineuse": True,
        "cycle_jours": 70,
        "stades_croissance_jours": {
            "initial": 12,
            "developpement": 20,
            "mi_saison": 25,
            "tardif": 13
        },
        "kc_ini": 0.30,
        "kc_mid": 0.95,
        "kc_end": 0.45,
        "fraction_depletion_p": 0.60,
        "profondeur_racinaire_initiale_m": 0.15,
        "profondeur_racinaire_m": 0.60,
        "besoin_eau_cycle_mm": 320,        # Besoin en eau minimal
        "sensibilite_stress_ky": 0.75,     # La plus faible sensibilité au stress parmi les grains alimentaires
        "ky_stades": {
            "vegetatif": 0.20,
            "floraison": 0.75,
            "remplissage_grain": 0.50,
            "maturation": 0.15
        },
        "bilan_azote_kg_ha": +40,          # Fixation symbiotique rapide en sol pauvre
        "credit_azote_suivant_kg_ha": +28,  # Restitution rapide d'azote organique
        "effet_suppression_striga_pct": 65.0, # Efficace pour assainir le sol de Striga
        "couverture_sol_max_pct": 90,      # Effet paillage vivant très protecteur
        "usle_c_factor": 0.15,             # Très forte protection anti-érosion
        "valeur_commerciale_kg_fcfa": 450, # Protéine végétale très valorisée en période de soudure
        "rendement_moyen_t_ha": 1.1,
        "rendement_potentiel_t_ha": 2.2,
        "varietes_vulgarisees_togo": ["IT97K-499-35", "KVx 30-309-6G", "Nafi"],
        "aptitude_regionale": {
            "Savanes": 0.95,
            "Kara": 0.90,
            "Centrale": 0.90,
            "Plateaux": 0.85,
            "Maritime": 1.00   # Idéal en 2ème saison bimodal courte dans le Dahomey Gap
        },
        "description": (
            "Légumineuse vivrière à cycle ultra-court (70 jours) et très faible demande en eau (320 mm). "
            "Couvre le sol à 90% contre le ravinement, résiste aux canicules et assure une trésorerie rapide "
            "aux ménages agricoles lors des soudures précoces."
        )
    },
    "Arachide": {
        "nom_scientifique": "Arachis hypogaea",
        "famille_botanique": "Fabaceae (Légumineuse)",
        "est_legumineuse": True,
        "cycle_jours": 95,
        "stades_croissance_jours": {
            "initial": 18,
            "developpement": 27,
            "mi_saison": 35,
            "tardif": 15
        },
        "kc_ini": 0.40,
        "kc_mid": 1.05,
        "kc_end": 0.55,
        "fraction_depletion_p": 0.50,
        "profondeur_racinaire_initiale_m": 0.20,
        "profondeur_racinaire_m": 0.75,
        "besoin_eau_cycle_mm": 420,
        "sensibilite_stress_ky": 0.70,
        "ky_stades": {
            "vegetatif": 0.20,
            "floraison": 0.80,             # Sensibilité au gynophore (pénétration sous terre)
            "remplissage_grain": 0.55,
            "maturation": 0.20
        },
        "bilan_azote_kg_ha": +35,
        "credit_azote_suivant_kg_ha": +25,
        "effet_suppression_striga_pct": 50.0,
        "couverture_sol_max_pct": 85,
        "usle_c_factor": 0.22,
        "valeur_commerciale_kg_fcfa": 360,
        "rendement_moyen_t_ha": 1.3,
        "rendement_potentiel_t_ha": 2.5,
        "varietes_vulgarisees_togo": ["RMP 12", "Fleur 11", "Moto"],
        "aptitude_regionale": {
            "Savanes": 0.95,
            "Kara": 0.90,
            "Centrale": 0.95,
            "Plateaux": 0.80,
            "Maritime": 0.80
        },
        "description": (
            "Légumineuse oléo-protéagineuse largement cultivée au Centre et au Nord Togo. "
            "Améliore la structure meuble du sol, fixe l'azote atmosphérique et fournit des fanes "
            "à haute valeur fourragère pour l'élevage bovin/ovin."
        )
    },
    "Coton": {
        "nom_scientifique": "Gossypium hirsutum",
        "famille_botanique": "Malvaceae (Fibre industrielle)",
        "est_legumineuse": False,
        "cycle_jours": 150,
        "stades_croissance_jours": {
            "initial": 25,
            "developpement": 35,
            "mi_saison": 55,
            "tardif": 35
        },
        "kc_ini": 0.35,
        "kc_mid": 1.20,
        "kc_end": 0.65,
        "fraction_depletion_p": 0.65,
        "profondeur_racinaire_initiale_m": 0.25,
        "profondeur_racinaire_m": 1.15,
        "besoin_eau_cycle_mm": 680,
        "sensibilite_stress_ky": 0.85,
        "ky_stades": {
            "vegetatif": 0.20,
            "floraison": 0.90,
            "remplissage_grain": 0.50,
            "maturation": 0.25
        },
        "bilan_azote_kg_ha": -95,          # Très forte exportation d'azote minéral
        "credit_azote_suivant_kg_ha": 0,
        "effet_suppression_striga_pct": 0.0,
        "couverture_sol_max_pct": 70,
        "usle_c_factor": 0.35,
        "valeur_commerciale_kg_fcfa": 300, # Prix d'achat garanti par la NSCT au Togo
        "rendement_moyen_t_ha": 1.2,
        "rendement_potentiel_t_ha": 2.4,
        "varietes_vulgarisees_togo": ["STAM 59 A", "STAM 129 B"],
        "aptitude_regionale": {
            "Savanes": 0.90,
            "Kara": 0.95,
            "Centrale": 0.95,
            "Plateaux": 0.80,
            "Maritime": 0.40
        },
        "description": (
            "Principale culture de rente industrielle du Togo (encadrée par la NSCT). "
            "Très longue en terre (150 jours), fortement consommatrice en eau (680 mm) et en nutriments. "
            "Requiert impérativement une alternance avec légumineuses pour stopper l'acidification des sols."
        )
    },
    "Manioc": {
        "nom_scientifique": "Manihot esculenta",
        "famille_botanique": "Euphorbiaceae (Racine & Tubercule)",
        "est_legumineuse": False,
        "cycle_jours": 270,                # Cycle semi-pérenne (9 mois)
        "stades_croissance_jours": {
            "initial": 30,
            "developpement": 60,
            "mi_saison": 120,
            "tardif": 60
        },
        "kc_ini": 0.35,
        "kc_mid": 1.10,
        "kc_end": 0.50,
        "fraction_depletion_p": 0.70,       # Très tolérant au dessèchement superficiel grâce à la chute des feuilles
        "profondeur_racinaire_initiale_m": 0.20,
        "profondeur_racinaire_m": 1.10,
        "besoin_eau_cycle_mm": 750,
        "sensibilite_stress_ky": 0.60,     # Remarquable tolérance globale par mise en dormance temporaire
        "ky_stades": {
            "vegetatif": 0.20,
            "floraison": 0.40,
            "remplissage_grain": 0.50,     # Tubérisation
            "maturation": 0.20
        },
        "bilan_azote_kg_ha": -55,
        "credit_azote_suivant_kg_ha": 0,
        "effet_suppression_striga_pct": 30.0,
        "couverture_sol_max_pct": 80,
        "usle_c_factor": 0.28,
        "valeur_commerciale_kg_fcfa": 140, # Prix moyen tubercules frais bord champ
        "rendement_moyen_t_ha": 14.0,      # Rendement en tubercules frais
        "rendement_potentiel_t_ha": 25.0,
        "varietes_vulgarisees_togo": ["Gbazékouté", "Agbelifia", "TMS 30572"],
        "aptitude_regionale": {
            "Savanes": 0.50,
            "Kara": 0.65,
            "Centrale": 0.85,
            "Plateaux": 1.00,  # Zone d'excellence gari/tapioca
            "Maritime": 0.95   # Terres de barre, aliment de sécurité côtière
        },
        "description": (
            "Culture de subsistance majeure au Sud et Centre Togo (Maritime, Plateaux). "
            "Tolère les sols pauvres et les sécheresses sévères par régulation stomatique. "
            "Fournit le gari et le tapioca consommés à l'échelle nationale."
        )
    }
}


class TropicalCropModel:
    """Modèle physique et dynamique de développement des cultures tropicales (FAO-56)."""

    @classmethod
    def get_crop(cls, crop_name: str) -> Dict[str, Any]:
        """Récupère les paramètres d'une culture avec fallback sécurisé sur le Maïs."""
        return CROP_DATABASE.get(crop_name, CROP_DATABASE["Maïs"])

    @classmethod
    def get_daily_kc(cls, crop_name: str, day: int) -> float:
        """
        Calcule le coefficient cultural journalier Kc(t) selon la courbe FAO-56 à 4 stades :
        1. Stade initial : Kc = Kc_ini constant
        2. Stade développement : Interpolation linéaire de Kc_ini à Kc_mid
        3. Stade mi-saison : Kc = Kc_mid constant
        4. Stade tardif : Interpolation linéaire de Kc_mid à Kc_end
        """
        crop = cls.get_crop(crop_name)
        stades = crop["stades_croissance_jours"]
        kc_ini = crop["kc_ini"]
        kc_mid = crop["kc_mid"]
        kc_end = crop["kc_end"]

        l_ini = stades["initial"]
        l_dev = stades["developpement"]
        l_mid = stades["mi_saison"]
        l_late = stades["tardif"]

        t1 = l_ini
        t2 = t1 + l_dev
        t3 = t2 + l_mid
        t4 = t3 + l_late

        day_bounded = max(0, min(day, t4))

        if day_bounded <= t1:
            return float(kc_ini)
        elif day_bounded <= t2:
            progress = (day_bounded - t1) / max(1, l_dev)
            return float(kc_ini + progress * (kc_mid - kc_ini))
        elif day_bounded <= t3:
            return float(kc_mid)
        else:
            progress = (day_bounded - t3) / max(1, l_late)
            return float(kc_mid + progress * (kc_end - kc_mid))

    @classmethod
    def get_dynamic_root_depth(cls, crop_name: str, day: int) -> float:
        """
        Modèle sigmoïdal d'élongation racinaire dynamique Zr(t) (Borg & Grimes / FAO-56).
        Les racines atteignent leur profondeur maximale Zr_max au milieu de la floraison.
        """
        crop = cls.get_crop(crop_name)
        zr_ini = crop.get("profondeur_racinaire_initiale_m", 0.20)
        zr_max = crop.get("profondeur_racinaire_m", 0.85)
        stades = crop["stades_croissance_jours"]
        t_max_root = stades["initial"] + stades["developpement"] + int(stades["mi_saison"] * 0.5)

        if day <= 0:
            return float(zr_ini)
        if day >= t_max_root:
            return float(zr_max)

        progress = day / max(1, t_max_root)
        # Élongation progressive sigmoïdale
        zr = zr_ini + (zr_max - zr_ini) * (0.5 * (1 - 1 / (1 + progress * 3.5))) * 2.0
        return float(min(zr_max, max(zr_ini, zr)))

    @classmethod
    def get_growth_stage(cls, crop_name: str, day: int) -> str:
        """Identifie le stade phénologique courant pour l'évaluation des risques ciblés."""
        crop = cls.get_crop(crop_name)
        stades = crop["stades_croissance_jours"]
        t1 = stades["initial"]
        t2 = t1 + stades["developpement"]
        t3 = t2 + stades["mi_saison"]

        if day <= t1:
            return "initial"
        elif day <= t2:
            return "developpement"
        elif day <= t3:
            return "mi_saison_critique"
        else:
            return "maturation"
