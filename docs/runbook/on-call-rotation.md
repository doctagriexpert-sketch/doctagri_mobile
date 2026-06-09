# On-Call Rotation

## Schedule

| Week | Primary | Secondary | Escalation |
|------|---------|-----------|------------|
| 2026-W17 | @alice | @bob | @cto |
| 2026-W18 | @bob | @carol | @cto |
| 2026-W19 | @carol | @alice | @cto |
| 2026-W20 | @alice | @bob | @cto |

## Responsibilities

### Primary On-Call
- **Response time SLA**: P0 within 15 min
- **Duty hours**: 24/7 during assigned week
- **Actions**: Acknowledge, initial triage, page secondary if needed
- **Tools**: PagerDuty, Sentry, Grafana, Slack

### Secondary On-Call
- **Response time SLA**: P0 within 30 min if primary unreachable
- **Duty hours**: 24/7 backup, only paged if primary doesn't respond
- **Actions**: Assist primary, provide specialized knowledge

### Escalation (CTO/VP Engineering)
- **Triggered**: P0 not resolved within 1 hour OR multiple P1s simultaneously
- **Actions**: Resource allocation, external communications, post-mortem oversight

## Communication Channels

| Channel | Purpose | Access |
|---------|---------|--------|
| #incidents | Active incident coordination | All engineers |
| #oncall | On-call handoff, schedule changes | All engineers |
| #doctagri-alerts | Automated alerts (Sentry, Grafana) | On-call team |
| pagerduty.doctagri.com | PagerDuty web | On-call only |

## Escalation Path

```
Alert fires
    ↓
Primary On-Call (PagerDuty)
    ↓ (15 min no response)
Secondary On-Call
    ↓ (30 min no response)
CTO
    ↓ (1 hour)
CEO (only if P0 affecting > 50% users)
```

## Handoff Checklist

- [ ] Review previous week's incidents
- [ ] Check pending MRs for Sentry issues
- [ ] Verify PagerDuty schedule is correct
- [ ] Update Slack status with on-call info
- [ ] Review runbook for new scenarios
- [ ] Check model monitoring dashboard for drift alerts

## Compensation

- Primary on-call week: +€150/month
- Secondary on-call week: +€75/month
- P0 incident worked: +€50/incident
- Post-mortem completed: +€100