# Données et sécurité

- Ne pas versionner `.env`, clé privée, keystore ou clé Supabase `service_role`.
  Une clé publique client ne donne pas de privilège administratif ; elle ne remplace
  pas RLS. Ne pas imprimer les valeurs de secrets dans les logs ou rapports.
- Toute table contenant des données utilisateur active RLS et définit explicitement
  les rôles autorisés. Tester un autre utilisateur et l'accès anonyme.
- Une fonction `SECURITY DEFINER` fixe son `search_path`, borne ses entrées et
  possède des permissions d'exécution explicites. Une RPC sans compte n'est pas
  une preuve d'identité physique ; prévoir une protection contre l'abus adaptée.
- Toute nouvelle collecte indique finalité, champs, accès, conservation et suppression
  dans le contrat. Ne pas récupérer nom, téléphone, position ou identifiant matériel
  simplement parce qu'un plugin les expose. Informer l'utilisateur du traitement.
- Ne pas utiliser des photos ou données personnelles de terrain comme fixtures
  versionnées. Employer des exemples synthétiques ou un corpus autorisé séparé.
- Une migration déjà appliquée est immuable : ajouter une migration corrective.
  Distinguer un rollback possible d'une restauration de sauvegarde ; tester avant
  de promettre la réversibilité.
- Les commandes de paiement sont confirmées par le fournisseur et le serveur.
  Le client ne peut pas déclarer un paiement réussi sur simple insertion de commande.

Le contrôle local détecte certains secrets et fichiers dangereux ; il ne constitue
ni un audit de sécurité exhaustif ni une preuve de conformité réglementaire.
