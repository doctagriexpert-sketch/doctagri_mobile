# Terra-orbit web

Voir [l’état réel et les commandes](../README.md) et le [contrat des sources](../../docs/contracts/terra-orbit-environment.md).

Le frontend Next.js centralise le chargement dans `useRegionalEnvironment`. Le graphique et le simulateur utilisent la même réponse NASA. Le panneau sol édite un état contrôlé, conservé entre onglets et réinitialisé au changement de région.

`npm test` lance des régressions déterministes (fournisseurs simulés, cycle de vie des hooks, rendu React). `npm run typecheck` vérifie TypeScript ; `npm run build` vérifie le bundle de production. Aucun test local ne certifie la disponibilité d’un fournisseur ou la précision terrain.
