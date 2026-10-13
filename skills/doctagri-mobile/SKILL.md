---
name: doctagri-mobile
description: Modifier une fonctionnalité Flutter de DoctAgri en préservant le diagnostic hors ligne, les données Hive et la séparation data/domain/presentation.
---

# Développer le mobile DoctAgri

Lire `AGENTS.md` et les règles applicables depuis la racine du dépôt.

1. Suivre le parcours existant depuis `lib/core/router/app_router.dart`, puis le
   provider et le repository concernés. Le code actif est dans `lib/`, pas dans
   les packages Melos encore vides.
2. Définir le comportement sans compte et sans réseau. Une fonction distante ne
   bloque pas le diagnostic embarqué. Distinguer attente, échec et résultat local.
3. Garder les nouveaux accès réseau/stockage dans la couche data ou les services.
   Modifier l'injection seulement si nécessaire ; régénérer avec build_runner si
   les annotations changent, plutôt que retoucher seul le fichier généré.
4. Pour Hive, vérifier les adaptateurs et la compatibilité des anciennes données.
   Pour Android natif, vérifier aussi la fermeture de l'interface et le redémarrage
   si la fonctionnalité promet du travail en arrière-plan.
5. Exécuter le test de régression ciblé, puis `python scripts/quality.py flutter`.
   Rapporter séparément une erreur préexistante. Ne pas lancer une refonte générale
   pour résoudre un défaut local.

Pour un changement d'inférence, consulter `skills/doctagri-ml/SKILL.md`.
Pour un changement de contrat distant, consulter `skills/doctagri-supabase/SKILL.md`.
