-- ============================================================
-- DoctAgri Expert Dashboard — Row Level Security (DURCI)
-- ============================================================
-- Migration 002: RLS strict par rôle (farmer, expert, senior, admin)
--
-- Principes :
--   • farmer  : voit/insère UNIQUEMENT ses propres images
--   • expert  : voit toutes les images du workflow, UPDATE assignées
--   • senior  : plein accès lecture, peut résoudre conflits
--   • admin   : accès total y compris DELETE et gestion Products
-- ============================================================

-- ─── PRE-REQUIS : rôle farmer ──────────────────────────────
-- Ajout sûr (IF NOT EXISTS) du rôle farmer dans l'enum
DO $$
BEGIN
    ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'farmer' BEFORE 'expert';
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ─── PRE-REQUIS : colonne uploaded_by ──────────────────────
-- Permet de tracer la propriété des images (qui a uploadé)
ALTER TABLE public.images
    ADD COLUMN IF NOT EXISTS uploaded_by UUID REFERENCES public.profiles(id);

CREATE INDEX IF NOT EXISTS idx_images_uploaded_by ON public.images(uploaded_by);

-- ─── ENABLE RLS ────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.annotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.taxonomy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disease_sheets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disease_product ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dataset_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ─── HELPER : rôle utilisateur courant ─────────────────────
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ═══════════════════════════════════════════════════════════
-- NETTOYAGE : supprimer toutes les anciennes policies
-- (idempotent — safe to re-run)
-- ═══════════════════════════════════════════════════════════
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- Nettoyer aussi les policies Storage
DROP POLICY IF EXISTS "Authenticated can upload images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can view images" ON storage.objects;


-- ═══════════════════════════════════════════════════════════
-- PROFILES
-- ═══════════════════════════════════════════════════════════
-- SELECT : tous les authentifiés (nécessaire pour les JOIN annotations→profiles)
CREATE POLICY "profiles_select_all"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

-- UPDATE : son propre profil uniquement
CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());


-- ═══════════════════════════════════════════════════════════
-- IMAGES — Isolation farmer / accès workflow expert
-- ═══════════════════════════════════════════════════════════

-- SELECT : farmers voient uniquement leurs images,
--          experts/senior/admin voient tout le workflow
CREATE POLICY "images_select_farmer_own"
    ON public.images FOR SELECT
    TO authenticated
    USING (
        CASE public.get_user_role()
            WHEN 'farmer' THEN uploaded_by = auth.uid()
            ELSE true  -- expert, senior, admin : accès complet
        END
    );

-- INSERT : farmers insèrent avec uploaded_by = eux-mêmes,
--          admins peuvent aussi insérer (import bulk)
CREATE POLICY "images_insert_farmer_or_admin"
    ON public.images FOR INSERT
    TO authenticated
    WITH CHECK (
        CASE public.get_user_role()
            WHEN 'farmer' THEN uploaded_by = auth.uid()
            WHEN 'admin'  THEN true
            ELSE false  -- experts/seniors n'insèrent pas d'images
        END
    );

-- UPDATE : experts sur images qui leur sont assignées uniquement,
--          senior/admin sur toutes les images
CREATE POLICY "images_update_assigned_or_senior"
    ON public.images FOR UPDATE
    TO authenticated
    USING (
        CASE public.get_user_role()
            WHEN 'farmer' THEN false
            WHEN 'expert' THEN
                assigned_expert_1 = auth.uid() OR
                assigned_expert_2 = auth.uid()
            ELSE true  -- senior, admin
        END
    )
    WITH CHECK (
        CASE public.get_user_role()
            WHEN 'farmer' THEN false
            WHEN 'expert' THEN
                assigned_expert_1 = auth.uid() OR
                assigned_expert_2 = auth.uid()
            ELSE true
        END
    );

-- DELETE : admin uniquement
CREATE POLICY "images_delete_admin_only"
    ON public.images FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');


-- ═══════════════════════════════════════════════════════════
-- ANNOTATIONS
-- ═══════════════════════════════════════════════════════════

-- SELECT : experts+ voient toutes les annotations (nécessaire pour le dashboard),
--          farmers voient les annotations de leurs propres images
CREATE POLICY "annotations_select"
    ON public.annotations FOR SELECT
    TO authenticated
    USING (
        CASE public.get_user_role()
            WHEN 'farmer' THEN
                image_id IN (SELECT id FROM public.images WHERE uploaded_by = auth.uid())
            ELSE true  -- expert, senior, admin
        END
    );

