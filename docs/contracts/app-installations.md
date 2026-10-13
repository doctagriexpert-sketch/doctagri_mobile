# Contrat — Recensement Android

Migration : supabase/migrations/20261002000000_app_installations.sql.
Déploiement non confirmé. Finalité : compter les premières ouvertures de la
version équipée, sans compte. Aucun GPS, nom, téléphone, photo ou diagnostic.

RPC `register_app_installation` :

| Argument | Type / limite |
|---|---|
| p_installation_id | UUID aléatoire local, pas une identité matérielle |
| p_first_opened_at | timestamptz, horloge du téléphone |
| p_manufacturer, p_model | text, 100 caractères chacun |
| p_os_version, p_app_version | text, 50 caractères chacun |

Le serveur ajoute received_at. Réponse void ; succès HTTP acquitté localement.
Les erreurs sont réessayées. Un UUID déjà reçu ne crée pas de doublon et sa ligne
n'est pas modifiée. La lecture/suppression de la table n'est pas publique.

La désinstallation efface l'identité locale, pas la ligne distante. La durée de
conservation et la purge restent à décider avant diffusion large (INSTALL-02).
La RPC publique ne prouve pas qu'un téléphone existe : limiter les abus.
L'application informe l'utilisateur au premier lancement.

Tests SQL : supabase/tests/app_installations.sql sur base de test après migration.
Tests terrain : [guide Android](../installation-registration.md). Aucun délai
d'envoi garanti par Android, notamment après arrêt forcé.
