# Setup Supabase CLI — guide one-shot

Ce guide te fait passer du workflow **manuel via SQL Editor** au workflow
**CLI Supabase** pour le projet dashboard. C'est un one-shot d'environ
1–2 h à faire **une seule fois**, par une personne qui a accès au projet
Supabase et aux secrets.

> ⚠️ **Avant de commencer** — vérifie deux choses :
> 1. Tu as les droits owner ou admin sur le projet Supabase dashboard.
> 2. Aucune migration n'est en cours d'écriture par un collègue
>    (sinon on risque un conflit).

## Étape 0 — Récupérer le project ref

Sur app.supabase.com, projet `dashboard` → **Project Settings → General**.
Le **Reference ID** est une chaîne de ~20 caractères (ex.
`abcdefghijklmnopqrst`). Copie-le, on en a besoin partout.

```bash
export DASHBOARD_REF="<colle-ici>"
```

## Étape 1 — Installer la CLI

**macOS / Linux** :
```bash
brew install supabase/tap/supabase
```

**Windows — au choix selon ce qui est dispo** :

```powershell
# Option A — winget (préinstallé sur Windows 10/11, le plus simple)
winget install Supabase.CLI

# Option B — Scoop (si déjà installé, sinon voir Annexe Windows plus bas)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Option C — npx (zéro install permanente, à préfixer à chaque commande)
npx supabase --version

# Option D — binaire direct depuis https://github.com/supabase/cli/releases
```

> Après install, **ferme et rouvre PowerShell** pour que le PATH soit
> rechargé.

**Vérifie** :
```bash
supabase --version
# 1.x ou 2.x → bon
```

## Étape 2 — Login

```bash
supabase login
```

Ça ouvre le navigateur pour l'auth. Une fois la session établie, tu
peux fermer l'onglet et revenir au terminal.

## Étape 3 — Linker le projet dashboard

Depuis la **racine du repo** (pas depuis `dashboard/`) :

```bash
cd D:/doctagri
supabase link --project-ref "$DASHBOARD_REF" --workdir dashboard
```

Le flag `--workdir dashboard` indique à la CLI que les fichiers de
config et de migrations vivent dans `dashboard/supabase/`, pas à la
racine. Sans ça, la CLI prendrait par défaut `supabase/` (le projet
farmer) — **mauvaise cible**.

> 💡 Si `--workdir` n'est pas supporté par ta version de CLI, fais
> juste `cd dashboard && supabase link --project-ref "$DASHBOARD_REF"`.

La commande va te demander le **mot de passe DB postgres** du projet
(le set au moment de la création du projet ; récupérable dans Project
Settings → Database).

## Étape 4 — Reconstruire le tracker de migrations historiques

C'est l'étape sensible. On veut dire à la CLI : « ces 5 migrations
historiques + les 2 récentes sont **déjà appliquées en prod, ne les
rejoue pas** ».

```bash
# Marque chaque migration historique comme appliquée SANS l'exécuter
supabase migration repair --status applied 20260305000001 --workdir dashboard
supabase migration repair --status applied 20260305000002 --workdir dashboard
supabase migration repair --status applied 20260305000003 --workdir dashboard
supabase migration repair --status applied 20260307000001 --workdir dashboard
supabase migration repair --status applied 20260307000002 --workdir dashboard
supabase migration repair --status applied 20260604120000 --workdir dashboard
supabase migration repair --status applied 20260604130000 --workdir dashboard
```

Chaque commande doit retourner `Repaired migration history`.

> ⚠️ **Pourquoi `applied` et pas `reverted`** : tes migrations
> historiques ONT bien été exécutées en prod (on l'a vérifié pour la
> `20260604120000` notamment — `taxonomy` contient bien
> `Cassava___healthy`). Marquer `applied` enregistre cet état dans le
> tracker sans re-exécuter le SQL.

## Étape 5 — Vérifier l'état

```bash
supabase migration list --workdir dashboard
```

