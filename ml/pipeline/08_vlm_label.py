#!/usr/bin/env python3
"""
08_vlm_label.py
Étiquetage assisté par VLM (Claude vision) des photos de terrain NON étiquetées.

Contexte : les données terrain couvrent des cultures hors-périmètre (laitue…) et
manquent d'étiquettes, faute d'expert. Un VLM propose culture + maladie + sévérité
+ qualité photo ; un non-expert n'a plus qu'à VÉRIFIER (colonnes `verified` /
`correction` du CSV), ce qui est bien plus rapide qu'étiqueter de zéro.

Garde-fou « expert faible VALIDÉ » : avant de faire confiance au VLM sur le
terrain, on mesure sa fiabilité sur un jeu DÉJÀ étiqueté (PlantVillage, dont le
nom de dossier = vérité terrain) via `--validate_dir`. On ne se fie ensuite au
VLM que sur les classes où il s'est montré fiable.

Sorties : un CSV ouvrable dans Excel/Sheets, REPRENABLE (les images déjà
étiquetées sont sautées) → on peut traiter tout le Drive par lots.

Prérequis :
    pip install anthropic        (Pillow déjà présent dans .venv_tf)
    $env:ANTHROPIC_API_KEY = "sk-ant-..."   (ou `ant auth login`)

Usage :
    # 1) Valider le VLM sur un échantillon PlantVillage étiqueté (recommandé d'abord)
    python 08_vlm_label.py --validate_dir data/plantvillage_sample --max_images 80

    # 2) Étiqueter les photos terrain
    python 08_vlm_label.py --images_dir data/field_photos \
        --output_csv data/field_labels.csv

    # Test à blanc sans appel API (vérifie le prompt/ancrage) :
    python 08_vlm_label.py --images_dir data/field_photos --dry_run --max_images 3
"""

import os
import csv
import json
import glob
import base64
import argparse

DEFAULT_MODEL = "claude-opus-4-8"  # vision ; --model pour basculer (ex. haiku) si gros volume
MAX_EDGE = 1536  # on redimensionne avant envoi pour limiter le coût en tokens d'image
IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp")

CSV_FIELDS = [
    "image", "crop", "in_app_catalog", "healthy", "disease", "severity",
    "image_quality", "confidence", "symptoms", "vlm_reasoning",
    "verified", "correction",
]

# Schéma de sortie structurée (output_config.format) — garantit un JSON parsable.
OUTPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "crop": {"type": "string", "description": "Culture identifiée, en français (ex. Laitue, Maïs, Manioc, Tomate). 'Indéterminé' si illisible."},
        "in_app_catalog": {"type": "boolean", "description": "La culture fait-elle partie du catalogue de l'app fourni ?"},
        "healthy": {"type": "boolean", "description": "La plante paraît-elle saine (aucun symptôme de maladie) ?"},
        "disease": {"type": "string", "description": "Nom de la maladie en français, ou 'Sain' si saine, ou 'Indéterminé'. Réutiliser un nom de la liste connue si applicable."},
        "severity": {"type": "string", "enum": ["aucune", "faible", "modérée", "sévère"]},
        "image_quality": {"type": "string", "enum": ["bonne", "moyenne", "mauvaise"], "description": "Qualité/utilisabilité de la photo (netteté, cadrage, éclairage)."},
        "confidence": {"type": "string", "enum": ["faible", "moyenne", "élevée"], "description": "Confiance du modèle dans CE diagnostic."},
        "symptoms": {"type": "string", "description": "Symptômes visibles, une phrase courte."},
        "reasoning": {"type": "string", "description": "Justification brève (1-2 phrases)."},
    },
    "required": [
        "crop", "in_app_catalog", "healthy", "disease", "severity",
        "image_quality", "confidence", "symptoms", "reasoning",
    ],
    "additionalProperties": False,
}


def load_app_taxonomy(pipeline_dir: str) -> tuple:
    """Construit l'ancrage : cultures couvertes par l'app + maladies connues.

    Lit registry.json (cultures par modèle) et diseases_knowledge.json
    (paires culture/maladie). Chemins relatifs à la racine du projet.
    """
    root = os.path.abspath(os.path.join(pipeline_dir, "..", ".."))
    crops, diseases = set(), []
    reg_path = os.path.join(root, "assets", "models", "registry.json")
    if os.path.exists(reg_path):
        with open(reg_path, encoding="utf-8") as f:
            for m in json.load(f):
                crops.update(m.get("cultures", []))
    kb_path = os.path.join(root, "assets", "data", "diseases_knowledge.json")
    if os.path.exists(kb_path):
        with open(kb_path, encoding="utf-8") as f:
            for e in json.load(f):
                name = e.get("display_name")
                culture = e.get("culture", "")
                if name:
                    diseases.append(f"{culture} — {name}")
    return sorted(crops), diseases


