-- ============================================================
-- KLUTCH KONNECT · DROPSEX TRACKING — SUPABASE SETUP v6
-- Run this ENTIRE script in Supabase SQL Editor
-- Dashboard → SQL Editor → New Query → Paste → RUN
-- ============================================================

-- STEP 1: Drop old tables and start clean
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.admins CASCADE;

-- STEP 2: Create orders table with ALL required columns
CREATE TABLE public.orders (
  id                BIGSERIAL PRIMARY KEY,
  tracking_id       TEXT UNIQUE NOT NULL,
  customer_name     TEXT NOT NULL,
  phone             TEXT,
  product           TEXT NOT NULL,
  delivery_address  TEXT NOT NULL,
  eta               TEXT,
  status            TEXT NOT NULL DEFAULT 'confirmed'
                    CHECK (status IN ('confirmed','processing','dispatched','delivered','cancelled')),
  confirmed_at      TIMESTAMPTZ,
  processing_at     TIMESTAMPTZ,
  dispatched_at     TIMESTAMPTZ,
  delivered_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- STEP 3: Indexes for fast lookups
CREATE INDEX idx_orders_tracking_id ON public.orders(tracking_id);
CREATE INDEX idx_orders_status ON public.orders(status);

-- STEP 4: Auto-update updated_at on every change
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_updated_at ON public.orders;
CREATE TRIGGER trigger_update_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- STEP 5: DISABLE RLS — your admin panel uses the anon key directly
-- (no Supabase Auth login, so auth.uid() is always NULL)
-- Security is handled by keeping admin.html URL private
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

-- STEP 6: Grant full access to anon key
GRANT ALL ON public.orders TO anon;
GRANT ALL ON public.orders TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.orders_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.orders_id_seq TO authenticated;

-- STEP 7: Insert a test order to verify everything works
INSERT INTO public.orders (
  tracking_id, customer_name, phone, product,
  delivery_address, status, confirmed_at, updated_at
) VALUES (
  'KLUTCH-TEST1',
  'Test Customer',
  '+2348127140217',
  'Smoky Roasted Catfish (900g)',
  'Opposite 18 Eckankar Drive, Jakande Estate, Isolo Lagos',
  'processing',
  NOW(),
  NOW()
);

-- ============================================================
-- VERIFY: Run this after to confirm it worked:
-- SELECT * FROM public.orders WHERE tracking_id = 'KLUTCH-TEST1';
-- Then go to track.html and search: KLUTCH-TEST1
-- ============================================================
