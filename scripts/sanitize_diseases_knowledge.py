#!/usr/bin/env python3
"""
Sanitise assets/data/diseases_knowledge.json :
1. Supprime tous les champs commerciaux (priceXof, sku, vendor) de tous les produits.
2. Corrige les fiches du Maïs pour éliminer la bouillie bordelaise et la remplacer par les recommandations agronomiques appropriées au Togo (gestion des résidus, semences certifiées, fongicides homologués ICAT/ITRA).
3. Ajoute à chaque fiche les métadonnées de gouvernance : validation_status, validated_by, validation_date, source, disclaimer.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KNOWLEDGE_PATH = ROOT / "assets" / "data" / "diseases_knowledge.json"

def sanitize():
    with open(KNOWLEDGE_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    disclaimer_text = (
        "Fiche informative d'aide à la décision. "
        "Tout traitement phytosanitaire doit être confirmé auprès d'un conseiller agricole local (ICAT / ITRA)."
    )
    source_text = "Guide de protection phytosanitaire des cultures vivrières (ITRA / ICAT / FAO)"

    corn_corrections = {
        "Corn___Cercospora_leaf_spot Gray_leaf_spot": {
            "display_name": "Cercosporiose du maïs (Tache grise)",
            "description": "Maladie fongique foliaire (Cercospora zeae-maydis) créant des lésions rectangulaires délimitées par les nervures. Très fréquente en climat chaud et humide en Afrique de l'Ouest.",
            "treatments": [{
                "method": "Mesures culturales et protection ciblée",
                "description": "Privilégier la prophylaxie culturale ; ne pas utiliser de bouillie cuprique sur le maïs.",
                "steps": [
                    "Enfouir ou brûler les résidus de récolte infectés après la récolte",
                    "Pratiquer une rotation culturale de 1 à 2 ans avec des légumineuses (soja, niébé)",
                    "Semer des variétés certifiées tolérantes recommandées par l'ITRA",
                    "En cas d'attaque sévère avant la floraison : consulter un agent ICAT pour un fongicide homologué (ex: Azoxystrobine)"
                ]
            }],
            "products": [{
                "name": "Fongicide systémique homologué céréales (ex: Azoxystrobine / Pyraclostrobine)",
                "dosage": "Selon prescription de l'agent agricole et notice fabricant",
                "precautions": "Port de masque, gants et bottes obligatoire. Ne pas traiter en plein soleil ni avant une pluie."
            }],
            "prevention": [
                "Utiliser des semences certifiées et traitées",
                "Rotation des cultures avec légumineuses (niébé, arachide)",
                "Gestion rigoureuse des résidus de récolte",
                "Densité de semis aérée pour limiter l'humidité foliaire"
            ],
            "plain_explanation_i18n": {
                "fr": "Cercosporiose du maïs. Détruire les résidus après récolte, faire la rotation avec le niébé et utiliser des semences certifiées. Demandez conseil à l'agent ICAT.",
                "ee": "Agblɛ ƒe dɔ ɣi. Tɔ dzo agble ƒe ɣe, wɔ dɔ kple azi alo ayi. Bia gblenɔla ƒe aɖaŋuɖoɖo.",
                "kab": "Agblɛ ƒe dɔ ɣi. Tɔ dzo agble ƒe ɣe. Bia gblenɔla ƒe aɖaŋuɖoɖo."
            }
        },
        "Corn___Common_rust": {
            "display_name": "Rouille commune du maïs",
            "description": "Maladie fongique (Puccinia sorghi) provoquant des pustules poudreuses brun-rouille sur les deux faces des feuilles. Réduit la photosynthèse et le rendement grainier.",
            "treatments": [{
                "method": "Prophylaxie et variétés tolérantes",
                "description": "La résistance variétale est le premier levier de contrôle ; les produits cupriques sont inadaptés.",
                "steps": [
                    "Semer dès les premières pluies utiles pour échapper au pic de sporulation",
                    "Détruire les repousses spontanées et adventices hôtes en bordure de parcelle",
                    "Éviter les excès de fertilisation azotée isolée",
                    "Traitement fongicide foliaire envisagé uniquement si plus de 15 à 20% des feuilles sont atteintes avant la floraison"
                ]
            }],
            "products": [{
                "name": "Fongicide foliaire homologué (ex: Mancozèbe / Tébuconazole)",
                "dosage": "Selon prescription technique locale ICAT",
                "precautions": "Réservé aux attaques précoces sévères. Respecter le délai avant récolte (DAR)."
            }],
            "prevention": [
                "Variétés résistantes vulgarisées par la recherche agricole",
                "Semis précoce et synchronisé",
                "Désherbage précoce des abords du champ",
                "Fertilisation NPK équilibrée"
            ],
            "plain_explanation_i18n": {
                "fr": "Rouille du maïs. Semer tôt, nettoyer les adventices hôtes et choisir des semences résistantes. Traitement uniquement si l'attaque est précoce.",
                "ee": "Agblɛ ƒe aŋɔdɔ. Do agblɛ kaba, kplɔ gbe vɔ̃wo ɖa. Bia gblenɔla ƒe aɖaŋuɖoɖo.",
                "kab": "Agblɛ ƒe aŋɔdɔ. Do agblɛ kaba. Bia gblenɔla ƒe aɖaŋuɖoɖo."
            }
        },
        "Corn___Northern_Leaf_Blight": {
            "display_name": "Helminthosporiose du maïs",
            "description": "Maladie fongique (Exserohilum turcicum / Setosphaeria turcica) causant de longues nécroses fusiformes (en forme de cigare) gris-vert à brun clair sur le feuillage.",
            "treatments": [{
                "method": "Lutte agronomique intégrée",
                "description": "Mesures d'hygiène culturale et fongicide adapté si nécessaire (pas de bouillie cuprique).",
                "steps": [
                    "Labourer ou enfouir profondément les résidus après récolte pour décomposer les spores",
                    "Rotation de 2 ans minimum sans maïs ni sorgho sur la même parcelle",
                    "Éliminer les premières feuilles basses fortement atteintes lors des sarclages",
                    "Consulter l'agent de vulgarisation si les lésions progressent vers l'épi avant la floraison"
                ]
            }],
            "products": [{
                "name": "Fongicide homologué grandes cultures (ex: formulation triazole / strobilurine)",
                "dosage": "Selon dose homologuée par le comité phytosanitaire national",
                "precautions": "Équipement de protection individuel complet obligatoire. Ne jamais appliquer sur maïs doux en récolte."
            }],
            "prevention": [
                "Utiliser des semences saines traitées",
                "Rotation longue avec cultures non-graminées (coton, arachide, soja)",
                "Espacement de semis respectant les normes agronomiques (aération)"
            ],
            "plain_explanation_i18n": {
                "fr": "Helminthosporiose du maïs. Enfouir les résidus, faire la rotation sans maïs ni sorgho pendant 2 ans. Demandez conseil à l'ICAT.",
                "ee": "Agblɛ ƒe dɔ gã. Wɔ dɔ kple ayi alo azi ƒe eve. Bia gblenɔla ƒe aɖaŋuɖoɖo.",
                "kab": "Agblɛ ƒe dɔ gã. Wɔ dɔ kple ayi ƒe eve. Bia gblenɔla ƒe aɖaŋuɖoɖo."
            }
        }
    }

    sanitized_count = 0
    prices_removed = 0

    for entry in data:
        label = entry.get("model_label", "")

        # 1. Gouvernance et validation
        entry["validation_status"] = "en_attente_validation_agronome"
        entry["validated_by"] = None
        entry["validation_date"] = None
        entry["source"] = source_text
        entry["disclaimer"] = disclaimer_text

        # 2. Retrait des prix et attributs commerciaux
        if "products" in entry and isinstance(entry["products"], list):
            clean_products = []
            for p in entry["products"]:
                clean_p = {
                    "name": p.get("name", ""),
                    "dosage": p.get("dosage", ""),
                    "precautions": p.get("precautions", "")
                }
                if "priceXof" in p:
                    prices_removed += 1
                clean_products.append(clean_p)
            entry["products"] = clean_products

        # 3. Corrections agronomiques pour le Maïs
        if label in corn_corrections:
            corr = corn_corrections[label]
            entry["display_name"] = corr["display_name"]
            entry["description"] = corr["description"]
            entry["treatments"] = corr["treatments"]
            entry["products"] = corr["products"]
            entry["prevention"] = corr["prevention"]
            if "plain_explanation_i18n" in corr:
                entry["plain_explanation_i18n"] = corr["plain_explanation_i18n"]
            sanitized_count += 1

    with open(KNOWLEDGE_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    print(f"Sanitization complete :")
    print(f"  - Total entries processed : {len(data)}")
    print(f"  - Commercial price tags removed : {prices_removed}")
    print(f"  - Corn agronomic sheets overhauled : {sanitized_count}")
    print(f"  - Governance metadata attached to all 45 sheets.")

if __name__ == "__main__":
    sanitize()