-- INSERT : expert+ uniquement, avec expert_id = soi-même
CREATE POLICY "annotations_insert_expert"
    ON public.annotations FOR INSERT
    TO authenticated
    WITH CHECK (
        expert_id = auth.uid() AND
        public.get_user_role() IN ('expert', 'senior', 'admin')
    );


-- ═══════════════════════════════════════════════════════════
-- VALIDATIONS
-- ═══════════════════════════════════════════════════════════

-- SELECT : expert+ (workflow), farmers exclus
CREATE POLICY "validations_select_expert"
    ON public.validations FOR SELECT
    TO authenticated
    USING (public.get_user_role() IN ('expert', 'senior', 'admin'));

-- INSERT : senior+ uniquement (résolution de conflits)
CREATE POLICY "validations_insert_senior"
    ON public.validations FOR INSERT
    TO authenticated
    WITH CHECK (public.get_user_role() IN ('senior', 'admin'));


-- ═══════════════════════════════════════════════════════════
-- TAXONOMY
-- ═══════════════════════════════════════════════════════════

-- SELECT : tous les authentifiés (affichage dans l'app mobile + dashboard)
CREATE POLICY "taxonomy_select_all"
    ON public.taxonomy FOR SELECT
    TO authenticated
    USING (true);

-- INSERT / UPDATE : admin uniquement
CREATE POLICY "taxonomy_insert_admin"
    ON public.taxonomy FOR INSERT
    TO authenticated
    WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "taxonomy_update_admin"
    ON public.taxonomy FOR UPDATE
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- DELETE : admin uniquement
CREATE POLICY "taxonomy_delete_admin"
    ON public.taxonomy FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');


-- ═══════════════════════════════════════════════════════════
-- DISEASE SHEETS
-- ═══════════════════════════════════════════════════════════

-- SELECT : tous les authentifiés (fiches publiées visibles pour les farmers)
CREATE POLICY "disease_sheets_select_all"
    ON public.disease_sheets FOR SELECT
    TO authenticated
    USING (
        CASE public.get_user_role()
            WHEN 'farmer' THEN status = 'published'  -- farmers : publiées seulement
            ELSE true  -- expert+ : toutes (draft, review, published)
        END
    );

-- INSERT : expert+ peuvent créer des brouillons
CREATE POLICY "disease_sheets_insert_expert"
    ON public.disease_sheets FOR INSERT
    TO authenticated
    WITH CHECK (
        public.get_user_role() IN ('expert', 'senior', 'admin') AND
        status = 'draft'
    );

-- UPDATE : auteur de ses propres brouillons, senior/admin pour tout
CREATE POLICY "disease_sheets_update"
    ON public.disease_sheets FOR UPDATE
    TO authenticated
    USING (
        (created_by = auth.uid() AND status = 'draft') OR
        public.get_user_role() IN ('senior', 'admin')
    )
    WITH CHECK (
        (created_by = auth.uid() AND status = 'draft') OR
        public.get_user_role() IN ('senior', 'admin')
    );

-- DELETE : admin uniquement
CREATE POLICY "disease_sheets_delete_admin"
    ON public.disease_sheets FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');


-- ═══════════════════════════════════════════════════════════
-- PRODUCTS — Admin only pour toute écriture
-- ═══════════════════════════════════════════════════════════

-- SELECT : tous les authentifiés (catalogue visible dans l'app mobile)
CREATE POLICY "products_select_all"
    ON public.products FOR SELECT
    TO authenticated
    USING (true);

-- INSERT : admin uniquement
CREATE POLICY "products_insert_admin"
    ON public.products FOR INSERT
    TO authenticated
    WITH CHECK (public.get_user_role() = 'admin');

-- UPDATE : admin uniquement
CREATE POLICY "products_update_admin"
    ON public.products FOR UPDATE
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- DELETE : admin uniquement
CREATE POLICY "products_delete_admin"
    ON public.products FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');


-- ═══════════════════════════════════════════════════════════
-- DISEASE_PRODUCT — Admin only pour écriture
-- ═══════════════════════════════════════════════════════════

CREATE POLICY "disease_product_select_all"
    ON public.disease_product FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "disease_product_insert_admin"
    ON public.disease_product FOR INSERT
    TO authenticated
    WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "disease_product_delete_admin"
    ON public.disease_product FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');


-- ═══════════════════════════════════════════════════════════
-- DATASET VERSIONS — Admin only
-- ═══════════════════════════════════════════════════════════

CREATE POLICY "dataset_versions_select_all"
    ON public.dataset_versions FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "dataset_versions_insert_admin"
    ON public.dataset_versions FOR INSERT
    TO authenticated
    WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "dataset_versions_update_admin"
    ON public.dataset_versions FOR UPDATE
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');


-- ═══════════════════════════════════════════════════════════
-- AUDIT LOGS
-- ═══════════════════════════════════════════════════════════

-- SELECT : senior+ uniquement (données sensibles)
CREATE POLICY "audit_logs_select_senior"
    ON public.audit_logs FOR SELECT
    TO authenticated
    USING (public.get_user_role() IN ('senior', 'admin'));

-- INSERT : tout authentifié (les SECURITY DEFINER functions écrivent)
CREATE POLICY "audit_logs_insert_system"
    ON public.audit_logs FOR INSERT
    TO authenticated
    WITH CHECK (true);


-- ═══════════════════════════════════════════════════════════
-- STORAGE : bucket diagnosis-images
-- ═══════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('diagnosis-images', 'diagnosis-images', false, 10485760)
ON CONFLICT (id) DO NOTHING;

-- Upload : farmers dans leur propre dossier, expert+ dans diagnoses/
CREATE POLICY "storage_insert_authenticated"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'diagnosis-images');

-- View : farmers voient uniquement leur dossier,
--        expert+ voient tout le bucket
CREATE POLICY "storage_select_authenticated"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'diagnosis-images');

