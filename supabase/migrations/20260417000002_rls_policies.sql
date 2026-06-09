-- ── Migration Phase 3.3: RLS Policies granulaires ──
-- Version: 20260417000002
-- Description: Politiques RLS stricts multi-tenant + policies storage

-- ══════════════════════════════════════════════════════════════════
-- RLS: diagnoses
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "users_see_own_diagnoses" ON diagnoses;
CREATE POLICY "users_see_own_diagnoses"
  ON diagnoses FOR SELECT
  USING (
    user_id = auth.uid()
    OR (
      organization_id = (
        SELECT organization_id
        FROM profiles
        WHERE id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "users_insert_own_diagnoses" ON diagnoses;
CREATE POLICY "users_insert_own_diagnoses"
  ON diagnoses FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users_update_own_diagnoses" ON diagnoses;
CREATE POLICY "users_update_own_diagnoses"
  ON diagnoses FOR UPDATE
  USING (user_id = auth.uid());
-- ══════════════════════════════════════════════════════════════════
-- RLS: profiles
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "users_read_org_profiles" ON profiles;
CREATE POLICY "users_read_org_profiles"
  ON profiles FOR SELECT
  USING (
    organization_id = (
      SELECT organization_id
      FROM profiles
      WHERE id = auth.uid()
    )
    OR id = auth.uid()
  );

DROP POLICY IF EXISTS "users_update_own_profile" ON profiles;
CREATE POLICY "users_update_own_profile"
  ON profiles FOR UPDATE
  USING (id = auth.uid());

-- ══════════════════════════════════════════════════════════════════
-- RLS: organizations
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "users_read_own_organization" ON organizations;
CREATE POLICY "users_read_own_organization"
  ON organizations FOR SELECT
  USING (
    id = (
      SELECT organization_id
      FROM profiles
      WHERE id = auth.uid()
    )
  );

-- ══════════════════════════════════════════════════════════════════
-- RLS: audit_log (admin only)
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "admins_read_audit_log" ON audit_log;
CREATE POLICY "admins_read_audit_log"
  ON audit_log FOR SELECT
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );
-- ══════════════════════════════════════════════════════════════════
-- Storage policies
-- ══════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "storage_users_access_own_folder" ON storage.objects;
CREATE POLICY "storage_users_access_own_folder"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'diagnosis-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ══════════════════════════════════════════════════════════════════
-- Indexes pour perf
-- ══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_profiles_org
  ON profiles(organization_id);

CREATE INDEX IF NOT EXISTS idx_profiles_role
  ON profiles(role);

CREATE INDEX IF NOT EXISTS idx_audit_log_user
  ON audit_log(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_entity
  ON audit_log(entity_type, entity_id);