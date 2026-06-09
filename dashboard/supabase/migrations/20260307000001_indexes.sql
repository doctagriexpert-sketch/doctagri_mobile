-- ============================================================
-- DoctAgri — Indexation pour Scalabilité
-- ============================================================
-- Migration 004: Index composites et partiels
-- Objectif: temps de réponse < 100ms avec millions d'entrées
--
-- Analyse des requêtes critiques :
--   1. AnnotationQueuePage : WHERE status = ? ORDER BY priority DESC, created_at ASC
--   2. get_next_image()    : WHERE status = 'pending' AND assigned_expert_1 IS NULL ORDER BY priority DESC
--   3. ConflictsPage       : WHERE status = 'conflict' ORDER BY priority DESC, created_at ASC
--   4. get_overview_stats  : count(*) GROUP BY status
--   5. Farmer isolation    : WHERE uploaded_by = ? ORDER BY created_at DESC
-- ============================================================

-- ─── 1. INDEX COMPOSITE PRINCIPAL ──────────────────────────
-- Couvre les requêtes de la queue d'annotation (page la plus sollicitée)
-- et le tri par priorité/date sur chaque filtre de statut
CREATE INDEX IF NOT EXISTS idx_images_status_priority_created
    ON public.images (status, priority DESC, created_at ASC);

-- ─── 2. INDEX COMPOSITE CULTURE + STATUS ───────────────────
-- Couvre le filtre combiné culture + status de AnnotationQueuePage
CREATE INDEX IF NOT EXISTS idx_images_culture_status
    ON public.images (culture, status);

-- ─── 3. INDEX PARTIEL : images pending non assignées ───────
-- Accélère get_next_image() Priorité 2 (le hot path)
-- Très sélectif : seule une fraction des images est en attente
CREATE INDEX IF NOT EXISTS idx_images_pending_unassigned
    ON public.images (priority DESC, created_at ASC)
    WHERE status = 'pending' AND assigned_expert_1 IS NULL;

-- ─── 4. INDEX PARTIEL : images en conflit ──────────────────
-- Accélère ConflictsPage (filtrage fréquent par les seniors)
CREATE INDEX IF NOT EXISTS idx_images_conflict
    ON public.images (priority DESC, created_at ASC)
    WHERE status = 'conflict';

-- ─── 5. INDEX PARTIEL : images annotating pour 2e expert ───
-- Accélère get_next_image() Priorité 3
CREATE INDEX IF NOT EXISTS idx_images_annotating_need_second
    ON public.images (priority DESC, created_at ASC)
    WHERE status = 'annotating'
      AND assigned_expert_1 IS NOT NULL
      AND assigned_expert_2 IS NULL;

-- ─── 6. INDEX COMPOSITE ANNOTATIONS ────────────────────────
-- Couvre check_annotation_agreement() : SELECT count(*), array_agg(disease_label) WHERE image_id = ?
-- L'index couvrant évite un heap fetch pour le label
CREATE INDEX IF NOT EXISTS idx_annotations_image_label
    ON public.annotations (image_id, disease_label);

-- ─── 7. INDEX FARMER : images par propriétaire ─────────────
-- Accélère l'isolation RLS des farmers (uploaded_by = auth.uid())
-- Ajouté en 002 mais on s'assure qu'il est composite avec le tri
CREATE INDEX IF NOT EXISTS idx_images_uploaded_by_created
    ON public.images (uploaded_by, created_at DESC)
    WHERE uploaded_by IS NOT NULL;

-- ─── 8. INDEX ANNOTATIONS PAR EXPERT ───────────────────────
-- Accélère la sous-requête NOT IN (SELECT image_id ... WHERE expert_id = ?)
-- dans get_next_image()
CREATE INDEX IF NOT EXISTS idx_annotations_expert_image
    ON public.annotations (expert_id, image_id);

-- ─── 9. SUPPRESSION DES INDEX SIMPLES REDONDANTS ───────────
-- Les index single-column sont maintenant couverts par les composites.
-- On les garde pour l'instant car DROP INDEX sur une table active
-- peut bloquer les écritures. À supprimer lors d'une fenêtre
-- de maintenance si nécessaire :
--
--   DROP INDEX CONCURRENTLY IF EXISTS idx_images_status;
--   DROP INDEX CONCURRENTLY IF EXISTS idx_images_priority;
--   DROP INDEX CONCURRENTLY IF EXISTS idx_images_culture;
--
-- Note: idx_images_assigned_1 et idx_images_assigned_2 restent
-- utiles pour les FK lookups.
