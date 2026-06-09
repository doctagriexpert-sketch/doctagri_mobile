-- ============================================================
-- DoctAgri Expert Dashboard — Schema Initial
-- ============================================================
-- Migration 001: Tables, RLS, Fonctions, Triggers
-- À exécuter dans le SQL Editor de Supabase
-- ============================================================

-- ─── EXTENSIONS ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── TYPES ENUM ──────────────────────────────────────────────
CREATE TYPE user_role AS ENUM ('expert', 'senior', 'admin');
CREATE TYPE image_status AS ENUM ('pending', 'annotating', 'annotated', 'conflict', 'validated', 'rejected');
CREATE TYPE severity_level AS ENUM ('léger', 'modéré', 'sévère');
CREATE TYPE sheet_status AS ENUM ('draft', 'review', 'published');
CREATE TYPE dataset_status AS ENUM ('active', 'frozen', 'archived');

-- ═══════════════════════════════════════════════════════════
-- TABLE: profiles (extension de auth.users)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'expert',
    specialization TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    annotations_count INTEGER NOT NULL DEFAULT 0,
    avg_annotation_time_ms INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger: auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'expert')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ═══════════════════════════════════════════════════════════
-- TABLE: images
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_path TEXT NOT NULL,
    thumbnail_path TEXT,
    original_filename TEXT,
    file_size_bytes INTEGER,
    -- Classification
    culture TEXT,
    region TEXT,
    -- Géolocalisation
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    -- Metadata capture
    capture_date TIMESTAMPTZ,
    device_model TEXT,
    app_version TEXT,
    source_device_id TEXT,
    weather_data JSONB,
    -- Workflow
    status image_status NOT NULL DEFAULT 'pending',
    priority INTEGER NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    assigned_expert_1 UUID REFERENCES public.profiles(id),
    assigned_expert_2 UUID REFERENCES public.profiles(id),
    -- ML pre-annotation
    ml_predicted_label TEXT,
    ml_confidence DOUBLE PRECISION,
    -- Tracking
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_images_status ON public.images(status);
CREATE INDEX idx_images_culture ON public.images(culture);
CREATE INDEX idx_images_priority ON public.images(priority DESC);
CREATE INDEX idx_images_assigned_1 ON public.images(assigned_expert_1);
CREATE INDEX idx_images_assigned_2 ON public.images(assigned_expert_2);

-- ═══════════════════════════════════════════════════════════
-- TABLE: taxonomy (liste officielle des maladies)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.taxonomy (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_label TEXT NOT NULL UNIQUE,
    scientific_name TEXT,
    display_name TEXT NOT NULL,
    culture TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════
-- TABLE: annotations
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.annotations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_id UUID NOT NULL REFERENCES public.images(id) ON DELETE CASCADE,
    expert_id UUID NOT NULL REFERENCES public.profiles(id),
    -- Classification
    disease_label TEXT NOT NULL,
    severity severity_level,
    additional_labels TEXT[] DEFAULT '{}',
    is_healthy BOOLEAN NOT NULL DEFAULT false,
    is_unusable BOOLEAN NOT NULL DEFAULT false,
    -- Qualité
    comment TEXT,
    certainty INTEGER CHECK (certainty BETWEEN 1 AND 5),
    annotation_time_ms INTEGER,
    taxonomy_version INTEGER NOT NULL DEFAULT 1,
    -- Tracking
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    UNIQUE(image_id, expert_id)
);

CREATE INDEX idx_annotations_image ON public.annotations(image_id);
CREATE INDEX idx_annotations_expert ON public.annotations(expert_id);

-- ═══════════════════════════════════════════════════════════
-- TABLE: dataset_versions
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.dataset_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version_tag TEXT NOT NULL UNIQUE,
    total_images INTEGER NOT NULL DEFAULT 0,
    class_distribution JSONB DEFAULT '{}',
    agreement_rate DOUBLE PRECISION,
    rejected_count INTEGER NOT NULL DEFAULT 0,
    uncertain_count INTEGER NOT NULL DEFAULT 0,
    status dataset_status NOT NULL DEFAULT 'active',
    notes TEXT,
    -- Tracking
    frozen_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════
