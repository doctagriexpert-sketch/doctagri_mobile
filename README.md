# DoctAgri

Application de diagnostic agricole par IA pour les agriculteurs africains.
L'APK peut être distribué sur le terrain ; le diagnostic embarqué et l'historique
local fonctionnent sans compte ni connexion.

## Commencer

- [État réel du projet](docs/project-status.md)
- [Installation développeur](docs/getting-started.md)
- [Architecture](docs/architecture/system-overview.md)
- [Contribuer](CONTRIBUTING.md)
- [Documentation](docs/README.md)

## Organisation

| Dossier | Rôle |
|---|---|
| lib/, android/, ios/ | Flutter et intégrations natives |
| doctagri-dashboard/ | Interface React des experts |
| supabase/ | Migrations et fonctions liées au mobile |
| dashboard/supabase/ | Historique SQL d'annotation, à réconcilier |
| ml/, assets/models/ | Pipeline Python et modèles embarqués |
| packages/ | Modularisation amorcée ; plusieurs squelettes |
| skills/, rules/, AGENTS.md | Procédures et conventions |
| hooks/, scripts/ | Contrôles exécutables partagés avec la CI |
| docs/ | Contrats, décisions, état et dette technique |

## Vérifications

```sh
python scripts/install_hooks.py
python scripts/quality.py repository
python scripts/quality.py all
```

Installer Flutter et les dépendances npm avant les suites applicatives.
Ces contrôles ne prouvent pas seuls la qualité agronomique ou la capacité de production.

## Livraison

Auth, validation experte et contrats SQL nécessitent encore une intégration.
Le paiement réel n'est pas branché. Le recensement Android est écrit ; déploiement
et essais physiques restent à confirmer. Voir [la dette](docs/technical-debt.md).

Les releases Android sont préparées explicitement. Aucun compte store ou
monitoring opérationnel n'est présumé configuré.

Licence : [MIT](LICENSE).
