---
name: doctagri-supabase
description: Faire évoluer les migrations, RPC, RLS et flux de synchronisation Supabase de DoctAgri en vérifiant les contrats clients et la compatibilité des deux historiques SQL.
---

# Faire évoluer les données DoctAgri

Lire `rules/data-security.md` et `docs/architecture/system-overview.md`.

1. Identifier le consommateur et le schéma cible. `supabase/migrations/` porte le
   mobile ; `dashboard/supabase/migrations/` porte l'annotation. Les tables
   homonymes ne justifient pas de concaténer les migrations.
2. Comparer chaque champ envoyé par Flutter/React avec type, nullabilité, valeur
   par défaut et contrainte SQL. Vérifier aussi les réponses et erreurs attendues.
3. Écrire une migration additive ou une stratégie de transition explicite. Une
   migration déjà appliquée ne se réécrit pas pour faire passer le client récent.
4. Tester sur une base locale ou de staging identifiée : propriétaire, autre
   utilisateur, anonyme, rôle expert/admin pertinent et entrées invalides. Pour
   les RPC de synchronisation, rejouer exactement la même requête.
5. Documenter l'ordre de déploiement et le comportement des anciennes versions APK.
   En l'absence de serveur de test, livrer le SQL et ses tests en signalant qu'ils
   n'ont pas été exécutés ; ne pas présenter une inspection statique comme un test RLS.

Les clés publiques peuvent être embarquées ; jamais une clé `service_role`.
Ne pas lancer `supabase db push` sans vérifier le projet lié et le périmètre
autorisé. Pour l'enregistrement sans compte, consulter le contrat
`docs/contracts/app-installations.md` et ses limites d'identité.