-- TABLE: validations (résolution de conflits)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.validations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_id UUID NOT NULL REFERENCES public.images(id) ON DELETE CASCADE UNIQUE,
    senior_id UUID NOT NULL REFERENCES public.profiles(id),
    -- Décision
    final_label TEXT NOT NULL,
    final_severity severity_level,
    resolution TEXT NOT NULL CHECK (resolution IN ('accepted_1', 'accepted_2', 'modified', 'rejected')),
    decision_comment TEXT,
    -- Dataset
    dataset_version_id UUID REFERENCES public.dataset_versions(id),
    -- Tracking
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════
-- TABLE: disease_sheets (fiches maladies versionnées)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.disease_sheets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Identification
    model_label TEXT,
    scientific_name TEXT,
    local_name TEXT NOT NULL,
    culture TEXT NOT NULL,
    -- Contenu
    description TEXT,
    symptoms JSONB DEFAULT '[]',
    causes JSONB DEFAULT '[]',
    favorable_conditions JSONB DEFAULT '{}',
    severity TEXT,
    -- Recommandations
    preventive_reco JSONB DEFAULT '[]',
    curative_reco JSONB DEFAULT '[]',
    biological_reco JSONB DEFAULT '[]',
    cultural_practices JSONB DEFAULT '[]',
    -- Versioning
    version INTEGER NOT NULL DEFAULT 1,
    status sheet_status NOT NULL DEFAULT 'draft',
    parent_version_id UUID REFERENCES public.disease_sheets(id),
    -- Tracking
    created_by UUID REFERENCES public.profiles(id),
    approved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_disease_sheets_status ON public.disease_sheets(status);
CREATE INDEX idx_disease_sheets_culture ON public.disease_sheets(culture);

