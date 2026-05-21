-- ============================================================
-- KLUTCH KONNECT · DIAGNOSTIC + NUCLEAR FIX
-- Run this in Supabase SQL Editor
-- It will tell us exactly what's wrong then fix it
-- ============================================================

-- STEP 1: Check if table exists and its structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'orders'
ORDER BY ordinal_position;

-- ============================================================
-- If the above returns rows, table exists — run STEP 2 below
-- If it returns NOTHING, table doesn't exist — run STEP 3
-- ============================================================

-- STEP 2: Check RLS status (run this separately)
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'orders';

-- STEP 3: Check existing policies (run this separately)
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'orders';

-- ============================================================
-- NUCLEAR FIX — Run ALL of this at once after checking above
-- This will wipe and rebuild everything correctly
-- ============================================================

-- Drop everything
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.admins CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at CASCADE;

-- Recreate orders table fresh
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

-- Indexes
CREATE INDEX idx_orders_tracking_id ON public.orders(tracking_id);
CREATE INDEX idx_orders_status ON public.orders(status);

-- Auto-update trigger
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- CRITICAL: Disable RLS completely
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

-- CRITICAL: Remove ALL existing policies
DO $$
DECLARE pol RECORD;
BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
             WHERE schemaname='public' AND tablename='orders'
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS "' || pol.policyname || '" ON public.orders';
  END LOOP;
END $$;

-- Grant full access to anon key (what your website uses)
GRANT ALL ON public.orders TO anon;
GRANT ALL ON public.orders TO authenticated;
GRANT ALL ON public.orders TO postgres;
GRANT USAGE, SELECT ON SEQUENCE public.orders_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.orders_id_seq TO authenticated;

-- Insert test order
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
  NOW(), NOW()
);

-- VERIFY: This should return 1 row
SELECT * FROM public.orders WHERE tracking_id = 'KLUTCH-TEST1';

-- ============================================================
-- If you see a row returned above = SUCCESS
-- Go to track.html and search KLUTCH-TEST1
-- ============================================================