def build_system_prompt(crops: list, diseases: list) -> str:
    crops_str = ", ".join(crops) if crops else "(aucune)"
    diseases_str = "\n".join(f"  - {d}" for d in diseases) if diseases else "  (aucune)"
    return (
        "Tu es agronome phytopathologiste, spécialiste des cultures vivrières "
        "et maraîchères d'Afrique de l'Ouest. On te montre une photo de terrain "
        "(prise au téléphone, en plein champ) d'une feuille ou plante. Identifie "
        "la culture, si elle est malade, la maladie, sa sévérité, les symptômes "
        "visibles, et juge la qualité de la photo.\n\n"
        f"Cultures couvertes par l'application (mets in_app_catalog=true si la "
        f"plante en fait partie, sinon false) : {crops_str}.\n\n"
        "Maladies déjà connues de la base (réutilise EXACTEMENT un de ces noms "
        f"quand il s'applique, pour rester cohérent) :\n{diseases_str}\n\n"
        "Si la culture ou la maladie n'est pas dans ces listes, propose quand "
        "même ton meilleur diagnostic et mets in_app_catalog=false. Si tu n'es "
        "pas sûr, baisse `confidence` — ne devine pas avec assurance. Si la photo "
        "est inexploitable, mets image_quality='mauvaise'."
    )


def encode_image(path: str) -> tuple:
    """Redimensionne (long edge <= MAX_EDGE) et encode en base64 JPEG."""
    from PIL import Image
    import io

    img = Image.open(path).convert("RGB")
    w, h = img.size
    scale = min(1.0, MAX_EDGE / max(w, h))
    if scale < 1.0:
        img = img.resize((int(w * scale), int(h * scale)), Image.BILINEAR)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return base64.standard_b64encode(buf.getvalue()).decode("utf-8"), "image/jpeg"


def label_image(client, model: str, system: str, path: str) -> dict:
    data, media_type = encode_image(path)
    response = client.messages.create(
        model=model,
        max_tokens=4096,
        thinking={"type": "adaptive"},
        system=system,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": data}},
                {"type": "text", "text": "Diagnostique cette plante. Réponds via le schéma structuré."},
            ],
        }],
        output_config={"format": {"type": "json_schema", "schema": OUTPUT_SCHEMA}},
    )
    text = next((b.text for b in response.content if b.type == "text"), "{}")
    return json.loads(text)


# ── Étiquetage (reprenable) ──

