-- ── Migration Phase 3.5: Audit triggers + compliance ──
-- Version: 20260417000003
-- Description: Triggers audit_log + encryption + backup config

-- ══════════════════════════════════════════════════════════════════
-- TRIGGER: audit_log sur tables sensibles
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_audit_event()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (
    user_id,
    action,
    entity_type,
    entity_id,
    payload,
    ip_address,
    user_agent
  ) VALUES (
    COALESCE(auth.uid(), NEW.user_id),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    jsonb_build_object(
      'old_data', CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
      'new_data', CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
    ),
    current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
    current_setting('request.headers', true)::jsonb->>'user-agent'
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger sur diagnoses
CREATE TRIGGER diagnoses_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON diagnoses
  FOR EACH ROW EXECUTE FUNCTION public.handle_audit_event();

-- Trigger sur profiles
CREATE TRIGGER profiles_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_audit_event();

-- ══════════════════════════════════════════════════════════════════
-- ENCRYPTION: colonnes PII (via pgsodium si disponible)
-- Note: Activer pgsodium extension dans Supabase dashboard > Extensions
-- ══════════════════════════════════════════════════════════════════

-- Example: chiffrer phone avec pgsodium
-- ALTER TABLE profiles ADD COLUMN phone_encrypted TEXT;
-- CREATE TRIGGER encrypt_phone_trigger
--   BEFORE INSERT OR UPDATE ON profiles
--   FOR EACH ROW EXECUTE FUNCTION pgsodium.crypto_secretbox_encrypt();

-- ══════════════════════════════════════════════════════════════════
-- BACKUP CONFIG: retention 30j (configuré via Supabase Dashboard)
-- Docs: https://supabase.com/docs/guides/database/management/backups
-- ══════════════════════════════════════════════════════════════════

-- Retention policy (via pgcron si disponible)
-- SELECT cron.schedule('monthly-backup-cleanup', '0 0 1 * *',
--   $$DELETE FROM backup_history WHERE created_at < now() - interval '30 days'$$);

-- ══════════════════════════════════════════════════════════════════
-- GDPR: soft delete columns
-- ══════════════════════════════════════════════════════════════════

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE diagnoses ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- View:only non-deleted records
CREATE OR REPLACE VIEW active_diagnoses AS
  SELECT * FROM diagnoses WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW active_profiles AS
  SELECT * FROM profiles WHERE deleted_at IS NULL;