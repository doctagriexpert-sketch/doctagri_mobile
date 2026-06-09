-- ── Migration Phase 4: ML Monitoring tables ──
-- Version: 20260417000004
-- Description: Tables pour ML monitoring, drift detection, A/B testing

-- ══════════════════════════════════════════════════════════════════
-- ML MODEL VERSIONS
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE ml_model_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL UNIQUE,
  crop_id TEXT NOT NULL REFERENCES crops(id),
  filename TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  accuracy NUMERIC(5,4),
  precision_at_expert NUMERIC(5,4),
  mean_confidence NUMERIC(5,4),
  std_confidence NUMERIC(5,4),
  min_confidence NUMERIC(5,4),
  max_confidence NUMERIC(5,4),
  latency_p50_ms NUMERIC(10,2),
  latency_p95_ms NUMERIC(10,2),
  released_at TIMESTAMPTZ DEFAULT now(),
  deprecated_at TIMESTAMPTZ,
  metadata JSONB,
  CONSTRAINT positive_accuracy CHECK (accuracy >= 0 AND accuracy <= 1)
);

-- ══════════════════════════════════════════════════════════════════
-- CONFIDENCE DISTRIBUTION (daily histogram)
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE confidence_distribution (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version TEXT NOT NULL REFERENCES ml_model_versions(version),
  crop_id TEXT NOT NULL,
  date DATE NOT NULL,
  bucket_0_2 INTEGER DEFAULT 0,
  bucket_2_4 INTEGER DEFAULT 0,
  bucket_4_6 INTEGER DEFAULT 0,
  bucket_6_8 INTEGER DEFAULT 0,
  bucket_8_1 INTEGER DEFAULT 0,
  total INTEGER DEFAULT 0,
  mean_confidence NUMERIC(5,4),
  median_confidence NUMERIC(5,4),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(model_version, date)
);

-- ══════════════════════════════════════════════════════════════════
-- CLASS DISTRIBUTION (daily per-class)
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE class_distribution (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version TEXT NOT NULL REFERENCES ml_model_versions(version),
  crop_id TEXT NOT NULL,
  date DATE NOT NULL,
  predicted_label TEXT NOT NULL,
  count INTEGER DEFAULT 0,
  proportion NUMERIC(5,4),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(model_version, date, predicted_label)
);

-- ══════════════════════════════════════════════════════════════════
-- EXPERT FEEDBACK (precision tracking)
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE expert_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  diagnosis_id UUID NOT NULL REFERENCES diagnoses(id),
  model_version TEXT NOT NULL,
  predicted_label TEXT NOT NULL,
  expert_label TEXT,
  confirmed BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT now(),
  validated_at TIMESTAMPTZ
);

-- ══════════════════════════════════════════════════════════════════
-- EXPERIMENT ASSIGNMENTS (A/B testing)
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE experiment_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  experiment_name TEXT NOT NULL,
  variant TEXT NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  converted_at TIMESTAMPTZ,
  conversion_event TEXT,
  UNIQUE(user_id, experiment_name)
);

-- ══════════════════════════════════════════════════════════════════
-- INDEXES
-- ══════════════════════════════════════════════════════════════════

CREATE INDEX idx_confidence_dist_version ON confidence_distribution(model_version, date DESC);
CREATE INDEX idx_confidence_dist_crop ON confidence_distribution(crop_id, date DESC);
CREATE INDEX idx_class_dist_version ON class_distribution(model_version, date DESC);
CREATE INDEX idx_expert_feedback_diagnosis ON expert_feedback(diagnosis_id);
CREATE INDEX idx_expert_feedback_version ON expert_feedback(model_version);
CREATE INDEX idx_experiment_user ON experiment_assignments(user_id, experiment_name);
CREATE INDEX idx_experiment_active ON experiment_assignments(converted_at) WHERE converted_at IS NULL;

-- ══════════════════════════════════════════════════════════════════
-- DRIFT DETECTION: fonction de comparaison jour/jour
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION detect_confidence_drift(
  p_model_version TEXT,
  p_crop_id TEXT,
  p_threshold NUMERIC DEFAULT 0.05
) RETURNS TABLE (
  date_prev DATE,
  date_curr DATE,
  mean_prev NUMERIC,
  mean_curr NUMERIC,
  drift NUMERIC,
  alert BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH daily AS (
    SELECT date, mean_confidence
    FROM confidence_distribution
    WHERE model_version = p_model_version AND crop_id = p_crop_id
    ORDER BY date DESC
    LIMIT 7
  ),
  pairwise AS (
    SELECT
      d1.date as date_curr,
      d2.date as date_prev,
      d1.mean_confidence as mean_curr,
      d2.mean_confidence as mean_prev
    FROM daily d1
    JOIN daily d2 ON d2.date = d1.date - INTERVAL '1 day'
  )
  SELECT
    pairwise.date_prev,
    pairwise.date_curr,
    pairwise.mean_prev,
    pairwise.mean_curr,
    pairwise.mean_curr - pairwise.mean_prev as drift,
    ABS(pairwise.mean_curr - pairwise.mean_prev) > p_threshold as alert
  FROM pairwise;
END;
$$ LANGUAGE plpgsql;