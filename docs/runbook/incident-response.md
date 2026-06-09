# Incident Response

## Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P0 | Service down, no workaround | 15 min | App crashes on launch, API unreachable |
| P1 | Major feature broken | 1 hour | Diagnosis fails, sync broken |
| P2 | Minor feature broken | 4 hours | History not loading, UI glitch |
| P3 | Cosmetic issue | 24 hours | Typo, color wrong |

## Response Procedure

### P0 (Critical)
1. **Acknowledge** - 15 min SLA starts now
2. **Escalate** - Page on-call via PagerDuty
3. **Identify** - Check Sentry for crash, Grafana for metrics
4. **Mitigate** - Rollback app OR disable feature flag
5. **Communicate** - Post to status page within 30 min
6. **Resolve** - Deploy fix or confirm rollback
7. **Post-mortem** - Within 48h (blameless)

### P1 (Major)
1. **Acknowledge** - 1 hour SLA
2. **Investigate** - Check logs, metrics, recent deploys
3. **Mitigate** - Rollback OR feature disable OR patch
4. **Communicate** - Update status page
5. **Resolve** - Deploy fix
6. **Post-mortem** - Within 1 week

## Quick Commands

```bash
# Check recent deploys
git log --oneline -10

# Check which version is deployed
curl -s https://api.doctagri.com/version

# Rollback app to previous version (Android)
adb install -r app-release-old.apk

# Disable feature flag
supabase db execute "UPDATE feature_flags SET enabled=false WHERE key='voice_assistant';"

# Check error rate in Grafana
grafana-cli admin dashboards get 12345 | jq '.panels[0].targets[0].expr'
```

## Rollback Decision Tree

```
Is error rate > 5%?
├── YES → Is it from a new app version?
│   ├── YES → Rollback app immediately
│   └── NO → Is it from a backend migration?
│       ├── YES → Rollback migration
│       └── NO → Investigate further
└── NO → Monitor for 15 min, escalate if > 10%
```

## Contacts

| Role | Contact |
|------|---------|
| On-call | pagerduty.doctagri.com |
| Backend Lead | slack: #oncall-backend |
| ML Lead | slack: #oncall-ml |
| PO | slack: #doctagri-product |