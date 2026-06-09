# Migrations Supabase — dashboard d'annotation experts

> **TL;DR** — Une migration = un fichier `.sql` horodaté dans ce dossier.
> Pas de CLI Supabase aujourd'hui (cf. dette plus bas) ; les migrations
> sont appliquées **à la main** dans le SQL Editor de Supabase. La source
> de vérité est la **DB live**, pas ces fichiers.

## Vue d'ensemble

Le projet DoctAgri a **deux** projets Supabase distincts, et donc deux
dossiers de migrations indépendants :

| Dossier | Projet | Convention | Workflow |
|---|---|---|---|
| `dashboard/supabase/migrations/` (ici) | Back-office d'annotation experts | Horodatée `YYYYMMDDHHMMSS_*.sql` | Manuel (SQL Editor) |
| `supabase/migrations/` (racine) | App farmer | Horodatée `YYYYMMDDHHMMSS_*.sql` | Manuel (SQL Editor) |

Les schémas sont totalement disjoints : `dashboard` héberge `images`,
`annotations`, `taxonomy`, `validations`, `disease_sheets` ; la racine
héberge le schéma orienté terrain (postgis, profil farmer, products,
orders).

## Convention de nommage

```
YYYYMMDDHHMMSS_<verbe>_<sujet_court>.sql
```

Exemples valides :

- `20260604120000_rename_cassava_labels.sql`
- `20260604130000_add_taxonomy_fk_disease_sheets.sql`
- `20260615093000_drop_legacy_image_status_enum.sql`

Le timestamp **n'a pas besoin d'être l'heure exacte de création** : il
doit juste garantir l'ordre d'application chronologique. Quand tu crées
une migration aujourd'hui, choisis un timestamp **postérieur à la
dernière migration existante** dans le dossier.

> 💡 Astuce : `date -u +"%Y%m%d%H%M%S"` (Unix) ou
> `Get-Date -Format "yyyyMMddHHmmss"` (PowerShell) génère un timestamp
> conforme.

## Les 3 règles d'or

1. **Une migration appliquée ne se renomme JAMAIS et ne se modifie JAMAIS.**
   Si tu dois corriger une migration passée, crée-en une nouvelle qui
   compense (`DROP …`, `ALTER … RENAME`, etc.).

2. **Toute migration doit être idempotente.** Utilise systématiquement :
   - `CREATE TABLE IF NOT EXISTS`
   - `CREATE INDEX IF NOT EXISTS`
   - `INSERT … ON CONFLICT DO NOTHING` (ou `DO UPDATE`)
   - `DO $$ BEGIN IF NOT EXISTS (...) THEN ... END IF; END $$` pour les
     contraintes et policies (pas de `IF NOT EXISTS` natif en Postgres).

   Pourquoi : la même migration peut être lancée plusieurs fois (test,
   staging, prod, redéploiement après incident). Elle doit toujours
   converger vers le même état sans crasher.

3. **Une migration doit être englobée par une transaction** (`BEGIN; …
   COMMIT;`) sauf si elle contient des commandes qui ne peuvent pas être
   transactionnelles (ex. `CREATE INDEX CONCURRENTLY`, `ALTER TYPE …
   ADD VALUE`). Cela garantit l'atomicité : si une étape échoue, tout
   est annulé.

## Runbook — créer une migration

```bash
# 1. Générer le timestamp
TS=$(date -u +"%Y%m%d%H%M%S")

# 2. Créer le fichier avec un nom explicite
touch "dashboard/supabase/migrations/${TS}_add_severity_index.sql"

# 3. Écrire le SQL en respectant les 3 règles ci-dessus
```

Template minimal :

```sql
-- ═══════════════════════════════════════════════════════════
-- YYYYMMDDHHMMSS_<verbe>_<sujet>.sql
--
-- <Une à trois lignes sur le pourquoi métier de cette migration>
--
-- Idempotente : peut être ré-appliquée sans effet de bord.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ton SQL ici, idempotent (IF NOT EXISTS, ON CONFLICT, etc.)

COMMIT;
```

## Runbook — appliquer une migration en prod

Workflow CLI (recommandé depuis le 4 juin 2026) :

```powershell
# 1. Set le DB password en env var (cf. CLI_SETUP.md si la CLI n'est pas
#    encore en place sur ton poste)
$env:SUPABASE_DB_PASSWORD = '<password>'

# 2. Push : applique toutes les migrations locales pas encore trackées
cd D:\doctagri\dashboard
supabase db push

# 3. Vérifie l'état après
supabase migration list
```