Tu dois voir une colonne **Local** et une colonne **Remote** alignées
sur les 7 versions. Si une seule désynchro apparaît, refais le `repair`
correspondant.

## Étape 6 — Workflow CLI à partir d'aujourd'hui

À la racine du repo, pour créer + appliquer une nouvelle migration :

```bash
# 1. Génère un fichier horodaté dans dashboard/supabase/migrations/
supabase migration new add_severity_index --workdir dashboard

# 2. Édite le fichier qui vient d'apparaître

# 3. Applique en local (si tu as un docker dev) ou direct en prod
supabase db push --workdir dashboard
```

`supabase db push` n'applique que les migrations **non encore
trackées** comme `applied` côté distant — donc safe.

> 💡 Pour un dry-run avant push : `supabase db diff --workdir dashboard`
> affiche le SQL qui sera exécuté.

## Étape 7 — Mettre à jour le README

Une fois les étapes ci-dessus passées, édite `dashboard/supabase/README.md` :

- Section **« Runbook — appliquer une migration en prod »** : remplace
  le workflow manuel SQL Editor par `supabase db push --workdir dashboard`.
- Section **« Dettes connues → Pas de CLI Supabase »** : supprime ce
  paragraphe (la dette est réglée).

## Étape 8 — Appliquer le même setup au projet farmer

Le projet `supabase/` (racine) a son propre Reference ID et son propre
historique de migrations (`20260417*`, `20260421*`, `20260514*`).
Refais les étapes 0–7 pour lui aussi, **sans `--workdir`** cette fois.

```bash
export FARMER_REF="<reference-id-du-projet-farmer>"
cd D:/doctagri
supabase link --project-ref "$FARMER_REF"
# repair sur chaque migration historique
supabase migration repair --status applied 20260417000000
supabase migration repair --status applied 20260417000001
supabase migration repair --status applied 20260417000002
supabase migration repair --status applied 20260417000003
supabase migration repair --status applied 20260417000004
supabase migration repair --status applied 20260421000000
supabase migration repair --status applied 20260514000000
supabase migration list
```

## Erreurs courantes

| Erreur | Cause | Fix |
|---|---|---|
| `failed to connect: password authentication failed` | Mauvais mot de passe DB postgres | Récupère-le dans Project Settings → Database |
| `Cannot find project` | Project ref invalide ou login expiré | `supabase login` puis re-vérifie le ref |
| `remote migration ... not found locally` | La CLI voit une migration en prod absente du dossier | Investiguer en SQL Editor — quelqu'un a appliqué un truc hors fichier |
| `local migration ... not found in remote` | Migration ajoutée au repo mais jamais appliquée | C'est normal pour une nouvelle migration ; `db push` la jouera |
| `permission denied to alter role` lors d'un `migration list` ou `db push` | Free tier Supabase : le rôle `postgres` n'a pas `CREATEROLE`, la CLI ne peut pas créer son rôle helper `cli_login_postgres` | Setter le DB password en env var et relancer : `$env:SUPABASE_DB_PASSWORD = "..."` (PowerShell) ou `export SUPABASE_DB_PASSWORD=...` (bash). Voir Project Settings → Database pour récupérer/reset le password. |

## Question fréquente

**Q : Et si je veux abandonner et revenir au mode manuel ?**
A : Tu peux simplement arrêter d'utiliser la CLI. La table
`supabase_migrations.schema_migrations` reste mais elle n'est pas
contraignante. Aucune perte de données. Le retour en arrière coûte 0.

**Q : Faut-il faire ce setup en local pour CHAQUE dev ?**
A : Oui — chaque dev qui veut appliquer une migration en prod doit
faire les étapes 1–3 (CLI + login + link). Les étapes 4–6 ne sont à
faire qu'une fois par projet, par n'importe qui.

## Annexe Windows — installer Scoop

Si tu veux passer par Scoop (option B de l'étape 1) mais qu'il n'est
pas encore installé :

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

Une fois Scoop dispo, reprends l'étape 1 avec les commandes `scoop …`.
