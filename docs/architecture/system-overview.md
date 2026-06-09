# DoctAgri Architecture

## System Context

```
┌─────────────────────────────────────────────────────────────┐
│                        Farmer                               │
│                    (Flutter App)                           │
└─────────────────┬─────────────────────────────────────────┘
                  │ HTTPS
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                     Supabase                                 │
│  ┌─────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────┐  │
│  │ Auth    │  │ Postgres │  │ Storage    │  │ Edge     │  │
│  │ (OTP)   │  │ + RLS    │  │ (Images)   │  │ Functions│  │
│  └─────────┘  └──────────┘  └─────────────┘  └──────────┘  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                  ┌─────▼─────┐
                  │ Dashboard │
                  │  (React)  │
                  └───────────┘
```

## Flutter App Architecture

```
lib/
├── app.dart                    # App widget, theme
├── main.dart                   # Entry point
├── core/
│   ├── constants/              # Colors, spacing, typography
│   ├── errors/                # Failure classes
│   ├── ml/                     # ModelManager, preprocessor
│   ├── router/                 # go_router config
│   ├── services/               # Supabase, sync, telemetry
│   └── di/                    # Dependency injection
├── features/
│   ├── camera/                # Camera capture
│   ├── diagnosis/              # Core feature
│   │   ├── data/              # Repository implementations
│   │   ├── domain/           # Entities, repository interfaces
│   │   └── presentation/      # Pages, providers, widgets
│   └── home/                  # Home page
├── shared/
│   └── widgets/              # Reusable widgets
└── l10n/                      # Internationalization
```

## Package Architecture (Melos)

```
doctagri/
├── melos.yaml
├── packages/
│   ├── doctagri_core/          # Failure, Either, utilities
│   ├── doctagri_design_system/ # Tokens, atoms, molecules
│   ├── doctagri_ml_engine/     # TFLite wrapper, preprocessor
│   ├── doctagri_diagnosis/     # Feature module
│   ├── doctagri_history/       # Feature module
│   ├── doctagri_validation/    # Feature module
│   ├── doctagri_knowledge/     # Disease database
│   ├── doctagri_sync/         # Offline sync
│   ├── doctagri_auth/         # Supabase auth
│   └── doctagri_telemetry/    # Sentry, PostHog
└── apps/
    ├── doctagri_mobile/        # Flutter app
    └── doctagri_dashboard/    # React dashboard
```

## Data Flow

```
Camera Capture
    ↓
preprocessImage() [Isolate]
    ↓
ModelManager.inference()
    ↓
Déquantification + Softmax
    ↓
DiseaseKnowledge lookup
    ↓
DiagnosisResult
    ↓
├── Display result
├── Save to Hive (offline)
└── Queue for Supabase sync
        ↓ (when online)
    Supabase.insertDiagnosis()
```

## ML Pipeline

```
plant_disease_model.keras (TF 2.15)
    ↓
01_export_savedmodel.py → savedmodel/
    ↓
03_quantize_int8.py → model_int8.tflite
    ↓ (calibration dataset)
validate_accuracy.py → accuracy > 92%
    ↓
06_package_artifact.py
    ├── assets/models/model.tflite
    ├── ml/models/registry.json
    └── SHA256 signature
```

## Multi-Tenant Model

```
organizations
    ├── id
    ├── name
    ├── region
    └── subscription_tier
         │
         └──► profiles
              ├── id (FK auth.users)
              ├── organization_id
              └── role (farmer/expert/admin)
                   │
                   └──► diagnoses
                        ├── user_id
                        ├── organization_id (for RLS)
                        └── image_path, predictions
```

## Security Model

| Layer | Mechanism |
|-------|-----------|
| Auth | Supabase OTP (phone number) |
| DB Access | RLS policies (organization isolation) |
| Storage | Per-user folder access |
| API | Signed URLs (1h expiry) |
| App | Obfuscation + ProGuard |
| Network | HTTPS only, cert pinning ready |

## Observability Stack

| Component | Tool | Purpose |
|----------|------|---------|
| Crash Reporting | Sentry | Errors, exceptions |
| Analytics | PostHog | User events, funnels |
| Metrics | Grafana | Latency, throughput |
| Logs | Grafana Loki | Structured logs |
| ML Monitoring | Supabase | Confidence drift, accuracy |
| Uptime | Grafana | Availability SLO |

## SLOs

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| Availability | 99.5% | 99.0% |
| Crash-free users | > 99.5% | 99.0% |
| Inference latency p95 | < 100ms | < 200ms |
| API latency p95 | < 500ms | < 1000ms |
| Diagnosis success rate | > 95% | < 90% |

## Deployment Regions

| Region | Use Case |
|--------|---------|
| EU (Frankfurt) | Primary (RGPD compliant) |
| US (optional) | Future expansion |

## Disaster Recovery

| Scenario | RTO | RPO |
|----------|-----|-----|
| App crash | < 30 min | N/A |
| Model corruption | < 5 min | < 1 day |
| Supabase outage | < 1 hour | < 1 day |
| Full region failure | < 4 hours | < 1 hour |