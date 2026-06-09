-- ── Migration Phase 3 Polish: Catalogue produits + commandes ──
-- Version: 20260421000000
-- Description: Tables products (catalogue recommandations) + orders (achats mobile money)

-- ══════════════════════════════════════════════════════════════════
-- Table products : catalogue centralisé, référence pour les achats
-- ══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.products (
  sku text PRIMARY KEY,
  name text NOT NULL,
  description text,
  price_xof numeric NOT NULL CHECK (price_xof > 0),
  vendor text,
  disease_label text, -- référence libellé de maladie
  stock int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- ══════════════════════════════════════════════════════════════════
-- Table orders : commandes utilisateur (mobile money simulé)
-- ══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  product_sku text REFERENCES public.products(sku),
  product_name text NOT NULL,
  price_xof numeric NOT NULL,
  quantity int NOT NULL DEFAULT 1 CHECK (quantity > 0),
  phone_number text NOT NULL,
  payment_method text NOT NULL CHECK (payment_method IN ('mtn_money','moov_money','orange_money')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','paid','failed','refunded')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ══════════════════════════════════════════════════════════════════
-- RLS
-- ══════════════════════════════════════════════════════════════════
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products readable by everyone" ON public.products
  FOR SELECT USING (true);

CREATE POLICY "users see own orders" ON public.orders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users create own orders" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════════════
-- Indexes
-- ══════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_products_disease ON public.products(disease_label);

-- ══════════════════════════════════════════════════════════════════
-- Seed : 3 produits démo
-- ══════════════════════════════════════════════════════════════════
INSERT INTO public.products (sku, name, price_xof, vendor, disease_label, stock)
VALUES
  ('DGA-0001','Fongicide cuivrique 500g', 3500, 'DoctAgri Shop', 'mildiou', 100),
  ('DGA-0002','Insecticide bio neem 250ml', 2800, 'DoctAgri Shop', 'pucerons', 80),
  ('DGA-0003','Engrais foliaire NPK 1L', 4500, 'DoctAgri Shop', 'carence', 60)
ON CONFLICT (sku) DO NOTHING;