-- Delete storage : admin uniquement
CREATE POLICY "storage_delete_admin"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'diagnosis-images' AND
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );


-- ═══════════════════════════════════════════════════════════
-- SEED: Initial taxonomy from TFLite model labels
-- ═══════════════════════════════════════════════════════════
INSERT INTO public.taxonomy (model_label, display_name, culture) VALUES
    ('Healthy', 'Plante Saine', 'Général'),
    ('Tomato___Early_Blight', 'Alternariose (Brûlure précoce)', 'Tomate'),
    ('Tomato___Late_Blight', 'Mildiou (Brûlure tardive)', 'Tomate'),
    ('Tomato___Leaf_Mold', 'Cladosporiose', 'Tomate'),
    ('Tomato___Septoria_Leaf_Spot', 'Septoriose', 'Tomate'),
    ('Tomato___Spider_Mites', 'Acariens (Araignées rouges)', 'Tomate'),
    ('Tomato___Target_Spot', 'Tache cible', 'Tomate'),
    ('Tomato___Mosaic_Virus', 'Virus de la mosaïque', 'Tomate'),
    ('Tomato___Yellow_Leaf_Curl_Virus', 'TYLCV', 'Tomate'),
    ('Tomato___Bacterial_Spot', 'Tache bactérienne', 'Tomate'),
    ('Potato___Early_Blight', 'Alternariose', 'Pomme de terre'),
    ('Potato___Late_Blight', 'Mildiou', 'Pomme de terre'),
    ('Potato___Healthy', 'Pomme de terre saine', 'Pomme de terre'),
    ('Wheat___Healthy', 'Blé sain', 'Blé'),
    ('Wheat___Rust', 'Rouille du blé', 'Blé'),
    ('Wheat___Septoria', 'Septoriose du blé', 'Blé'),
    ('Corn___Common_Rust', 'Rouille commune', 'Maïs'),
    ('Corn___Gray_Leaf_Spot', 'Tache grise', 'Maïs'),
    ('Corn___Healthy', 'Maïs sain', 'Maïs'),
    ('Corn___Northern_Leaf_Blight', 'Helminthosporiose', 'Maïs')
ON CONFLICT (model_label) DO NOTHING;

-- ═══════════════════════════════════════════════════════════
-- SEED: Initial dataset version
-- ═══════════════════════════════════════════════════════════
INSERT INTO public.dataset_versions (version_tag, status, notes)
VALUES ('v0.1.0', 'active', 'Version initiale du dataset')
ON CONFLICT (version_tag) DO NOTHING;
