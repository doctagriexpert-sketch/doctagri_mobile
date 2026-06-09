-- ── Fix : aligne le CHECK constraint `orders.payment_method` sur les
-- opérateurs Mobile Money réellement supportés côté app (Togo).
--
-- Avant : ('mtn_money','moov_money','orange_money') — incompatible avec
-- l'enum Dart `PaymentMethod` qui envoie 'mixx_by_yas' (Yas Togocel,
-- ex-Tmoney) ou 'moov_money' (Flooz). Toute commande Mixx By Yas violait
-- la contrainte et l'insert retournait une erreur côté client.
--
-- Après : ('mixx_by_yas','moov_money') — aligné sur `PaymentMethod`.
-- Ajouter ici toute nouvelle méthode supportée (Orange Money CI, etc.).

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_payment_method_check;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN ('mixx_by_yas','moov_money'));
