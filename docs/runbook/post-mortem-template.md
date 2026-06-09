# Post-Mortem Template

> **Blameless post-mortem**: We're looking for what went wrong in our systems and processes, not who made mistakes.

## Incident Overview

| Field | Value |
|-------|-------|
| Incident ID | INC-YYYY-MM-DD-NNN |
| Date | YYYY-MM-DD |
| Duration | HH:MM to HH:MM (UTC) |
| Severity | P0 / P1 / P2 / P3 |
| Impact | X users affected, Y% of traffic |

## Timeline

| Time (UTC) | Event |
|-----------|-------|
| HH:MM | Alert triggered (Sentry/Grafana) |
| HH:MM | On-call acknowledged |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Incident resolved |

## Root Cause

_Describe what actually caused the incident. Be specific and technical._

## Impact

- Users affected: X
- Revenue impact: €Y (if applicable)
- Failed diagnoses: Z
- Error rate peak: %

## Detection

_How was this incident detected? Was it via automated alert, user report, or something else?_

## Response

_What actions were taken during the incident?_

## Lessons Learned

### What Went Well
- _List positive outcomes_

### What Could Be Improved
- _List areas for improvement_

## Action Items

| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| TODO | @owner | YYYY-MM-DD | Open |
| TODO | @owner | YYYY-MM-DD | Open |

## Related Incidents

- INC-YYYY-MM-DD-NNN - Previous similar incident
- Links to related issues or tickets

---

**To be completed within 48h of incident resolution**