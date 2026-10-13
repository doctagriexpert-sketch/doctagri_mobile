# Installation développeur

## Outils

Flutter **3.44.6** (relevé localement et fixé en CI), Node **22**, JDK **17**,
Android SDK et Python **3.11+**. Les scripts de contrôle utilisent la bibliothèque
standard Python. Supabase CLI et une base isolée sont nécessaires aux tests SQL.
L'environnement d'entraînement ML reste à verrouiller séparément.

## Démarrer

Depuis la racine :

```sh
flutter pub get
npm ci --prefix doctagri-dashboard
python scripts/install_hooks.py
python scripts/quality.py repository
flutter run
```

Sans configuration Supabase, le diagnostic local reste disponible. Injecter les
valeurs publiques SUPABASE_URL et SUPABASE_ANON_KEY avec `--dart-define` ou un
fichier JSON local via `--dart-define-from-file`. Jamais de clé privilégiée.
La simple présence d'un .env n'injecte pas ces valeurs dans Flutter.

Pour React, créer localement doctagri-dashboard/.env avec VITE_SUPABASE_URL et
VITE_SUPABASE_ANON_KEY, puis lancer `npm run dev --prefix doctagri-dashboard`.

## Vérifier

```sh
python scripts/quality.py repository
python scripts/quality.py flutter
python scripts/quality.py dashboard
python scripts/quality.py python
```

`all` lance ces contrôles sans masquer les échecs. Les scripts n'installent rien,
ne reformatent rien et ne déploient rien. Les tests SQL et physiques restent séparés.

## Android et données

Définir JAVA_HOME et le SDK sur sa machine ; aucun chemin personnel dans Gradle.
Le debug ne nécessite pas de keystore de production. La release exige
android/key.properties et la signature historique, exclus de Git.
L'ancien build_apk.bat contient des chemins locaux à vérifier avant usage ;
préférer Flutter explicitement ou le workflow manuel de release.

Avant toute migration, lire DATA-02 dans la dette technique : les deux historiques
Supabase ne doivent pas être concaténés. Identifier le schéma et une base de test ;
ne pas lancer db push sur un projet lié non vérifié.

## CI et release manuelle

Les workflows exécutent les mêmes scripts que les hooks. Les artefacts debug
ne contiennent pas la configuration de production et ne servent pas de release terrain.
Le workflow manuel prépare un APK signé, sans publication store ni migration SQL.

Configurer l'environnement GitHub `production` et ses secrets :
`ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
`ANDROID_KEY_ALIAS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`. Le numéro de build demandé
doit être supérieur à la version distribuée. Les mots de passe sont échappés pour
le format Java Properties ; les fichiers de signature sont supprimés en fin de job.

Le dashboard conserve son déploiement Netlify sur main après tous les contrôles,
avec `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `NETLIFY_AUTH_TOKEN` et
`NETLIFY_SITE_ID`. Les valeurs factices de validation ne permettent pas le déploiement.
Configurer les protections de branche et les approbations d'environnement dans
GitHub avant de traiter la CI comme une barrière de production.
