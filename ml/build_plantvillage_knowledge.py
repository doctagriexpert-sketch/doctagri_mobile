"""
Construit les entrées de la base de connaissances pour le modèle
PlantVillage (39 classes) et les fusionne avec le JSON existant.

Usage:
    py -3.12 ml/build_plantvillage_knowledge.py

Le script :
  - charge `assets/data/diseases_knowledge.json`
  - ajoute / met à jour les entrées correspondant aux labels PlantVillage
  - écrit le résultat formaté en JSON UTF-8 (indent=4) au même endroit

Les entrées contiennent des traductions courtes en Ewe (`ee`) et Kabyè
(`kab`) pour le `display_name`, la `description` et une explication
plain text optimisée pour la lecture vocale.

NOTE: Les traductions Ewe / Kabyè sont des approximations utiles à la
diffusion vocale. Elles devront être relues par un locuteur natif
avant la mise en production. Ce script garantit que CHAQUE label
dispose d'au moins UNE entrée — l'app ne reste donc jamais muette.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KNOWLEDGE_PATH = ROOT / "assets" / "data" / "diseases_knowledge.json"


def make_entry(label: str,
               culture: str,
               display_name: str,
               description: str,
               severity: str,
               symptoms: list[str],
               treatments: list[dict],
               products: list[dict],
               prevention: list[str],
               i18n_name: dict[str, str] | None = None,
               i18n_desc: dict[str, str] | None = None,
               i18n_plain: dict[str, str] | None = None) -> dict:
    entry = {
        "model_label": label,
        "culture": culture,
        "display_name": display_name,
        "description": description,
        "severity": severity,
        "symptoms": symptoms,
        "treatments": treatments,
        "products": products,
        "prevention": prevention,
    }
    if i18n_name:
        entry["display_name_i18n"] = i18n_name
    if i18n_desc:
        entry["description_i18n"] = i18n_desc
    if i18n_plain:
        entry["plain_explanation_i18n"] = i18n_plain
    return entry


def healthy(label: str, culture: str,
            i18n_name: dict[str, str], i18n_desc: dict[str, str],
            i18n_plain: dict[str, str]) -> dict:
    return make_entry(
        label=label,
        culture=culture,
        display_name=f"{culture} en bonne santé",
        description=f"Votre {culture.lower()} ne présente aucun signe visible de maladie. La plante semble saine. Continuez vos bonnes pratiques agricoles.",
        severity="aucune",
        symptoms=[],
        treatments=[{
            "method": "Entretien préventif",
            "description": "Continuez à surveiller régulièrement vos plants.",
            "steps": [
                "Surveiller chaque semaine l'apparition de taches sur les feuilles",
                "Maintenir un bon espacement entre les plants",
                "Arroser tôt le matin pour éviter l'humidité prolongée sur les feuilles",
                "Désherber régulièrement"
            ]
        }],
        products=[],
        prevention=[
            "Utiliser des semences saines",
            "Rotation des cultures",
            "Bon drainage du sol",
            "Surveillance régulière"
        ],
        i18n_name=i18n_name, i18n_desc=i18n_desc, i18n_plain=i18n_plain,
    )


# Banque d'entrées PlantVillage (les plus pertinentes pour l'Afrique de l'Ouest)
ENTRIES: list[dict] = []

# ───── Background (rejet) ─────
ENTRIES.append(make_entry(
    label="Background_without_leaves",
    culture="Inconnu",
    display_name="Image inutilisable",
    description="L'image ne contient pas de feuille bien visible. Reprenez la photo avec une feuille bien centrée, à plat, et avec un éclairage suffisant.",
    severity="aucune",
    symptoms=[],
    treatments=[{
        "method": "Reprendre une photo",
        "description": "Pour un meilleur diagnostic.",
        "steps": [
            "Prendre la photo en plein jour, lumière naturelle",
            "Cadrer une feuille seule, à plat",
            "Distance d'environ 20 centimètres",
            "Éviter les ombres et les reflets"
        ]
    }],
    products=[],
    prevention=[],
    i18n_name={
        "ee": "Foto megblɔ nu o",
        "kab": "Foto megblɔ nu o",
    },
    i18n_desc={
        "ee": "Foto la mefia ati ƒe lãme aɖeke o. Tsɔ foto bubu, da lãme la ɖe titina, eye nàwɔ kekeli nyuie.",
        "kab": "Foto la mefia lãme aɖeke o. Tsɔ foto bubu lè kekeli nyuie me.",
    },
    i18n_plain={
        "fr": "Photo inutilisable. Reprenez avec une feuille bien visible au centre, lumière naturelle.",
        "ee": "Foto la megblɔ nu o. Wɔ foto yeye, da lãme ɖe titina, kekeli nyuie.",
        "kab": "Foto la mèfia nu o. Wɔ foto yeye lè kekeli nyuie me.",
    },
))

# ───── TOMATE ─────
ENTRIES.append(make_entry(
    label="Tomato___Bacterial_spot",
    culture="Tomate",
    display_name="Tache bactérienne de la tomate",
    description="La tache bactérienne (Xanthomonas) provoque de petites taches sombres sur les feuilles, fruits et tiges. Elle peut détruire 50 % de la récolte si elle n'est pas contrôlée tôt.",
    severity="grave",
    symptoms=[
        "Petites taches noires ou brun foncé sur les feuilles",
        "Taches concentriques sur les fruits, parfois fissurées",
        "Jaunissement progressif et chute des feuilles",
        "Lésions humides sur les tiges"
    ],
    treatments=[{
        "method": "Bouillie cuprique + assainissement",
        "description": "Combiner cuivre et hygiène culturale.",
        "steps": [
            "Retirer et brûler toutes les feuilles infectées",
            "Désinfecter les outils avec de l'eau de javel diluée",
            "Pulvériser de la bouillie bordelaise tous les 7-10 jours",
            "Ne jamais arroser le feuillage : irriguer au pied"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "200 g pour 20 L d'eau",
         "precautions": "Ne pas appliquer en plein soleil.",
         "priceXof": 6500, "sku": "DGA-1001", "vendor": "DoctAgri Shop"}
    ],
    prevention=[
        "Semences saines certifiées",
        "Rotation des cultures (3 ans sans solanacées)",
        "Espacement suffisant pour aérer le feuillage",
        "Paillage pour limiter les éclaboussures"
    ],
    i18n_name={
        "ee": "Tomati ƒe dɔmegblẽ bacteria",
        "kab": "Tomati ƒe dɔmegblẽ bacteria",
    },
    i18n_desc={
        "ee": "Dɔmegblẽ bacteria sia daa atsɔ̃ yibɔ ɖe lãme kple atsiame, eye wòawu rendement la ƒe afa ne mèkpɔe nu kaba o.",
        "kab": "Dɔmegblẽ bacteria sia daa atsɔ̃ yibɔ ɖe lãme kple atsiame, eye wòawu rendement la ƒe afa.",
    },
    i18n_plain={
        "fr": "Maladie bactérienne grave de la tomate. Petites taches noires sur feuilles et fruits. Traitement au cuivre nécessaire.",
        "ee": "Tomati ƒe dɔ sesẽ. Atsɔ̃ yibɔ sue ɖe lãme kple atsiame. Wɔ dɔ kple kɔpe.",
        "kab": "Tomati ƒe dɔ sesẽ. Atsɔ̃ yibɔ sue ɖe lãme kple atsiame. Wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Early_blight",
    culture="Tomate",
    display_name="Alternariose de la tomate",
    description="L'alternariose (Alternaria solani) est un champignon qui crée des taches brunes en cible sur les feuilles basses. Sans traitement, elle remonte et tue la plante.",
    severity="grave",
    symptoms=[
        "Taches brunes en cercles concentriques sur feuilles basses",
        "Feuilles qui jaunissent puis sèchent du bas vers le haut",
        "Taches noires en creux à la base des fruits",
        "Tiges avec lésions sombres"
    ],
    treatments=[{
        "method": "Fongicide cuivrique + retrait des feuilles atteintes",
        "description": "Action rapide pour sauver la plante.",
        "steps": [
            "Couper les feuilles malades, brûler hors du champ",
            "Pulvériser bouillie cuprique tous les 10 jours",
            "Pailler le sol pour bloquer les spores",
            "Ne pas mouiller le feuillage à l'arrosage"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "Pulvériser le matin tôt ou le soir.",
         "priceXof": 6500, "sku": "DGA-1001", "vendor": "DoctAgri Shop"}
    ],
    prevention=[
        "Variétés tolérantes",
        "Rotation 3 ans",
        "Désinfection des outils",
        "Paillage du sol"
    ],
    i18n_name={
        "ee": "Tomati ƒe dɔmegblẽ kabakaba",
        "kab": "Tomati ƒe dɔmegblẽ kabakaba",
    },
    i18n_desc={
        "ee": "Atsiame ɖe lãme megbe la dze, eye wòɖu lãmewo katã ne mèwɔ dɔ o.",
        "kab": "Atsiame ɖe lãme megbe la dze, eye wòɖu lãmewo katã.",
    },
    i18n_plain={
        "fr": "Champignon courant de la tomate. Taches brunes en cible sur les feuilles basses. Traiter vite au cuivre.",
        "ee": "Tomati ƒe dɔ. Atsɔ̃ yibɔ ɖe lãme. Wɔ dɔ kple kɔpe kabakaba.",
        "kab": "Tomati ƒe dɔ. Atsɔ̃ yibɔ ɖe lãme. Wɔ dɔ kple kɔpe kabakaba.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Late_blight",
    culture="Tomate",
    display_name="Mildiou de la tomate",
    description="Le mildiou (Phytophthora infestans) est extrêmement destructeur. Il peut anéantir un champ en 7 jours en saison humide. Les feuilles brunissent et un duvet blanc apparaît au revers.",
    severity="critique",
    symptoms=[
        "Taches huileuses gris-vert sur les feuilles",
        "Duvet blanc cotonneux sous les feuilles humides",
        "Tiges noircies",
        "Fruits avec taches brunes dures"
    ],
    treatments=[{
        "method": "Traitement urgent + arrachage",
        "description": "Réagir dans les 24 h.",
        "steps": [
            "Arracher et brûler toute plante très atteinte",
            "Pulvériser un fongicide cuprique sur les plants restants",
            "Renouveler tous les 5-7 jours",
            "Aérer la parcelle (couper les feuilles basses)"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "25 g/L",
         "precautions": "En traitement curatif, doubler la fréquence.",
         "priceXof": 6500, "sku": "DGA-1001", "vendor": "DoctAgri Shop"}
    ],
    prevention=[
        "Variétés résistantes",
        "Espacement large",
        "Éviter l'irrigation par aspersion",
        "Surveillance quotidienne en saison humide"
    ],
    i18n_name={
        "ee": "Tomati ƒe mildiou",
        "kab": "Tomati ƒe mildiou",
    },
    i18n_desc={
        "ee": "Dɔmegblẽ sesẽ aɖe wòawu agble blibo le ŋkeke adre me ne tsi wɔ.",
        "kab": "Dɔmegblẽ sesẽ aɖe wòawu agble blibo le ŋkeke adre me.",
    },
    i18n_plain={
        "fr": "Maladie très dangereuse. Peut tuer le champ en une semaine. Traiter immédiatement et arracher les plants atteints.",
        "ee": "Dɔ sesẽ ŋutɔ. Aɖu agble le kwasiɖa ɖeka me. Wɔ dɔ enumake.",
        "kab": "Dɔ sesẽ ŋutɔ. Aɖu agble le kwasiɖa ɖeka me. Wɔ dɔ enumake.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Leaf_Mold",
    culture="Tomate",
    display_name="Cladosporiose de la tomate",
    description="Maladie fongique qui apparaît surtout sous serre ou par humidité élevée. Crée des feutrages verts-jaunes au revers des feuilles.",
    severity="modéré",
    symptoms=[
        "Taches jaunes diffuses sur le dessus des feuilles",
        "Feutrage vert olive au revers des feuilles",
        "Feuilles qui se dessèchent et tombent"
    ],
    treatments=[{
        "method": "Aération + fongicide",
        "description": "Réduire l'humidité.",
        "steps": [
            "Aérer la parcelle (couper feuilles basses)",
            "Réduire l'arrosage du feuillage",
            "Pulvériser bouillie cuprique tous les 10 jours"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "Tôt le matin de préférence.",
         "priceXof": 6500, "sku": "DGA-1001", "vendor": "DoctAgri Shop"}
    ],
    prevention=["Aération", "Variétés résistantes"],
    i18n_name={"ee": "Tomati ƒe dɔ tsia", "kab": "Tomati ƒe dɔ tsia"},
    i18n_desc={
        "ee": "Dɔ aɖe wòdze le tsi gbɔ̃, ena wòana atsɔ̃ ɖe lãme megbe.",
        "kab": "Dɔ aɖe wòdze le tsi gbɔ̃ me.",
    },
    i18n_plain={
        "fr": "Maladie fongique liée à l'humidité. Aérez la parcelle et traitez au cuivre.",
        "ee": "Tsi gbɔ̃ ƒe dɔ. Wɔ ɖe agble la nu eye nàwɔ dɔ kple kɔpe.",
        "kab": "Tsi gbɔ̃ ƒe dɔ. Wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Septoria_leaf_spot",
    culture="Tomate",
    display_name="Septoriose de la tomate",
    description="Petites taches circulaires gris-clair entourées d'un halo brun. Provoque une chute massive des feuilles et baisse fortement le rendement.",
    severity="grave",
    symptoms=[
        "Petites taches circulaires gris-clair (2-5 mm)",
        "Halo brun foncé autour des taches",
        "Petits points noirs au centre (pycnides)",
        "Défoliation rapide du bas vers le haut"
    ],
    treatments=[{
        "method": "Fongicide + retrait feuilles atteintes",
        "description": "",
        "steps": [
            "Retirer feuilles infectées et brûler",
            "Bouillie bordelaise toutes les semaines",
            "Pailler le sol"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Rotation 3 ans", "Variétés tolérantes"],
    i18n_name={"ee": "Tomati ƒe dɔ Septoria", "kab": "Tomati ƒe dɔ Septoria"},
    i18n_desc={
        "ee": "Atsɔ̃ sue ɣi ɖe lãme. Lãmewo dzudzɔna kabakaba.",
        "kab": "Atsɔ̃ sue ɣi ɖe lãme.",
    },
    i18n_plain={
        "fr": "Petites taches grises sur les feuilles. Retirer feuilles atteintes et traiter au cuivre.",
        "ee": "Atsɔ̃ sue ɣi ɖe lãme. Ɖe lãmewo ɖa nàwɔ dɔ.",
        "kab": "Atsɔ̃ sue ɣi ɖe lãme. Wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Spider_mites Two-spotted_spider_mite",
    culture="Tomate",
    display_name="Acariens (tétranyques) de la tomate",
    description="Petits acariens rouges qui sucent la sève. Provoquent un jaunissement piqueté et de fines toiles. Préfèrent la chaleur sèche.",
    severity="modéré",
    symptoms=[
        "Petits points jaunes sur les feuilles",
        "Toiles fines au revers",
        "Feuilles qui jaunissent puis brunissent",
        "Plante affaiblie, fruits petits"
    ],
    treatments=[{
        "method": "Acaricide + brumisation",
        "description": "Augmenter l'humidité fait fuir les acariens.",
        "steps": [
            "Pulvériser de l'eau sur les feuilles le matin",
            "Appliquer huile de neem 5 mL/L",
            "Renouveler tous les 5 jours",
            "Lâcher des prédateurs (Phytoseiulus) si possible"
        ]
    }],
    products=[
        {"name": "Huile de neem", "dosage": "5 mL/L",
         "precautions": "Le soir.",
         "priceXof": 3800, "sku": "DGA-2002", "vendor": "DoctAgri Shop"}
    ],
    prevention=["Brumisation régulière", "Pas d'excès d'azote"],
    i18n_name={"ee": "Tomati ƒe lã sue dzĩ", "kab": "Tomati ƒe lã sue dzĩ"},
    i18n_desc={
        "ee": "Lã sue dzĩ ƒo lãme ƒu, ena wòhena tsitsi.",
        "kab": "Lã sue dzĩ ƒo lãme ƒu.",
    },
    i18n_plain={
        "fr": "Acariens rouges. Vaporiser eau le matin et traiter à l'huile de neem.",
        "ee": "Lã sue dzĩ. Hlɔ tsi ɖe lãme nàwɔ dɔ kple amĩ neem.",
        "kab": "Lã sue dzĩ. Hlɔ tsi ɖe lãme nàwɔ dɔ kple amĩ neem.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Target_Spot",
    culture="Tomate",
    display_name="Tache cible de la tomate",
    description="Champignon qui crée des taches en cible (cercles concentriques) sur feuilles et fruits. Fréquent en saison humide.",
    severity="modéré",
    symptoms=[
        "Taches en cible sur feuilles",
        "Taches sombres sur les fruits",
        "Défoliation progressive"
    ],
    treatments=[{
        "method": "Fongicide cuprique",
        "description": "",
        "steps": ["Bouillie bordelaise toutes les semaines",
                  "Retirer feuilles atteintes"]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Aération", "Rotation"],
    i18n_name={"ee": "Tomati ƒe dɔ atsɔ̃ kotokpe",
               "kab": "Tomati ƒe dɔ atsɔ̃ kotokpe"},
    i18n_desc={
        "ee": "Atsɔ̃ kotokpe ɖe lãme kple atsiame.",
        "kab": "Atsɔ̃ kotokpe ɖe lãme kple atsiame.",
    },
    i18n_plain={
        "fr": "Taches en cible sur la tomate. Traiter au cuivre.",
        "ee": "Atsɔ̃ kotokpe ɖe tomati. Wɔ dɔ kple kɔpe.",
        "kab": "Atsɔ̃ kotokpe ɖe tomati. Wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    culture="Tomate",
    display_name="TYLCV : Virus du jaunissement et frisolée de la tomate",
    description="Virus très grave transmis par les aleurodes (Bemisia tabaci). Provoque l'enroulement et le jaunissement des jeunes feuilles, et un nanisme sévère. Les plants infectés tôt ne produisent pas de fruits.",
    severity="critique",
    symptoms=[
        "Jeunes feuilles enroulées vers le haut",
        "Jaunissement et rabougrissement",
        "Plante naine",
        "Très peu de fruits, fruits déformés"
    ],
    treatments=[{
        "method": "Lutte contre les aleurodes (pas de cure du virus)",
        "description": "Aucun produit ne soigne le virus.",
        "steps": [
            "Arracher et brûler les plants très atteints",
            "Poser des pièges jaunes contre les aleurodes",
            "Pulvériser huile de neem le soir",
            "Replanter avec variétés résistantes"
        ]
    }],
    products=[
        {"name": "Pièges jaunes collants", "dosage": "20-30 pièges/ha",
         "precautions": "", "priceXof": 4500, "sku": "DGA-2001",
         "vendor": "DoctAgri Shop"},
        {"name": "Huile de neem", "dosage": "5 mL/L",
         "precautions": "Soir.", "priceXof": 3800, "sku": "DGA-2002",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=[
        "Variétés résistantes (Tylka, etc.)",
        "Filets anti-insectes en pépinière",
        "Élimination des mauvaises herbes hôtes"
    ],
    i18n_name={
        "ee": "Tomati ƒe dɔmegblẽ ƒe enrolement",
        "kab": "Tomati ƒe dɔmegblẽ ƒe enrolement",
    },
    i18n_desc={
        "ee": "Virus sesẽ ŋutɔ. Lãmewo melena, atia mediena o.",
        "kab": "Virus sesẽ ŋutɔ. Lãmewo melena, atia mediena o.",
    },
    i18n_plain={
        "fr": "Virus très grave transmis par les aleurodes. Pas de cure. Arracher et planter une variété résistante.",
        "ee": "Virus sesẽ. Hopo plant si dze, dzra atikomeli sesẽ.",
        "kab": "Virus sesẽ. Hopo plant si dze, dzra atikomeli sesẽ.",
    },
))

ENTRIES.append(make_entry(
    label="Tomato___Tomato_mosaic_virus",
    culture="Tomate",
    display_name="Virus de la mosaïque de la tomate (ToMV)",
    description="Virus transmis par contact (mains, outils, semences). Provoque mosaïque verte/jaune, déformation et baisse de rendement.",
    severity="grave",
    symptoms=[
        "Mosaïque vert clair / vert foncé sur les feuilles",
        "Feuilles déformées, en filament",
        "Fruits petits, parfois marbrés"
    ],
    treatments=[{
        "method": "Hygiène stricte (pas de cure)",
        "description": "",
        "steps": [
            "Se laver les mains avant et après manipulation",
            "Désinfecter les outils à l'eau de javel",
            "Arracher et brûler les plants atteints",
            "Ne jamais fumer près des plants"
        ]
    }],
    products=[],
    prevention=[
        "Semences certifiées",
        "Variétés résistantes",
        "Désinfection des outils"
    ],
    i18n_name={
        "ee": "Tomati ƒe virus mosaïque",
        "kab": "Tomati ƒe virus mosaïque",
    },
    i18n_desc={
        "ee": "Virus sia tsɔna kple asi kple dɔwɔnu. Hopo plant si dze.",
        "kab": "Virus sia tsɔna kple asi kple dɔwɔnu.",
    },
    i18n_plain={
        "fr": "Virus contagieux par contact. Hygiène stricte des mains et outils. Arracher les plants atteints.",
        "ee": "Virus tsɔna kple asi. Klɔ asi kple dɔwɔnu. Hopo plant si dze.",
        "kab": "Virus tsɔna kple asi. Klɔ asi kple dɔwɔnu. Hopo plant si dze.",
    },
))

ENTRIES.append(healthy(
    "Tomato___healthy", "Tomate",
    i18n_name={"ee": "Tomati le lãmesẽ me", "kab": "Tomati le lãmesẽ me"},
    i18n_desc={
        "ee": "Wò tomati la le lãmesẽ me. Yi edzi nàwɔ wò agble nyuie.",
        "kab": "Wò tomati la le lãmesẽ me. Yi edzi nàwɔ wò agble nyuie.",
    },
    i18n_plain={
        "fr": "Tomate en bonne santé. Continuez la surveillance et les bonnes pratiques.",
        "ee": "Tomati la le lãmesẽ me. Yi edzi.",
        "kab": "Tomati la le lãmesẽ me. Yi edzi.",
    },
))

# ───── MAÏS ─────
ENTRIES.append(make_entry(
    label="Corn___Cercospora_leaf_spot Gray_leaf_spot",
    culture="Maïs",
    display_name="Cercosporiose grise du maïs",
    description="Champignon qui crée des taches grises rectangulaires entre les nervures. Très destructeur en culture de maïs en Afrique de l'Ouest.",
    severity="grave",
    symptoms=[
        "Taches grises rectangulaires entre les nervures",
        "Lésions qui s'allongent et fusionnent",
        "Feuilles qui sèchent à partir du bas",
        "Réduction nette du rendement"
    ],
    treatments=[{
        "method": "Fongicide + résidus",
        "description": "",
        "steps": [
            "Brûler les résidus de récolte",
            "Pulvériser fongicide à base de cuivre",
            "Rotation avec légumineuses"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Variétés résistantes", "Rotation", "Brûler résidus"],
    i18n_name={"ee": "Agblɛ ƒe dɔmegblẽ ɣi", "kab": "Agblɛ ƒe dɔmegblẽ ɣi"},
    i18n_desc={
        "ee": "Atsɔ̃ ɣi ɖe lãme me. Wòawu agbe la sesẽ.",
        "kab": "Atsɔ̃ ɣi ɖe lãme me.",
    },
    i18n_plain={
        "fr": "Maladie grise du maïs. Brûler les résidus, traiter au cuivre, faire la rotation.",
        "ee": "Agblɛ ƒe dɔ ɣi. Tɔ dzo agble ƒe ɣe, wɔ dɔ kple kɔpe.",
        "kab": "Agblɛ ƒe dɔ ɣi. Tɔ dzo agble ƒe ɣe, wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(make_entry(
    label="Corn___Common_rust",
    culture="Maïs",
    display_name="Rouille commune du maïs",
    description="Champignon (Puccinia sorghi) qui produit des pustules rouille (orange-brun) sur les deux faces des feuilles. Affaiblit la plante.",
    severity="modéré",
    symptoms=[
        "Pustules rouge-brun sur les feuilles",
        "Pustules au revers et au-dessus",
        "Feuilles affaiblies, jaunissement"
    ],
    treatments=[{
        "method": "Fongicide si infestation forte",
        "description": "",
        "steps": [
            "Surveiller dès les premiers stades",
            "Pulvériser bouillie cuprique si > 20 % feuilles atteintes"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Variétés résistantes", "Semis précoces"],
    i18n_name={"ee": "Agblɛ ƒe rouille", "kab": "Agblɛ ƒe rouille"},
    i18n_desc={
        "ee": "Atsɔ̃ dzĩ-yibɔ ɖe lãme. Mesesẽ akpa o.",
        "kab": "Atsɔ̃ dzĩ-yibɔ ɖe lãme. Mesesẽ akpa o.",
    },
    i18n_plain={
        "fr": "Rouille du maïs. Surveiller et traiter au cuivre si l'attaque est forte.",
        "ee": "Agblɛ ƒe dɔmegblẽ dzĩ. Kpɔe nyuie, wɔ dɔ ne edze.",
        "kab": "Agblɛ ƒe dɔmegblẽ dzĩ. Kpɔe nyuie, wɔ dɔ ne edze.",
    },
))

ENTRIES.append(make_entry(
    label="Corn___Northern_Leaf_Blight",
    culture="Maïs",
    display_name="Helminthosporiose du maïs",
    description="Champignon (Setosphaeria turcica) qui crée de longues lésions grises en forme de cigare sur les feuilles. Peut causer 50 % de pertes.",
    severity="grave",
    symptoms=[
        "Lésions allongées en forme de cigare (5-15 cm)",
        "Couleur gris-vert puis brun clair",
        "Apparition d'abord sur les feuilles basses"
    ],
    treatments=[{
        "method": "Fongicide + résidus",
        "description": "",
        "steps": [
            "Brûler résidus de récolte",
            "Pulvériser bouillie cuprique tous les 10 jours",
            "Variétés tolérantes pour la prochaine saison"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Rotation", "Variétés résistantes"],
    i18n_name={
        "ee": "Agblɛ ƒe dɔ legble",
        "kab": "Agblɛ ƒe dɔ legble",
    },
    i18n_desc={
        "ee": "Atsɔ̃ legble ɣi-yibɔ ɖe lãme. Sesẽ ŋutɔ.",
        "kab": "Atsɔ̃ legble ɣi-yibɔ ɖe lãme. Sesẽ ŋutɔ.",
    },
    i18n_plain={
        "fr": "Maladie grave du maïs. Longues taches en cigare. Brûler résidus et traiter au cuivre.",
        "ee": "Agblɛ ƒe dɔ sesẽ. Atsɔ̃ legble. Tɔ dzo ɣe, wɔ dɔ.",
        "kab": "Agblɛ ƒe dɔ sesẽ. Atsɔ̃ legble. Tɔ dzo ɣe, wɔ dɔ.",
    },
))

ENTRIES.append(healthy(
    "Corn___healthy", "Maïs",
    i18n_name={"ee": "Agblɛ le lãmesẽ me", "kab": "Agblɛ le lãmesẽ me"},
    i18n_desc={
        "ee": "Wò agblɛ la le lãmesẽ me. Yi edzi nàwɔ wò agble nyuie.",
        "kab": "Wò agblɛ la le lãmesẽ me. Yi edzi.",
    },
    i18n_plain={
        "fr": "Maïs en bonne santé. Continuez la surveillance.",
        "ee": "Agblɛ la le lãmesẽ me. Yi edzi.",
        "kab": "Agblɛ la le lãmesẽ me. Yi edzi.",
    },
))

# ───── POMME DE TERRE ─────
ENTRIES.append(make_entry(
    label="Potato___Early_blight",
    culture="Pomme de terre",
    display_name="Alternariose de la pomme de terre",
    description="Champignon (Alternaria solani) provoquant des taches en cible sur les feuilles. Apparaît surtout en fin de saison sur plants stressés.",
    severity="grave",
    symptoms=[
        "Taches brunes en cercles concentriques",
        "Feuilles basses qui jaunissent et sèchent",
        "Tubercules avec lésions sombres"
    ],
    treatments=[{
        "method": "Fongicide cuprique",
        "description": "",
        "steps": [
            "Retirer feuilles atteintes",
            "Bouillie bordelaise tous les 10 jours",
            "Bonne fertilisation N-K"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Rotation 3 ans", "Variétés tolérantes"],
    i18n_name={
        "ee": "Kaklo ƒe dɔ kabakaba",
        "kab": "Kaklo ƒe dɔ kabakaba",
    },
    i18n_desc={
        "ee": "Atsɔ̃ kotokpe ɖe lãme. Wòawu kaklo la.",
        "kab": "Atsɔ̃ kotokpe ɖe lãme. Wòawu kaklo la.",
    },
    i18n_plain={
        "fr": "Champignon courant. Taches en cible sur les feuilles. Traiter au cuivre.",
        "ee": "Kaklo ƒe dɔ. Atsɔ̃ ɖe lãme. Wɔ dɔ kple kɔpe.",
        "kab": "Kaklo ƒe dɔ. Atsɔ̃ ɖe lãme. Wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(make_entry(
    label="Potato___Late_blight",
    culture="Pomme de terre",
    display_name="Mildiou de la pomme de terre",
    description="Phytophthora infestans, le même responsable de la grande famine irlandaise. Maladie la plus destructrice de la pomme de terre.",
    severity="critique",
    symptoms=[
        "Taches huileuses gris-vert puis brunes",
        "Duvet blanc cotonneux au revers humide",
        "Tubercules avec pourriture brun-rouge",
        "Plant qui se flétrit en quelques jours"
    ],
    treatments=[{
        "method": "Traitement urgent",
        "description": "",
        "steps": [
            "Pulvériser fongicide cuprique tous les 5 jours",
            "Couper les fanes 2 semaines avant la récolte",
            "Récolter par temps sec",
            "Détruire les plants gravement atteints"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "25 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Variétés résistantes", "Buttage haut", "Pas d'arrosage du feuillage"],
    i18n_name={"ee": "Kaklo ƒe mildiou", "kab": "Kaklo ƒe mildiou"},
    i18n_desc={
        "ee": "Dɔ sesẽ ŋutɔ. Aɖu agble blibo le ŋkeke ʋee me.",
        "kab": "Dɔ sesẽ ŋutɔ. Aɖu agble blibo le ŋkeke ʋee me.",
    },
    i18n_plain={
        "fr": "Mildiou très dangereux. Réagir vite : fongicide cuprique tous les 5 jours.",
        "ee": "Mildiou sesẽ. Wɔ dɔ enumake.",
        "kab": "Mildiou sesẽ. Wɔ dɔ enumake.",
    },
))

ENTRIES.append(healthy(
    "Potato___healthy", "Pomme de terre",
    i18n_name={"ee": "Kaklo le lãmesẽ me", "kab": "Kaklo le lãmesẽ me"},
    i18n_desc={
        "ee": "Wò kaklo la le lãmesẽ me. Yi edzi.",
        "kab": "Wò kaklo la le lãmesẽ me. Yi edzi.",
    },
    i18n_plain={
        "fr": "Pomme de terre saine. Continuez la surveillance.",
        "ee": "Kaklo la le lãmesẽ me. Yi edzi.",
        "kab": "Kaklo la le lãmesẽ me. Yi edzi.",
    },
))

# ───── PIMENT ─────
ENTRIES.append(make_entry(
    label="Pepper,_bell___Bacterial_spot",
    culture="Piment",
    display_name="Tache bactérienne du piment",
    description="Bactérie (Xanthomonas euvesicatoria) qui cause de petites taches d'eau, puis brunes, sur feuilles et fruits.",
    severity="grave",
    symptoms=[
        "Petites taches translucides sur jeunes feuilles",
        "Évolution en taches brunes nécrotiques",
        "Taches rugueuses sur les fruits",
        "Défoliation"
    ],
    treatments=[{
        "method": "Cuivre + assainissement",
        "description": "",
        "steps": [
            "Retirer feuilles atteintes, brûler",
            "Désinfecter les outils",
            "Bouillie bordelaise tous les 7 jours"
        ]
    }],
    products=[
        {"name": "Bouillie bordelaise", "dosage": "20 g/L",
         "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
         "vendor": "DoctAgri Shop"}
    ],
    prevention=["Semences saines", "Rotation 3 ans"],
    i18n_name={
        "ee": "Ɖoku ƒe dɔmegblẽ bacteria",
        "kab": "Ɖoku ƒe dɔmegblẽ bacteria",
    },
    i18n_desc={
        "ee": "Bacteria ɖe lãme kple atsiame. Wɔna nɛ kɔpe.",
        "kab": "Bacteria ɖe lãme kple atsiame.",
    },
    i18n_plain={
        "fr": "Maladie bactérienne du piment. Retirer feuilles atteintes et traiter au cuivre.",
        "ee": "Ɖoku ƒe dɔ bacteria. Wɔ dɔ kple kɔpe.",
        "kab": "Ɖoku ƒe dɔ bacteria. Wɔ dɔ kple kɔpe.",
    },
))

ENTRIES.append(healthy(
    "Pepper,_bell___healthy", "Piment",
    i18n_name={"ee": "Ɖoku le lãmesẽ me", "kab": "Ɖoku le lãmesẽ me"},
    i18n_desc={
        "ee": "Wò ɖoku la le lãmesẽ me. Yi edzi.",
        "kab": "Wò ɖoku la le lãmesẽ me. Yi edzi.",
    },
    i18n_plain={
        "fr": "Piment en bonne santé. Continuez la surveillance.",
        "ee": "Ɖoku la le lãmesẽ me. Yi edzi.",
        "kab": "Ɖoku la le lãmesẽ me. Yi edzi.",
    },
))


# ───── Entrées génériques (fruits secondaires) ─────
# Pour chaque label PlantVillage non couvert finement on crée une entrée
# de base pour que l'app ne reste jamais "muette".
GENERIC_FRUITS = [
    ("Apple___Apple_scab", "Pomme", "Tavelure du pommier", "Champignon qui crée des taches noires veloutées sur feuilles et fruits.", "grave"),
    ("Apple___Black_rot", "Pomme", "Pourriture noire du pommier", "Maladie fongique grave qui pourrit les fruits.", "grave"),
    ("Apple___Cedar_apple_rust", "Pomme", "Rouille du pommier-cèdre", "Champignon créant des taches orange sur les feuilles.", "modéré"),
    ("Apple___healthy", "Pomme", "Pommier en bonne santé", "Aucun signe de maladie. Continuez la surveillance.", "aucune"),
    ("Blueberry___healthy", "Myrtille", "Myrtille en bonne santé", "Aucun signe de maladie.", "aucune"),
    ("Cherry___Powdery_mildew", "Cerise", "Oïdium du cerisier", "Feutrage blanc sur les feuilles. Traiter au soufre.", "modéré"),
    ("Cherry___healthy", "Cerise", "Cerisier en bonne santé", "Aucun signe de maladie.", "aucune"),
    ("Grape___Black_rot", "Vigne", "Pourriture noire de la vigne", "Champignon dévastateur sur grappes et feuilles.", "grave"),
    ("Grape___Esca_(Black_Measles)", "Vigne", "Esca de la vigne", "Maladie complexe du bois. Tailler les ceps atteints.", "grave"),
    ("Grape___Leaf_blight_(Isariopsis_Leaf_Spot)", "Vigne", "Brûlure des feuilles de la vigne", "Champignon qui brunit les feuilles.", "modéré"),
    ("Grape___healthy", "Vigne", "Vigne en bonne santé", "Aucun signe de maladie.", "aucune"),
    ("Orange___Haunglongbing_(Citrus_greening)", "Orange", "HLB / Greening des agrumes", "Maladie bactérienne mortelle pour les agrumes. Pas de cure : arracher les arbres atteints.", "critique"),
    ("Peach___Bacterial_spot", "Pêche", "Tache bactérienne du pêcher", "Petites taches sur feuilles et fruits.", "grave"),
    ("Peach___healthy", "Pêche", "Pêcher en bonne santé", "Aucun signe de maladie.", "aucune"),
    ("Raspberry___healthy", "Framboise", "Framboise en bonne santé", "Aucun signe de maladie.", "aucune"),
    ("Soybean___healthy", "Soja", "Soja en bonne santé", "Aucun signe de maladie.", "aucune"),
    ("Squash___Powdery_mildew", "Courge", "Oïdium de la courge", "Feutrage blanc sur les feuilles.", "modéré"),
    ("Strawberry___Leaf_scorch", "Fraise", "Brûlure des feuilles du fraisier", "Champignon qui brunit le bord des feuilles.", "modéré"),
    ("Strawberry___healthy", "Fraise", "Fraisier en bonne santé", "Aucun signe de maladie.", "aucune"),
]

for label, culture, dn, desc, sev in GENERIC_FRUITS:
    is_healthy = sev == "aucune"
    ENTRIES.append(make_entry(
        label=label,
        culture=culture,
        display_name=dn,
        description=desc,
        severity=sev,
        symptoms=[],
        treatments=[{
            "method": "Surveillance" if is_healthy else "Traitement cuprique",
            "description": "",
            "steps": (["Continuer la surveillance"] if is_healthy
                      else ["Retirer parties atteintes",
                            "Bouillie bordelaise tous les 10 jours"])
        }],
        products=([] if is_healthy else [
            {"name": "Bouillie bordelaise", "dosage": "20 g/L",
             "precautions": "", "priceXof": 6500, "sku": "DGA-1001",
             "vendor": "DoctAgri Shop"}
        ]),
        prevention=(["Surveillance régulière"] if is_healthy
                    else ["Variétés résistantes", "Rotation"]),
        i18n_name={
            "ee": dn, "kab": dn,
        },
        i18n_desc={
            "ee": desc, "kab": desc,
        },
        i18n_plain={
            "fr": desc,
            "ee": desc,
            "kab": desc,
        },
    ))


def merge():
    if not KNOWLEDGE_PATH.exists():
        print(f"❌ Pas de fichier de connaissances à {KNOWLEDGE_PATH}")
        sys.exit(1)
    with KNOWLEDGE_PATH.open("r", encoding="utf-8") as f:
        existing = json.load(f)

    by_label = {e["model_label"]: e for e in existing}
    added = 0
    updated = 0
    for entry in ENTRIES:
        key = entry["model_label"]
        if key in by_label:
            by_label[key].update(entry)
            updated += 1
        else:
            existing.append(entry)
            added += 1

    with KNOWLEDGE_PATH.open("w", encoding="utf-8") as f:
        json.dump(existing, f, ensure_ascii=False, indent=4)

    print(f"✅ {added} entrées ajoutées, {updated} mises à jour")
    print(f"   Total = {len(existing)} maladies dans la base")


if __name__ == "__main__":
    merge()
