# Vérification du cadre d'ingénierie — 2 octobre 2026

Vérifications locales sur Windows, Flutter 3.44.6 / Dart 3.12.2. Aucun push,
déploiement, application de migration ou modification de protection GitHub.

| Contrôle | Résultat |
|---|---|
| Garde-fous du dépôt et liens documentaires | Réussis |
| Tests des hooks et préparation de signature | 9 réussis |
| Validation des 4 skills par quick_validate.py | Réussie |
| Parsing YAML des 4 workflows et de Lefthook | Réussi ; pas une exécution GitHub Actions |
| Syntaxe Python scripts/hooks/pipeline | Réussie ; pas une validation d'entraînement |
| Flutter tests | 112 réussis |
| Flutter analyze | 5 diagnostics info de dépendances absentes du manifeste test/pubspec.yaml |
| Formatage Dart en lecture seule | Écarts hérités ; aucun reformatage général effectué |
| Dashboard tests | 8 réussis |
| Dashboard build | Réussi ; avertissement de bundle supérieur à 500 kB |
| Dashboard ESLint | 13 erreurs et 2 avertissements préexistants |
| Android :app:compileDebugKotlin | Réussi sans script temporaire d'alignement Kotlin |
| Hook pre-commit via Git Bash | Réussi |
| core.hooksPath du clone | hooks ; anciens fichiers conservés |

La compilation Android a utilisé le JDK 21 d'Android Studio et un dossier temporaire
local sans espaces via paramètres de commande. Les chemins personnels ont été
retirés de Gradle versionné ; la CI cible JDK 17. Le plugin tflite_flutter est
désormais explicitement aligné sur sa cible Java 11. Aucun APK release produit.

## Dette mesurée

- Dépendances des tests Flutter : image, hive et equatable sont utilisées mais non
  déclarées dans le manifeste imbriqué. Clarifier ce manifeste avant de modifier
  les exclusions de l'analyseur.
- ESLint : imports/variables inutilisés, ordre de déclaration, effets React et
  règles Fast Refresh. Les erreurs sont dans les fichiers applicatifs existants,
  non modifiés par le cadre.
- Le contrôle de formatage ignore désormais les sorties g.dart, freezed.dart et
  injection_container.config.dart : elles doivent être régénérées, pas retouchées manuellement.
- Les contrôles complets empêchent un pre-push tant que cette dette n'est pas
  corrigée. Ils ne sont pas désactivés pour afficher un résultat vert.

Les logs détaillés locaux sont dans build/verification/governance-*.log, hors Git.
La compilation locale ne valide ni les secrets GitHub, ni une installation sur
téléphone, ni la base de données distante.
