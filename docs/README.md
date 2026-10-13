# Documentation DoctAgri

## Prendre en main

1. [État du projet](project-status.md) : ce qui est implémenté, partiel et non vérifié.
2. [Installation développeur](getting-started.md) : environnement et commandes.
3. [Architecture réelle](architecture/system-overview.md) : composants et frontières.
4. [Contribution](../CONTRIBUTING.md) et [règles](../AGENTS.md).

## Faire évoluer et livrer

- [Dette technique priorisée](technical-debt.md)
- [Vérifications initiales du cadre](verification/2026-10-02-engineering-foundation.md)
- [Décisions d'architecture](decisions/0001-engineering-foundation.md) et [modèle d'ADR](decisions/template.md)
- [Contrat des installations](contracts/app-installations.md)
- [Enregistrement Android et vérification terrain](installation-registration.md)
- [Pipeline ML](../ml/README.md)
- [Gestion des incidents](runbook/incident-response.md)

Les documents `DOCUMENTATION_TECHNIQUE.md`, `DEMO_SETUP.md`, l'ancienne roadmap
et les runbooks décrivent aussi des intentions historiques. Les capacités
déployées, l'astreinte et les métriques qui y figurent doivent être vérifiées avant
usage opérationnel. L'état daté du projet prime pour savoir ce qui est confirmé.

Une modification de contrat met à jour le contrat ; une décision durable ajoute
une ADR. Éviter de copier une même règle dans plusieurs documents.
