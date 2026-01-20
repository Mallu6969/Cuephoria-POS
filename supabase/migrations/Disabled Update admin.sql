-- Create subscription table (No RLS needed - only 2 users)
CREATE TABLE IF NOT EXISTS public.subscription (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  subscription_type VARCHAR(20) NOT NULL CHECK (subscription_type IN ('monthly', 'quarterly', 'yearly')),
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE NOT NULL,
  amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0,
  pages_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- No RLS - only 2 users
-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_subscription_end_date ON public.subscription(end_date);
CREATE INDEX IF NOT EXISTS idx_subscription_is_active ON public.subscription(is_active);

-- Insert default subscription (inactive)
INSERT INTO public.subscription (is_active, subscription_type, start_date, end_date, amount_paid, pages_enabled)
VALUES (false, 'monthly', CURRENT_DATE, CURRENT_DATE, 0, false)
ON CONFLICT DO NOTHING;

