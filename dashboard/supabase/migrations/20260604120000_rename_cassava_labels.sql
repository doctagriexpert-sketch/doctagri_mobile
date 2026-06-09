-- ═══════════════════════════════════════════════════════════
-- 005_rename_cassava_labels.sql
--
-- Aligne la table public.taxonomy avec le renommage des labels
-- ambigus du modèle cassava côté app :
--   'Healthy' → 'Cassava___healthy'   (culture: 'Général' → 'Manioc')
--   ajout de 'Cassava___unknown'      (absent du seed initial)
--
-- Motif : le label 'Healthy' était partagé sémantiquement entre
-- "manioc sain" (sortie du modèle cassava 6-classes) et "plante
-- saine générique". Le nouveau label namespacé lève l'ambiguïté
-- et reste cohérent avec les autres labels (`<Culture>___<état>`).
--
-- Idempotente : peut être ré-appliquée sans effet de bord.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- 1) Rename de l'entrée existante 'Healthy' → 'Cassava___healthy'
--    et correction du display_name + culture.
UPDATE public.taxonomy
SET
    model_label = 'Cassava___healthy',
    display_name = 'Manioc sain',
    culture = 'Manioc'
WHERE model_label = 'Healthy';

-- 2) Insertion de la classe 'Cassava___unknown' (fourre-tout du
--    modèle cassava, absente du seed 002).
INSERT INTO public.taxonomy (model_label, display_name, culture)
VALUES ('Cassava___unknown', 'État non identifié', 'Manioc')
ON CONFLICT (model_label) DO NOTHING;

COMMIT;
