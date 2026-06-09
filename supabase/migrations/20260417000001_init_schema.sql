-- ── Migration Phase 3.1-3.3: Schema complet multi-tenant + RLS ──
-- Version: 20260417000001
-- Description: Schema unifié organisations + profiles + diagnoses + audit + feature_flags

-- ── ENUMS ──
CREATE TYPE user_role AS ENUM ('farmer', 'expert', 'admin');

-- ── ORGANISATIONS (multi-tenancy) ──
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  region TEXT,
  subscription_tier TEXT DEFAULT 'free',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── PROFILES ──
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  organization_id UUID REFERENCES organizations(id),
  role user_role NOT NULL DEFAULT 'farmer',
  phone TEXT,
  locale TEXT DEFAULT 'fr',
  gdpr_consent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── CULTURES SUPPORTÉES ──
CREATE TABLE crops (
  id TEXT PRIMARY KEY,
  display_name JSONB NOT NULL,
  model_version TEXT NOT NULL,
  active BOOLEAN DEFAULT true
);

-- ── DIAGNOSTICS ──
CREATE TABLE diagnoses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  organization_id UUID REFERENCES organizations(id),
  crop_id TEXT NOT NULL REFERENCES crops(id),
  model_version TEXT NOT NULL,
  image_path TEXT NOT NULL,
  predicted_disease_id TEXT,
  confidence NUMERIC(5,4),
  top_k_predictions JSONB,
  gps_location GEOGRAPHY(Point),
  weather_conditions JSONB,
  user_feedback JSONB,
  expert_validation_id UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── AUDIT LOG ──
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  payload JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── FEATURE FLAGS ──
CREATE TABLE feature_flags (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT false,
  rollout_percent INT DEFAULT 100,
  target_users JSONB,
  target_regions TEXT[],
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── INDEXES ──
CREATE INDEX idx_diagnoses_user ON diagnoses(user_id, created_at DESC);
CREATE INDEX idx_diagnoses_crop ON diagnoses(crop_id, created_at DESC);
CREATE INDEX idx_diagnoses_location ON diagnoses USING GIST(gps_location);
CREATE INDEX idx_diagnoses_confidence_low ON diagnoses(created_at) WHERE confidence < 0.7;
CREATE INDEX idx_profiles_org ON profiles(organization_id);
CREATE INDEX idx_audit_user ON audit_log(user_id, created_at DESC);

-- ── RLS POLICIES ──
ALTER TABLE diagnoses ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Policy: users see own diagnoses
CREATE POLICY "users_see_own_diagnoses"
  ON diagnoses FOR SELECT
  USING (
    user_id = auth.uid()
    OR organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
  );

-- Policy: experts see low confidence in their org
CREATE POLICY "experts_see_org_low_confidence"
  ON diagnoses FOR SELECT
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'expert'
    AND organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
    AND confidence < 0.7
  );

-- Policy: users insert own diagnoses
CREATE POLICY "users_insert_own_diagnoses"
  ON diagnoses FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ── SEED: Default feature flags ──
INSERT INTO feature_flags (key, enabled) VALUES
  ('offline_mode', true),
  ('voice_assistant', false),
  ('expert_validation', true),
  ('telemetry', true),
  ('beta_models', false);