def run_labeling(args) -> None:
    paths = sorted(
        p for p in glob.glob(os.path.join(args.images_dir, "**", "*.*"), recursive=True)
        if p.lower().endswith(IMAGE_EXTS)
    )
    if not paths:
        raise FileNotFoundError(f"Aucune image dans {args.images_dir}")
    if args.max_images:
        paths = paths[: args.max_images]

    pipeline_dir = os.path.dirname(os.path.abspath(__file__))
    crops, diseases = load_app_taxonomy(pipeline_dir)
    system = build_system_prompt(crops, diseases)

    done = set()
    if os.path.exists(args.output_csv):
        with open(args.output_csv, encoding="utf-8", newline="") as f:
            done = {row["image"] for row in csv.DictReader(f)}
    todo = [p for p in paths if os.path.basename(p) not in done]

    print(f"[8] Étiquetage VLM — {len(todo)} images à traiter "
          f"({len(done)} déjà faites), modèle {args.model}")
    if args.dry_run:
        print("\n--- DRY RUN : system prompt (ancrage) ---\n")
        print(system)
        print(f"\n{len(todo)} images seraient envoyées. Aucun appel API effectué.")
        return
    if not todo:
        print("Rien à faire.")
        return

    import anthropic
    client = anthropic.Anthropic()  # clé via ANTHROPIC_API_KEY ou profil `ant`

    new_file = not os.path.exists(args.output_csv)
    with open(args.output_csv, "a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        if new_file:
            writer.writeheader()
        for i, path in enumerate(todo, 1):
            name = os.path.basename(path)
            try:
                r = label_image(client, args.model, system, path)
                writer.writerow({
                    "image": name,
                    "crop": r.get("crop", ""),
                    "in_app_catalog": r.get("in_app_catalog", ""),
                    "healthy": r.get("healthy", ""),
                    "disease": r.get("disease", ""),
                    "severity": r.get("severity", ""),
                    "image_quality": r.get("image_quality", ""),
                    "confidence": r.get("confidence", ""),
                    "symptoms": r.get("symptoms", ""),
                    "vlm_reasoning": r.get("reasoning", ""),
                    "verified": "",
                    "correction": "",
                })
                f.flush()  # reprenable même en cas d'interruption
                print(f"  [{i}/{len(todo)}] {name}: {r.get('crop')} / "
                      f"{r.get('disease')} ({r.get('confidence')})")
            except Exception as e:  # noqa: BLE001 — on continue le lot
                print(f"  [{i}/{len(todo)}] {name}: ERREUR {e}")

    print(f"\nCSV : {args.output_csv}")
    print("Ouvre-le dans Excel/Sheets et remplis la colonne `verified` "
          "(ok / corriger) + `correction` si besoin.")


# ── Validation du VLM sur un jeu DÉJÀ étiqueté ──

def run_validation(args) -> None:
    """Mesure l'accord du VLM avec la vérité terrain (nom de dossier =
    `Crop___Disease`, format PlantVillage). Estime la fiabilité AVANT de se
    fier au VLM sur le terrain."""
    paths = sorted(
        p for p in glob.glob(os.path.join(args.validate_dir, "**", "*.*"), recursive=True)
        if p.lower().endswith(IMAGE_EXTS)
    )
    if not paths:
        raise FileNotFoundError(f"Aucune image dans {args.validate_dir}")
    if args.max_images:
        paths = paths[: args.max_images]

    pipeline_dir = os.path.dirname(os.path.abspath(__file__))
    crops, diseases = load_app_taxonomy(pipeline_dir)
    system = build_system_prompt(crops, diseases)

    print(f"[8] Validation VLM — {len(paths)} images étiquetées, modèle {args.model}")
    if args.dry_run:
        print("DRY RUN : aucun appel API.")
        return

    import anthropic
    client = anthropic.Anthropic()

    crop_ok = disease_ok = 0
    per_class = {}  # classe -> [n, crop_ok, disease_ok]
    for i, path in enumerate(paths, 1):
        gt = os.path.basename(os.path.dirname(path))  # ex. Tomato___Late_blight
        gt_crop = gt.split("___")[0].replace("_", " ").lower()
        gt_disease = (gt.split("___")[-1] if "___" in gt else "").replace("_", " ").lower()
        try:
            r = label_image(client, args.model, system, path)
        except Exception as e:  # noqa: BLE001
            print(f"  [{i}/{len(paths)}] {gt}: ERREUR {e}")
            continue
        pc = str(r.get("crop", "")).lower()
        pd = str(r.get("disease", "")).lower()
        # Accord grossier : la culture-vérité apparaît dans la prédiction.
        c_match = gt_crop in pc or pc in gt_crop
        is_healthy_gt = "healthy" in gt_disease
        d_match = (r.get("healthy") is True) if is_healthy_gt else any(
            tok in pd for tok in gt_disease.split() if len(tok) > 3
        )
        crop_ok += c_match
        disease_ok += d_match
        st = per_class.setdefault(gt, [0, 0, 0])
        st[0] += 1; st[1] += c_match; st[2] += d_match
        print(f"  [{i}/{len(paths)}] {gt} -> {r.get('crop')}/{r.get('disease')} "
              f"[culture {'OK' if c_match else 'X'}, maladie {'OK' if d_match else 'X'}]")

    n = sum(s[0] for s in per_class.values()) or 1
    print(f"\n=== Fiabilité VLM sur {n} images ===")
    print(f"  Accord culture : {crop_ok}/{n} = {crop_ok/n*100:.0f}%")
    print(f"  Accord maladie : {disease_ok}/{n} = {disease_ok/n*100:.0f}%")
    print("  Par classe (n, culture%, maladie%) — fie-toi au VLM sur les classes hautes :")
    for cls, (cn, cc, cd) in sorted(per_class.items()):
        print(f"    {cls}: n={cn}, culture {cc/cn*100:.0f}%, maladie {cd/cn*100:.0f}%")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--images_dir", help="Dossier de photos terrain à étiqueter")
    parser.add_argument("--output_csv", default="data/field_labels.csv")
    parser.add_argument("--validate_dir", help="Dossier étiqueté (Crop___Disease) pour valider le VLM")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--max_images", type=int, default=0, help="Limite (0 = tout)")
    parser.add_argument("--dry_run", action="store_true", help="N'appelle pas l'API")
    args = parser.parse_args()

    if args.validate_dir:
        run_validation(args)
    elif args.images_dir:
        run_labeling(args)
    else:
        parser.error("Fournir --images_dir (étiquetage) ou --validate_dir (validation).")


if __name__ == "__main__":
    main()
