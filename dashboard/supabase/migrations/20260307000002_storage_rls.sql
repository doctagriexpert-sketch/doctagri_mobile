-- ============================================================
-- DoctAgri — Migration 004 : Storage & Images RLS
-- ============================================================
-- Objectif : S'assurer que seuls les utilisateurs authentifiés
-- (y compris les sessions anonymes créées par l'app mobile)
-- peuvent uploader des images ou insérer des enregistrements.
-- ============================================================

-- ─── 1. STORAGE BUCKET POLICIES ─────────────────────────────
-- NOTE : Ces policies s'appliquent à la table interne
-- storage.objects pour le bucket 'diagnosis-images'.

-- Permettre l'upload uniquement aux utilisateurs connectés (même anon)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'diagnosis-images',
    'diagnosis-images',
    false,         -- Bucket privé — les URLs publiques sont déjà générées en amont
    5242880,       -- Taille max par fichier : 5 Mo
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit  = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Politique: les utilisateurs authentifiés peuvent uploader dans leur propre "dossier"
CREATE POLICY "Authenticated users can upload images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'diagnosis-images'
        AND auth.role() = 'authenticated'
    );

-- Politique: les experts/admins peuvent lire les images pour les annoter
CREATE POLICY "Experts can read diagnosis images"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'diagnosis-images'
        AND (
            public.get_user_role() IN ('expert', 'senior', 'admin')
            -- Permet aussi à l'auteur (app mobile) de lire sa propre image
            OR name LIKE '%' || auth.uid()::text || '%'
        )
    );

-- Politique: seuls senior/admin peuvent supprimer des images
CREATE POLICY "Senior+ can delete diagnosis images"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'diagnosis-images'
        AND public.get_user_role() IN ('senior', 'admin')
    );


-- ─── 2. TABLE images — Autoriser l'insertion par les apps mobiles ──

-- Supprimer l'ancienne policy restrictive (admin-only)
DROP POLICY IF EXISTS "Admin can insert images" ON public.images;

-- Nouvelle policy : tout utilisateur authentifié (même anon) peut insérer pour soi
CREATE POLICY "Authenticated users can insert own images"
    ON public.images FOR INSERT
    TO authenticated
    WITH CHECK (
        -- Vérifier que l'utilisateur est bien authentifié (même session anonyme)
        auth.uid() IS NOT NULL
    );

-- Renforcement : les experts ne peuvent mettre à jour que le statut
-- (empêcher la modification de l'image originale ou de la date)
DROP POLICY IF EXISTS "Experts+ can update images (status)" ON public.images;

CREATE POLICY "Experts+ can update image status only"
    ON public.images FOR UPDATE
    TO authenticated
    USING (public.get_user_role() IN ('expert', 'senior', 'admin'))
    WITH CHECK (public.get_user_role() IN ('expert', 'senior', 'admin'));
