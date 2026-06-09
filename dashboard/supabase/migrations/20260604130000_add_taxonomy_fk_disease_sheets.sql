-- ═══════════════════════════════════════════════════════════
-- 20260604130000_add_taxonomy_fk_disease_sheets.sql
--
-- Ajoute une clé étrangère ATTÉNUÉE depuis disease_sheets.model_label
-- vers taxonomy.model_label.
--
-- Pourquoi atténuée ?
--   - SCOPE : uniquement disease_sheets (table d'édition par les experts,
--     jamais alimentée par l'app farmer). Les chemins critiques
--     (images.ml_predicted_label, annotations.disease_label,
--     validations.final_label) restent SANS FK pour ne pas bloquer
--     l'ingestion d'un nouveau label modèle non encore déclaré dans
--     taxonomy. Cette dette d'intégrité est consciente et documentée
--     dans dashboard/supabase/README.md.
--   - ON UPDATE CASCADE : si un model_label est renommé dans taxonomy
--     (comme dans la migration 20260604120000_rename_cassava_labels),
--     la valeur référencée dans disease_sheets se met à jour
--     automatiquement.
--   - NOT VALID : la contrainte s'applique aux insertions/updates
--     futurs, mais NE valide PAS les lignes existantes. Aucun risque
--     que la migration échoue si des données legacy violent la FK
--     (et on a déjà vérifié qu'il n'y en a pas — voir le rapport QW1).
--   - PAS de ON DELETE : suppression d'un label dans taxonomy = action
--     manuelle, on veut un échec bruyant si quelqu'un essaie.
--
-- Idempotente : ne re-crée pas la contrainte si elle existe déjà.
-- ═══════════════════════════════════════════════════════════

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_disease_sheets_taxonomy'
          AND conrelid = 'public.disease_sheets'::regclass
    ) THEN
        ALTER TABLE public.disease_sheets
            ADD CONSTRAINT fk_disease_sheets_taxonomy
            FOREIGN KEY (model_label)
            REFERENCES public.taxonomy(model_label)
            ON UPDATE CASCADE
            NOT VALID;
    END IF;
END $$;

-- Pour valider rétroactivement la contrainte plus tard (une fois sûr
-- que toutes les lignes existantes la respectent), exécuter :
--
--   ALTER TABLE public.disease_sheets
--       VALIDATE CONSTRAINT fk_disease_sheets_taxonomy;
--
-- Cette opération acquiert un SHARE UPDATE EXCLUSIVE lock (n'empêche
-- pas les lectures) et scanne toute la table une fois.
