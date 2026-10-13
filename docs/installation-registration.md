# Recensement des installations Android

À la première ouverture de cette version, l'application crée un UUID aléatoire
et conserve la date, la marque, le modèle, la version Android et la version de
DoctAgri. Un message informe l'utilisateur de cette transmission. Aucun compte,
GPS, numéro de téléphone, IMEI, photo ou diagnostic n'est transmis par ce mécanisme.
Ce dispositif enregistre les installations, pas l'activité ni les déplacements.

Le fichier natif est écrit atomiquement dans `Context.noBackupFilesDir` : il
survit aux mises à jour mais n'est pas copié vers un autre téléphone par backup.
Une désinstallation ou un effacement des données crée une nouvelle installation.
Pour une application déjà utilisée, la date correspond à la première ouverture
de la version équipée, pas à la date d'installation historique.

## Envoi hors interface

WorkManager conserve une tâche unique avec contrainte réseau CONNECTED, exécutée
par un Worker Kotlin sans moteur Flutter, sans session Supabase et sans dépendre
de l'initialisation des modèles IA. Les échecs sont réessayés avec délai exponentiel
(30 secondes initialement, plafonné par WorkManager), sans abandon après N essais.
Le serveur ignore les UUID déjà reçus, y compris si l'application est arrêtée
entre l'insertion distante et l'enregistrement local du succès.

Une fois l'envoi réussi, aucune transmission périodique n'est programmée.
Fermer l'interface n'annule pas la tâche. WorkManager gère la replanification
après redémarrage. Android choisit le moment effectif : Doze, batterie, restrictions
constructeur et arrêt forcé peuvent différer ou empêcher l'exécution. Un arrêt
forcé nécessite normalement une nouvelle ouverture. Aucun délai ni envoi
inconditionnel ne peut être garanti. L'application doit avoir été ouverte au
moins une fois et rester installée. iOS n'est pas implémenté.

## Mise en service

1. Appliquer `supabase/migrations/20261002000000_app_installations.sql` au projet
   cible après revue. La migration ne dépend pas des tables métier existantes.
2. Construire l'APK avec `--dart-define=SUPABASE_URL=https://…` et
   `--dart-define=SUPABASE_ANON_KEY=…` (clé publique anon/publishable uniquement).
   La simple présence d'un `.env` n'injecte pas ces valeurs. Ne jamais embarquer
   une clé service_role. Sans configuration, l'identité est conservée mais
   aucune tâche d'envoi n'est planifiée.
   Le script existant `build_apk.bat` lit le `.env` et passe ces deux paramètres.
3. Distribuer une mise à jour avec la même signature Android et un versionCode
   supérieur à l'APK distribué, puis ouvrir cette version au moins une fois.
4. Consulter `public.app_installations` depuis la console Supabase autorisée.
   Aucun accès en lecture aux clients anonymes ou utilisateurs ordinaires.

La RPC publique autorise uniquement l'insertion idempotente, avec champs bornés.
Ces déclarations ne constituent pas une preuve matérielle d'un téléphone : un
client modifié peut fabriquer des UUID. Avant une diffusion large, prévoir une
limitation de débit en amont pour limiter les inscriptions artificielles.
`first_opened_at` vient de l'horloge du téléphone ; `received_at` vient du serveur.

## Vérification terrain avant distribution

Les tests Flutter ciblés sont dans
`test/unit/core/installation_registration_service_test.dart`.
Le script `supabase/tests/app_installations.sql` vérifie dans une transaction
annulée l'idempotence, les limites de taille et l'interdiction de lecture et de
suppression anonyme. L'exécuter sur une base de test après la migration.

- Installer l'APK configuré sur un appareil Android physique, activer le mode
  avion, ouvrir l'application et vérifier le message d'information.
- Fermer l'interface sans utiliser « Forcer l'arrêt », rétablir Internet et
  vérifier qu'une ligne finit par apparaître sans rouvrir DoctAgri.
- Refaire l'essai avec redémarrage du téléphone avant le retour du réseau.
- Simuler une indisponibilité serveur puis rétablir le serveur : une seule ligne
  doit apparaître, même après plusieurs tentatives ou ouvertures.
- Mettre à jour l'APK signé : l'UUID doit rester identique. Après effacement des
  données, un nouvel UUID est attendu.
- Tester séparément « Forcer l'arrêt » et les restrictions de batterie des
  modèles utilisés sur le terrain ; documenter les délais réellement observés.

Référence : https://developer.android.com/develop/background-work/background-tasks/persistent

## Vérifications réalisées lors de l'implémentation

- Trois tests Flutter ciblés réussis ; analyse statique des deux nouveaux fichiers
  Dart sans anomalie.
- `:app:compileDebugKotlin` réussi avec des substitutions locales de Java et du
  répertoire temporaire, ainsi qu'un script de vérification alignant la cible
  Kotlin de `tflite_flutter` sur sa cible Java 11. Sans cette substitution, la
  configuration existante échoue sur le conflit Java 11 / Kotlin 21 de ce plugin.
  Les substitutions ne modifient pas la configuration de compilation versionnée.
- Migration et tests SQL non exécutés sur un serveur ; aucun déploiement effectué.
- Envoi réel, reprise après redémarrage et restrictions constructeur à vérifier
  sur téléphone physique avant distribution.
