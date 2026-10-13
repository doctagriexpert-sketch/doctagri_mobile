# Contribuer à DoctAgri

Lire [le guide développeur](docs/getting-started.md), [l'état réel](docs/project-status.md)
et [AGENTS.md](AGENTS.md).

1. Décrire le besoin, le résultat attendu et sa vérification.
2. Travailler sur une branche dédiée en préservant les changements locaux.
3. Ajouter un test de régression pour une correction de logique ; actualiser le contrat.
4. Exécuter les contrôles pertinents et inspecter le diff, y compris le code produit par IA.
5. Présenter une PR avec preuves, compatibilité et limites ; obtenir une revue.

`python scripts/install_hooks.py` active les hooks pour ce clone. Il préserve les
anciens fichiers `.git/hooks/`, qui cessent d'être utilisés avec `core.hooksPath=hooks`.
Un chemin personnalisé existant n'est pas remplacé automatiquement.

Le pre-commit contrôle l'index sans le modifier. Le pre-push lance les suites locales.
La CI reste nécessaire si un hook a été contourné. Consigner les échecs hérités
dans [la dette technique](docs/technical-debt.md), sans les masquer.

Configurer sur GitHub la protection de main/develop, une revue obligatoire et les
checks CI requis. Ces paramètres distants ne sont pas activés par un fichier.
Ajouter CODEOWNERS lorsque les responsables réels sont désignés.