-- ═══════════════════════════════════════════════════════════
-- TABLE: products
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    commercial_name TEXT NOT NULL,
    active_substance TEXT,
    dosage TEXT,
    frequency TEXT,
    days_before_harvest INTEGER,
    toxicity_level TEXT,
    precautions TEXT,
    local_compliance BOOLEAN DEFAULT true,
    -- Tracking
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════
-- TABLE: disease_product (association N:N)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.disease_product (
    disease_sheet_id UUID NOT NULL REFERENCES public.disease_sheets(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    recommendation_type TEXT CHECK (recommendation_type IN ('preventive', 'curative', 'biological')),
    PRIMARY KEY (disease_sheet_id, product_id)
);

-- ═══════════════════════════════════════════════════════════
-- TABLE: audit_logs
-- ═══════════════════════════════════════════════════════════
CREATE TABLE public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    old_value JSONB,
    new_value JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_user ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON public.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created ON public.audit_logs(created_at DESC);

-- ═══════════════════════════════════════════════════════════
-- FUNCTION: get_next_image (attribution intelligente)
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_next_image(p_expert_id UUID)
RETURNS UUID AS $$
DECLARE
    v_image_id UUID;
BEGIN
    -- Priorité 1: images assignées à cet expert (2e annotation)
    SELECT id INTO v_image_id
    FROM public.images
    WHERE assigned_expert_2 = p_expert_id
      AND status = 'annotating'
      AND id NOT IN (SELECT image_id FROM public.annotations WHERE expert_id = p_expert_id)
    LIMIT 1;
    
    IF v_image_id IS NOT NULL THEN RETURN v_image_id; END IF;
    
    -- Priorité 2: images pending non encore assignées
    SELECT id INTO v_image_id
    FROM public.images
    WHERE status = 'pending'
      AND assigned_expert_1 IS NULL
    ORDER BY priority DESC, created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    
    IF v_image_id IS NOT NULL THEN
        UPDATE public.images 
        SET assigned_expert_1 = p_expert_id, status = 'annotating'
        WHERE id = v_image_id;
        RETURN v_image_id;
    END IF;
    
    -- Priorité 3: images annotées 1 fois, besoin 2e expert
    SELECT id INTO v_image_id
    FROM public.images
    WHERE status = 'annotating'
      AND assigned_expert_1 IS NOT NULL
      AND assigned_expert_1 != p_expert_id
      AND assigned_expert_2 IS NULL
      AND id NOT IN (SELECT image_id FROM public.annotations WHERE expert_id = p_expert_id)
    ORDER BY priority DESC, created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;
    
    IF v_image_id IS NOT NULL THEN
        UPDATE public.images 
        SET assigned_expert_2 = p_expert_id
        WHERE id = v_image_id;
        RETURN v_image_id;
    END IF;
    
    RETURN NULL; -- Aucune image disponible
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════
-- FUNCTION: check_annotation_agreement (après 2e annotation)
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.check_annotation_agreement()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
    v_labels TEXT[];
    v_agree BOOLEAN;
BEGIN
    -- Compter les annotations pour cette image
    SELECT count(*), array_agg(disease_label)
    INTO v_count, v_labels
    FROM public.annotations
    WHERE image_id = NEW.image_id;
    
    IF v_count >= 2 THEN
        -- Vérifier accord
        v_agree := v_labels[1] = v_labels[2];
        
        IF v_agree THEN
            UPDATE public.images SET status = 'validated' WHERE id = NEW.image_id;
        ELSE
            UPDATE public.images SET status = 'conflict' WHERE id = NEW.image_id;
        END IF;
    END IF;
    
    -- Mettre à jour le compteur d'annotations de l'expert
    UPDATE public.profiles 
    SET annotations_count = annotations_count + 1
    WHERE id = NEW.expert_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER after_annotation_insert
    AFTER INSERT ON public.annotations
    FOR EACH ROW EXECUTE FUNCTION public.check_annotation_agreement();

-- ═══════════════════════════════════════════════════════════
-- FUNCTION: updated_at trigger
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_images_updated_at BEFORE UPDATE ON public.images
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_disease_sheets_updated_at BEFORE UPDATE ON public.disease_sheets
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ═══════════════════════════════════════════════════════════
-- FUNCTION: audit log helper
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.log_audit(
    p_action TEXT,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_old JSONB DEFAULT NULL,
    p_new JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, old_value, new_value)
    VALUES (auth.uid(), p_action, p_entity_type, p_entity_id, p_old, p_new);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════
-- FUNCTION: overview stats
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_overview_stats()
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_images', (SELECT count(*) FROM public.images),
        'pending', (SELECT count(*) FROM public.images WHERE status = 'pending'),
        'annotating', (SELECT count(*) FROM public.images WHERE status = 'annotating'),
        'annotated', (SELECT count(*) FROM public.images WHERE status = 'annotated'),
        'conflict', (SELECT count(*) FROM public.images WHERE status = 'conflict'),
        'validated', (SELECT count(*) FROM public.images WHERE status = 'validated'),
        'rejected', (SELECT count(*) FROM public.images WHERE status = 'rejected'),
        'agreement_rate', (
            SELECT ROUND(
                COALESCE(
                    count(*) FILTER (WHERE status = 'validated')::numeric / 
                    NULLIF(count(*) FILTER (WHERE status IN ('validated', 'conflict')), 0),
                    0
                ) * 100, 1
            )
            FROM public.images
        ),
        'avg_annotation_time_ms', (SELECT ROUND(avg(annotation_time_ms)) FROM public.annotations),
        'class_distribution', (
            SELECT COALESCE(jsonb_object_agg(disease_label, cnt), '{}'::jsonb)
            FROM (
                SELECT disease_label, count(*) as cnt
                FROM public.annotations
                GROUP BY disease_label
            ) sub
        ),
        'culture_distribution', (
            SELECT COALESCE(jsonb_object_agg(culture, cnt), '{}'::jsonb)
            FROM (
                SELECT COALESCE(culture, 'Inconnu') as culture, count(*) as cnt
                FROM public.images
                GROUP BY culture
            ) sub
        ),
        'active_dataset', (
            SELECT version_tag FROM public.dataset_versions 
            WHERE status = 'active' 
            ORDER BY created_at DESC LIMIT 1
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
