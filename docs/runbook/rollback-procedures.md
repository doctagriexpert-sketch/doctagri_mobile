# Rollback Procedures

## App Rollback (< 30 min)

### Android (Google Play)
1. Log into Google Play Console
2. Go to Release > Management > Artifact library
3. Select previous working release
4. Click "Release to production" with rollback version
5. Set staged rollout to 1% initially

### Android (APK Direct / Firebase App Distribution)
```bash
# List recent releases
ls -la build/app/outputs/flutter-apk/

# Install specific version
adb install -r build/app/outputs/flutter-apk/app-release-v1.2.3.apk
```

### iOS (TestFlight / App Store)
1. Log into App Store Connect
2. Go to TestFlight > Builds
3. Select previous build
4. For App Store: reject current build, release previous

## Model Rollback (< 5 min)

### Via Feature Flag
```sql
-- Disable new model
UPDATE feature_flags SET enabled=false WHERE key='beta_models';

-- Or set rollout to 0%
UPDATE feature_flags SET rollout_percent=0 WHERE key='beta_models';
```

### Manual (if DB unavailable)
```bash
# In app, model loading reads from feature_flags
# Restart app to reload flags
```

## Backend Migration Rollback

### Supabase Migration
```bash
# Check migration status
supabase migrations list

# Rollback last migration
supabase db reset --dry-run  # Preview first
supabase db reset           # Execute
```

### Specific Migration
```bash
# Rollback migration 20260417000001
psql $DATABASE_URL -c "DROP TABLE IF EXISTS diagnoses CASCADE;"
psql $DATABASE_URL -c "DROP TABLE IF EXISTS profiles CASCADE;"
# ... (see migration for full rollback SQL)
```

## Staged Rollout Restart

### Android Release Steps
1. Go to Google Play Console > Release > Production
2. Select "Manage track" > "Edit release"
3. Choose "Replace" with previous APK
4. Set percentage: 1% → 10% → 50% → 100%
5. Wait 24h at each stage if no issues

## Verification After Rollback

```bash
# Check crash rate
curl -s "https://sentry.io/api/0/projects/doctagri/android/releases/" \
  | jq '.[] | select(.version=="$OLD_VERSION") | .stats'

# Check error rate
grafana-cli queries execute \
  'sum(rate(errors_total{version="$OLD_VERSION"}[5m]))'

# Health check
curl -f https://api.doctagri.com/health || echo "UNHEALTHY"
```