-- Add missing columns to sessions table for coupon and rate tracking
-- These columns are required by the application code but were missing from the schema

ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS original_rate NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS coupon_code TEXT,
ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10, 2);

-- Add comments for documentation
COMMENT ON COLUMN public.sessions.hourly_rate IS 'The hourly rate applied to this session (may include coupon discount)';
COMMENT ON COLUMN public.sessions.original_rate IS 'The original hourly rate before any discounts';
COMMENT ON COLUMN public.sessions.coupon_code IS 'Coupon code applied to this session';
COMMENT ON COLUMN public.sessions.discount_amount IS 'Amount discounted from the original rate';

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_sessions_coupon_code ON public.sessions(coupon_code) WHERE coupon_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_hourly_rate ON public.sessions(hourly_rate);