Workflow manuel (fallback, si CLI cassée ou pas configurée) :

1. Connecte-toi au projet `doctagriexpert-sketch's Project` sur app.supabase.com.
2. Onglet **SQL Editor**.
3. Crée un nouveau snippet, copie-colle le contenu **complet** du
   fichier `.sql`.
4. Vérifie une dernière fois que tu es sur le **bon projet** (en haut
   à droite — pas le projet `doctagri` qui est l'app farmer !).
5. Clique **Run**. Attends `Success`.
6. **Important** si tu passes en mode manuel : marque la migration comme
   appliquée dans le tracker CLI après coup, sinon le prochain
   `supabase db push` la rejouera :
   ```powershell
   supabase migration repair --status applied <version>
   ```
7. Vérifie avec une requête de contrôle (voir runbook suivant).
8. Commit le fichier sur Git pour l'historique.

## Runbook — vérifier qu'une migration a réussi

Après chaque application, lance une requête de contrôle qui matérialise
l'effet attendu. Quelques exemples génériques :

```sql
-- Nouvelle colonne ?
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='<table>';

-- Nouvelle contrainte ?
SELECT conname, contype FROM pg_constraint
WHERE conrelid = 'public.<table>'::regclass;

-- Nouvelle policy ?
SELECT polname FROM pg_policy
WHERE polrelid = 'public.<table>'::regclass;

-- Donnée seedée présente ?
SELECT count(*) FROM public.<table> WHERE <colonne>=<valeur attendue>;
```

## Dettes connues (à ne pas oublier)

### Intégrité référentielle partielle sur `taxonomy.model_label`

`taxonomy.model_label` est `UNIQUE` mais peu de tables ont une FK vers
elle. Seule `disease_sheets.model_label` a une FK (`NOT VALID`, donc
non rétroactive) depuis la migration `20260604130000_*`.

Les chemins critiques **n'ont pas de FK** par choix :

- `images.ml_predicted_label` — alimenté par l'app farmer avec la
  sortie du modèle TFLite. Une FK bloquerait l'ingestion dès qu'un
  nouveau label modèle arriverait sans avoir été déclaré dans
  `taxonomy` au préalable.
- `annotations.disease_label` — saisi par les experts via un dropdown
  alimenté par `taxonomy`, mais stocké comme TEXT libre côté DB.
- `validations.final_label` — idem.

**Le jour où l'équipe ML formalisera un workflow de pré-déclaration des
labels modèles**, ces FK pourront être ajoutées avec un seed coordonné.

### Anciens noms `001_*–004_*` figés en historique Git

Avant le 4 juin 2026, les migrations utilisaient une numérotation
séquentielle (`001_*` à `004_*`) avec une collision sur `004_*` (deux
fichiers existaient). Tous ont été renommés en horodaté le 4 juin. Le
Git log conserve la trace. À partir d'aujourd'hui : **uniquement la
convention horodatée**.

### Ne supprime jamais une seed migration

`20260305000002_rls_policies.sql` (ex-`002_rls_policies.sql`) contient
un `INSERT INTO public.taxonomy …` historique. Ces lignes ont été
modifiées en live par des migrations ultérieures (`20260604120000_*`
notamment). **Ne modifie surtout pas le seed en place** pour
« rattraper » — le seed est figé dans son état historique au moment de
son application, et la DB live est la source de vérité.

## Index des migrations

| Fichier | Effet métier |
|---|---|
| `20260305000001_initial_schema.sql` | Schéma initial : `images`, `annotations`, `taxonomy`, `validations`, `disease_sheets`, RPC `get_next_image`, etc. |
| `20260305000002_rls_policies.sql` | RLS par rôle + seed initial de `taxonomy` |
| `20260305000003_resolve_conflict_rpc.sql` | RPC `resolve_conflict` pour les seniors |
| `20260307000001_indexes.sql` | Index composites + partiels pour scalabilité |
| `20260307000002_storage_rls.sql` | Bucket `diagnosis-images` + RLS storage |
| `20260604120000_rename_cassava_labels.sql` | `Healthy` → `Cassava___healthy`, `Unknown` → `Cassava___unknown` (cf. audit qualité diagnostic QW1) |
| `20260604130000_add_taxonomy_fk_disease_sheets.sql` | FK atténuée `disease_sheets.model_label` → `taxonomy.model_label` |
