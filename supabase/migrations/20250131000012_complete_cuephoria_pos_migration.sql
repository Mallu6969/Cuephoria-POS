-- ============================================================================
-- COMPLETE CUEPHORIA POS MIGRATION
-- This migration creates all tables, functions, triggers, views, and policies
-- for duplicating the POS system into Cuephoria POS
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. CORE TABLES
-- ============================================================================

-- Admin Users Table
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Insert default categories
INSERT INTO public.categories (name)
VALUES 
  ('food'),
  ('drinks'),
  ('tobacco'),
  ('challenges'),
  ('membership')
ON CONFLICT (name) DO NOTHING;

-- Stations Table
CREATE TABLE IF NOT EXISTS public.stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  hourly_rate NUMERIC(10, 2) NOT NULL,
  is_occupied BOOLEAN NOT NULL DEFAULT false,
  is_controller BOOLEAN,
  parent_station_id UUID REFERENCES public.stations(id),
  consolidated_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Products Table
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  price NUMERIC(10, 2) NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  image TEXT,
  buying_price NUMERIC(10, 2),
  selling_price NUMERIC(10, 2),
  profit NUMERIC(10, 2),
  original_price NUMERIC(10, 2),
  offer_price NUMERIC(10, 2),
  student_price NUMERIC(10, 2),
  duration TEXT,
  membership_hours INTEGER,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Customers Table
CREATE TABLE IF NOT EXISTS public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  is_member BOOLEAN NOT NULL DEFAULT false,
  loyalty_points INTEGER NOT NULL DEFAULT 0,
  total_spent NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_play_time INTEGER NOT NULL DEFAULT 0,
  membership_plan TEXT,
  membership_start_date DATE,
  membership_expiry_date DATE,
  membership_duration TEXT,
  membership_hours_left INTEGER,
  membership_seconds_left INTEGER,
  created_via_tournament BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Bills Table
CREATE TABLE IF NOT EXISTS public.bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id),
  subtotal NUMERIC(10, 2) NOT NULL,
  discount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  discount_type TEXT,
  discount_value NUMERIC(10, 2),
  total NUMERIC(10, 2) NOT NULL,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'upi', 'split', 'credit')),
  cash_amount NUMERIC(10, 2),
  upi_amount NUMERIC(10, 2),
  is_split_payment BOOLEAN,
  loyalty_points_earned INTEGER NOT NULL DEFAULT 0,
  loyalty_points_used INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Bill Items Table
CREATE TABLE IF NOT EXISTS public.bill_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
  item_id UUID NOT NULL,
  item_type TEXT NOT NULL,
  name TEXT NOT NULL,
  price NUMERIC(10, 2) NOT NULL,
  quantity INTEGER NOT NULL,
  total NUMERIC(10, 2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Bookings Table
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id),
  station_id UUID NOT NULL REFERENCES public.stations(id),
  booking_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  duration INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'confirmed',
  original_price NUMERIC(10, 2),
  final_price NUMERIC(10, 2),
  discount_percentage NUMERIC(5, 2),
  coupon_code TEXT,
  booking_group_id UUID,
  notes TEXT,
  payment_mode TEXT,
  payment_txn_id TEXT,
  status_updated_at TIMESTAMPTZ,
  status_updated_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Sessions Table
CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID NOT NULL REFERENCES public.stations(id),
  customer_id UUID REFERENCES public.customers(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration INTEGER,
  price NUMERIC(10, 2),
  status TEXT,
  is_paused BOOLEAN DEFAULT false,
  paused_at TIMESTAMPTZ,
  total_paused_time INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Expenses Table
CREATE TABLE IF NOT EXISTS public.expenses (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  category TEXT NOT NULL,
  frequency TEXT NOT NULL,
  date TEXT NOT NULL,
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 2. SUBSCRIPTION & PAYMENT TABLES
-- ============================================================================

-- Subscription Table
CREATE TABLE IF NOT EXISTS public.subscription (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  subscription_type VARCHAR(20) NOT NULL CHECK (subscription_type IN ('monthly', 'quarterly', 'yearly')),
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE NOT NULL,
  amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0,
  pages_enabled BOOLEAN NOT NULL DEFAULT true,
  plan_name VARCHAR(50),
  booking_access BOOLEAN NOT NULL DEFAULT false,
  staff_management_access BOOLEAN NOT NULL DEFAULT false,
  allow_custom_end_date BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Insert default subscription (inactive)
INSERT INTO public.subscription (is_active, subscription_type, start_date, end_date, amount_paid, pages_enabled)
VALUES (false, 'monthly', CURRENT_DATE, CURRENT_DATE, 0, false)
ON CONFLICT DO NOTHING;

-- Pending Payments Table
CREATE TABLE IF NOT EXISTS public.pending_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  razorpay_order_id TEXT NOT NULL UNIQUE,
  razorpay_payment_id TEXT,
  amount NUMERIC(10, 2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'expired')),
  booking_data JSONB NOT NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_email TEXT,
  station_names TEXT[],
  timeslots JSONB,
  failure_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  verified_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 minutes'),
  notes TEXT,
  CONSTRAINT pending_payments_razorpay_order_id_key UNIQUE (razorpay_order_id)
);

-- ============================================================================
-- 3. CASH MANAGEMENT TABLES
-- ============================================================================

-- Cash Vault Table
CREATE TABLE IF NOT EXISTS public.cash_vault (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  current_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_by TEXT NOT NULL
);

-- Cash Vault Transactions Table
CREATE TABLE IF NOT EXISTS public.cash_vault_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_type TEXT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  person_name TEXT NOT NULL,
  transaction_number TEXT,
  notes TEXT,
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  created_by TEXT NOT NULL
);

-- Cash Bank Deposits Table
CREATE TABLE IF NOT EXISTS public.cash_bank_deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deposit_date DATE NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  person_name TEXT NOT NULL,
  transaction_number TEXT NOT NULL,
  notes TEXT,
  remarks TEXT,
  created_by TEXT NOT NULL
);

-- Cash Deposits Table
CREATE TABLE IF NOT EXISTS public.cash_deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deposit_date DATE NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  bank_name TEXT,
  reference_number TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  created_by TEXT NOT NULL
);

-- Cash Transactions Table
CREATE TABLE IF NOT EXISTS public.cash_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_type TEXT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  bill_id UUID REFERENCES public.bills(id),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  created_by TEXT NOT NULL
);

-- Cash Summary Table
CREATE TABLE IF NOT EXISTS public.cash_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL UNIQUE,
  opening_balance NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_sales NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_deposits NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_withdrawals NUMERIC(10, 2) NOT NULL DEFAULT 0,
  closing_balance NUMERIC(10, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================================
-- 4. TOURNAMENT TABLES
-- ============================================================================

-- Tournaments Table
CREATE TABLE IF NOT EXISTS public.tournaments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  game_type VARCHAR(50) NOT NULL,
  game_variant VARCHAR(50),
  game_title VARCHAR(255),
  date VARCHAR(50) NOT NULL,
  players JSONB DEFAULT '[]'::jsonb NOT NULL,
  matches JSONB DEFAULT '[]'::jsonb NOT NULL,
  status VARCHAR(20) NOT NULL,
  budget NUMERIC,
  winner_prize NUMERIC,
  runner_up_prize NUMERIC,
  winner JSONB,
  runner_up JSONB,
  max_players INTEGER DEFAULT 16,
  tournament_format VARCHAR(20) NOT NULL DEFAULT 'knockout' CHECK (tournament_format IN ('knockout', 'league')),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Tournament History Table
CREATE TABLE IF NOT EXISTS public.tournament_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  match_id TEXT NOT NULL,
  player1_name TEXT NOT NULL,
  player2_name TEXT NOT NULL,
  winner_name TEXT NOT NULL,
  match_date DATE NOT NULL,
  match_stage TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Tournament Winners Table
CREATE TABLE IF NOT EXISTS public.tournament_winners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  tournament_name TEXT NOT NULL,
  winner_name TEXT NOT NULL,
  runner_up_name TEXT,
  tournament_date DATE NOT NULL,
  game_type TEXT NOT NULL,
  game_variant TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Tournament Public Registrations Table
CREATE TABLE IF NOT EXISTS public.tournament_public_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_email TEXT,
  entry_fee NUMERIC(10, 2),
  registration_date DATE NOT NULL DEFAULT CURRENT_DATE,
  registration_source TEXT,
  status TEXT NOT NULL DEFAULT 'registered',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Tournament Registrations Table (Legacy)
CREATE TABLE IF NOT EXISTS public.tournament_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_email TEXT,
  entry_fee NUMERIC(10, 2),
  registration_date DATE,
  registration_source TEXT,
  status TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Tournament Winner Images Table
CREATE TABLE IF NOT EXISTS public.tournament_winner_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  winner_name TEXT,
  caption TEXT,
  created_by TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 5. LOYALTY & REWARDS TABLES
-- ============================================================================

-- Loyalty Transactions Table
CREATE TABLE IF NOT EXISTS public.loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id),
  points INTEGER NOT NULL,
  source TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Rewards Table
CREATE TABLE IF NOT EXISTS public.rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  points_cost INTEGER NOT NULL,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Reward Redemptions Table
CREATE TABLE IF NOT EXISTS public.reward_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id),
  reward_id UUID NOT NULL REFERENCES public.rewards(id),
  points_spent INTEGER NOT NULL,
  redemption_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  staff_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  redeemed_at TIMESTAMPTZ
);

-- Referrals Table
CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES public.customers(id),
  referred_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  points_awarded INTEGER,
  created_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- ============================================================================
-- 6. STAFF MANAGEMENT TABLES
-- ============================================================================

-- Staff Profiles Table
CREATE TABLE IF NOT EXISTS public.staff_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  role TEXT,
  photo_url TEXT,
  user_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Staff Attendance Table
CREATE TABLE IF NOT EXISTS public.staff_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES public.staff_profiles(id),
  date DATE NOT NULL,
  clock_in TIMESTAMPTZ,
  clock_out TIMESTAMPTZ,
  duration_minutes INTEGER,
  status TEXT NOT NULL DEFAULT 'present',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Staff Leave Requests Table
CREATE TABLE IF NOT EXISTS public.staff_leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES public.staff_profiles(id),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  remarks TEXT,
  created_by TEXT,
  reviewed_by TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Staff Work Schedules Table
CREATE TABLE IF NOT EXISTS public.staff_work_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES public.staff_profiles(id),
  weekday INTEGER NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================================
-- 7. MARKETING & PROMOTIONS TABLES
-- ============================================================================

-- Promotions Table
CREATE TABLE IF NOT EXISTS public.promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL,
  discount_value NUMERIC(10, 2) NOT NULL,
  start_date DATE,
  end_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Offers Table
CREATE TABLE IF NOT EXISTS public.offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  discount_type TEXT CHECK (discount_type IN ('percentage', 'fixed', 'bogo', 'free_item')) DEFAULT 'percentage',
  discount_value NUMERIC,
  validity_days INTEGER DEFAULT 7,
  is_active BOOLEAN DEFAULT true,
  target_audience TEXT CHECK (target_audience IN ('all', 'members', 'non_members', 'new_customers', 'vip')) DEFAULT 'all',
  min_spend NUMERIC DEFAULT 0,
  max_uses INTEGER,
  current_uses INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================================================
-- 8. NOTIFICATION & COMMUNICATION TABLES
-- ============================================================================

-- Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB,
  is_read BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Notification Templates Table
CREATE TABLE IF NOT EXISTS public.notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  title_template TEXT NOT NULL,
  message_template TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Email Templates Table
CREATE TABLE IF NOT EXISTS public.email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  subject_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================================
-- 9. BOOKING VIEWS & ACCESS TABLES
-- ============================================================================

-- Booking Views Table
CREATE TABLE IF NOT EXISTS public.booking_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  access_code TEXT NOT NULL UNIQUE,
  last_accessed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Customer Users Table
CREATE TABLE IF NOT EXISTS public.customer_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id),
  email TEXT NOT NULL UNIQUE,
  pin TEXT,
  auth_id TEXT,
  referral_code TEXT,
  reset_pin TEXT,
  reset_pin_expiry TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 10. INVESTMENT & PARTNERSHIP TABLES
-- ============================================================================

-- Investment Partners Table
CREATE TABLE IF NOT EXISTS public.investment_partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  partnership_type TEXT NOT NULL,
  investment_amount NUMERIC(10, 2) NOT NULL,
  investment_date DATE NOT NULL,
  initial_investment_amount NUMERIC(10, 2),
  equity_percentage NUMERIC(5, 2),
  status TEXT NOT NULL,
  contact_person TEXT,
  company TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Investment Transactions Table
CREATE TABLE IF NOT EXISTS public.investment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.investment_partners(id),
  transaction_type TEXT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  transaction_date DATE NOT NULL,
  status TEXT NOT NULL,
  description TEXT,
  reference_number TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================================
-- 11. USER PREFERENCES TABLE
-- ============================================================================

-- User Preferences Table
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL UNIQUE,
  theme TEXT NOT NULL DEFAULT 'light',
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  email_notifications BOOLEAN NOT NULL DEFAULT true,
  default_timeout INTEGER NOT NULL DEFAULT 30,
  receipt_template TEXT NOT NULL DEFAULT 'default',
  how_to_use_dismissed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================================
-- 12. INDEXES FOR PERFORMANCE
-- ============================================================================

-- Bookings Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_station_date_status 
ON public.bookings(station_id, booking_date, status)
WHERE status IN ('confirmed', 'in-progress');

CREATE INDEX IF NOT EXISTS idx_bookings_station_date_time 
ON public.bookings(station_id, booking_date, start_time, end_time)
WHERE status IN ('confirmed', 'in-progress');

CREATE INDEX IF NOT EXISTS idx_bookings_payment_txn_id ON public.bookings(payment_txn_id);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_mode ON public.bookings(payment_mode);
CREATE INDEX IF NOT EXISTS idx_bookings_customer_id ON public.bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_date ON public.bookings(booking_date);

-- Pending Payments Indexes
CREATE INDEX IF NOT EXISTS idx_pending_payments_status ON public.pending_payments(status);
CREATE INDEX IF NOT EXISTS idx_pending_payments_razorpay_order_id ON public.pending_payments(razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_pending_payments_razorpay_payment_id ON public.pending_payments(razorpay_payment_id) WHERE razorpay_payment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pending_payments_created_at ON public.pending_payments(created_at);
CREATE INDEX IF NOT EXISTS idx_pending_payments_expires_at ON public.pending_payments(expires_at);

-- Subscription Indexes
CREATE INDEX IF NOT EXISTS idx_subscription_end_date ON public.subscription(end_date);
CREATE INDEX IF NOT EXISTS idx_subscription_is_active ON public.subscription(is_active);

-- Tournament Indexes
CREATE INDEX IF NOT EXISTS idx_tournament_history_tournament_id ON public.tournament_history(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_history_match_date ON public.tournament_history(match_date);
CREATE INDEX IF NOT EXISTS idx_tournament_winners_winner_name ON public.tournament_winners(winner_name);
CREATE INDEX IF NOT EXISTS idx_tournament_winners_tournament_date ON public.tournament_winners(tournament_date);

-- Customer Indexes
CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON public.customers(email) WHERE email IS NOT NULL;

-- Sessions Indexes
CREATE INDEX IF NOT EXISTS idx_sessions_station_id ON public.sessions(station_id);
CREATE INDEX IF NOT EXISTS idx_sessions_customer_id ON public.sessions(customer_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON public.sessions(start_time);

-- ============================================================================
-- 13. FUNCTIONS
-- ============================================================================

-- Get Available Slots Function
CREATE OR REPLACE FUNCTION public.get_available_slots(
  p_date date, 
  p_station_id uuid, 
  p_slot_duration integer DEFAULT 60
)
RETURNS TABLE(start_time time without time zone, end_time time without time zone, is_available boolean)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  opening_time TIME := '11:00:00';
  closing_time TIME := '23:59:59';
  total_minutes INTEGER;
  slot_count INTEGER;
BEGIN
  total_minutes := EXTRACT(EPOCH FROM (closing_time - opening_time))::INTEGER / 60;
  slot_count := (total_minutes / p_slot_duration) + CASE WHEN total_minutes % p_slot_duration > 0 THEN 1 ELSE 0 END;
  
  RETURN QUERY
  WITH slot_times AS (
    SELECT 
      (opening_time + (n * p_slot_duration || ' minutes')::interval)::TIME AS slot_start,
      LEAST(
        (opening_time + ((n + 1) * p_slot_duration || ' minutes')::interval)::TIME,
        closing_time
      ) AS slot_end
    FROM generate_series(0, slot_count - 1) AS n
    WHERE (opening_time + (n * p_slot_duration || ' minutes')::interval)::TIME < closing_time
  ),
  active_bookings AS (
    SELECT b.start_time, b.end_time
    FROM public.bookings b
    WHERE b.station_id = p_station_id 
      AND b.booking_date = p_date
      AND b.status IN ('confirmed', 'in-progress')
  ),
  active_session AS (
    SELECT s.start_time::TIME AS session_start
    FROM public.sessions s
    WHERE p_date = CURRENT_DATE
      AND s.station_id = p_station_id
      AND s.end_time IS NULL
      AND DATE(s.start_time) = p_date
    LIMIT 1
  )
  SELECT 
    st.slot_start AS start_time,
    st.slot_end AS end_time,
    NOT EXISTS (
      SELECT 1
      FROM active_bookings ab
      WHERE (
        (ab.start_time <= st.slot_start AND ab.end_time > st.slot_start) OR
        (ab.start_time < st.slot_end AND ab.end_time >= st.slot_end) OR
        (ab.start_time >= st.slot_start AND ab.end_time <= st.slot_end) OR
        (ab.start_time <= st.slot_start AND ab.end_time >= st.slot_end)
      )
    ) AND NOT (
      p_date = CURRENT_DATE 
      AND EXISTS (SELECT 1 FROM active_session)
      AND CURRENT_TIME >= st.slot_start 
      AND CURRENT_TIME < st.slot_end
    ) AS is_available
  FROM slot_times st
  ORDER BY st.slot_start;
END;
$$;

-- Check Booking Overlap Function
CREATE OR REPLACE FUNCTION public.check_booking_overlap(
  p_station_id UUID,
  p_booking_date DATE,
  p_start_time TIME,
  p_end_time TIME,
  p_exclude_booking_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  has_overlap BOOLEAN;
  p_end_normalized TIME;
BEGIN
  p_end_normalized := CASE 
    WHEN p_end_time = '00:00:00'::TIME THEN '23:59:59'::TIME
    ELSE p_end_time
  END;
  
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.station_id = p_station_id
      AND b.booking_date = p_booking_date
      AND b.status IN ('confirmed', 'in-progress')
      AND (p_exclude_booking_id IS NULL OR b.id != p_exclude_booking_id)
      AND (
        (b.start_time <= p_start_time AND 
         (CASE WHEN b.end_time = '00:00:00'::TIME THEN '23:59:59'::TIME ELSE b.end_time END) > p_start_time) OR
        (b.start_time < p_end_normalized AND 
         (CASE WHEN b.end_time = '00:00:00'::TIME THEN '23:59:59'::TIME ELSE b.end_time END) >= p_end_normalized) OR
        (b.start_time >= p_start_time AND 
         (CASE WHEN b.end_time = '00:00:00'::TIME THEN '23:59:59'::TIME ELSE b.end_time END) <= p_end_normalized) OR
        (b.start_time <= p_start_time AND 
         (CASE WHEN b.end_time = '00:00:00'::TIME THEN '23:59:59'::TIME ELSE b.end_time END) >= p_end_normalized)
      )
    LIMIT 1
  ) INTO has_overlap;
  
  RETURN has_overlap;
END;
$$;

-- Check Stations Availability Function
CREATE OR REPLACE FUNCTION public.check_stations_availability(
  p_date date, 
  p_start_time time without time zone, 
  p_end_time time without time zone, 
  p_station_ids uuid[]
)
RETURNS TABLE(station_id uuid, is_available boolean)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH booking_conflicts AS (
    SELECT b.station_id
    FROM public.bookings b
    WHERE b.booking_date = p_date
      AND b.status IN ('confirmed', 'in-progress')
      AND b.station_id = ANY(p_station_ids)
      AND (
        (b.start_time <= p_start_time AND b.end_time > p_start_time) OR
        (b.start_time < p_end_time AND b.end_time >= p_end_time) OR
        (b.start_time >= p_start_time AND b.end_time <= p_end_time) OR
        (b.start_time <= p_start_time AND b.end_time >= p_end_time)
      )
  ),
  session_conflicts AS (
    SELECT s.station_id
    FROM public.sessions s
    WHERE s.end_time IS NULL
      AND DATE(s.start_time) = p_date
      AND s.station_id = ANY(p_station_ids)
  )
  SELECT 
    s.id AS station_id,
    NOT EXISTS (
      SELECT 1 FROM booking_conflicts bc WHERE bc.station_id = s.id
    ) AND NOT EXISTS (
      SELECT 1 FROM session_conflicts sc WHERE sc.station_id = s.id
    ) AS is_available
  FROM unnest(p_station_ids) AS s(id);
END;
$$;

-- Get Booking Conflicts Function
CREATE OR REPLACE FUNCTION public.get_booking_conflicts(
  p_station_id UUID,
  p_booking_date DATE,
  p_start_time TIME,
  p_end_time TIME,
  p_exclude_booking_id UUID DEFAULT NULL
)
RETURNS TABLE(
  booking_id UUID,
  booking_date DATE,
  start_time TIME,
  end_time TIME,
  status TEXT,
  station_name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.booking_date,
    b.start_time,
    b.end_time,
    b.status::TEXT,
    s.name,
    b.created_at
  FROM public.bookings b
  INNER JOIN public.stations s ON s.id = b.station_id
  WHERE b.station_id = p_station_id
    AND b.booking_date = p_booking_date
    AND b.status IN ('confirmed', 'in-progress')
    AND (p_exclude_booking_id IS NULL OR b.id != p_exclude_booking_id)
    AND (
      (b.start_time <= p_start_time AND (b.end_time > p_start_time OR b.end_time = '00:00:00'::TIME)) OR
      (b.start_time < p_end_time AND (b.end_time >= p_end_time OR (b.end_time = '00:00:00'::TIME AND p_end_time = '00:00:00'::TIME))) OR
      (b.start_time >= p_start_time AND (b.end_time <= p_end_time OR (b.end_time = '00:00:00'::TIME AND p_end_time = '00:00:00'::TIME))) OR
      (b.start_time <= p_start_time AND (b.end_time >= p_end_time OR b.end_time = '00:00:00'::TIME))
    )
  ORDER BY b.created_at DESC;
END;
$$;

-- Check Booking Overlap With Details Function
CREATE OR REPLACE FUNCTION public.check_booking_overlap_with_details(
  p_station_id UUID,
  p_booking_date DATE,
  p_start_time TIME,
  p_end_time TIME,
  p_exclude_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  has_overlap BOOLEAN;
  conflict_details JSONB;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.station_id = p_station_id
      AND b.booking_date = p_booking_date
      AND b.status IN ('confirmed', 'in-progress')
      AND (p_exclude_booking_id IS NULL OR b.id != p_exclude_booking_id)
      AND (
        (b.start_time <= p_start_time AND (
          (b.end_time > p_start_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME)
        )) OR
        (b.start_time < p_end_time AND (
          (b.end_time >= p_end_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time = '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time != '00:00:00'::TIME)
        )) OR
        (b.start_time >= p_start_time AND (
          (b.end_time <= p_end_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time = '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time != '00:00:00'::TIME)
        )) OR
        (b.start_time <= p_start_time AND (
          (b.end_time >= p_end_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME)
        ))
      )
  ) INTO has_overlap;

  IF has_overlap THEN
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'booking_date', b.booking_date,
        'start_time', b.start_time,
        'end_time', b.end_time,
        'status', b.status,
        'station_name', s.name,
        'created_at', b.created_at
      )
    )
    INTO conflict_details
    FROM public.bookings b
    INNER JOIN public.stations s ON s.id = b.station_id
    WHERE b.station_id = p_station_id
      AND b.booking_date = p_booking_date
      AND b.status IN ('confirmed', 'in-progress')
      AND (p_exclude_booking_id IS NULL OR b.id != p_exclude_booking_id)
      AND (
        (b.start_time <= p_start_time AND (
          (b.end_time > p_start_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME)
        )) OR
        (b.start_time < p_end_time AND (
          (b.end_time >= p_end_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time = '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time != '00:00:00'::TIME)
        )) OR
        (b.start_time >= p_start_time AND (
          (b.end_time <= p_end_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time = '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME AND p_end_time != '00:00:00'::TIME)
        )) OR
        (b.start_time <= p_start_time AND (
          (b.end_time >= p_end_time AND b.end_time != '00:00:00'::TIME) OR
          (b.end_time = '00:00:00'::TIME)
        ))
      );
  END IF;

  RETURN jsonb_build_object(
    'has_overlap', has_overlap,
    'conflicts', COALESCE(conflict_details, '[]'::jsonb)
  );
END;
$$;

-- Generate Booking Access Code Function
CREATE OR REPLACE FUNCTION public.generate_booking_access_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  access_code TEXT;
BEGIN
  access_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 8));
  RETURN access_code;
END;
$$;

-- Save Bill Edit Audit Function
CREATE OR REPLACE FUNCTION public.save_bill_edit_audit(
  p_bill_id UUID,
  p_editor_name TEXT,
  p_changes TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  -- This function can be extended to log bill edits
  -- For now, it's a placeholder
  NULL;
END;
$$;

-- Update Missed Bookings Function
CREATE OR REPLACE FUNCTION public.update_missed_bookings()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.bookings
  SET status = 'missed'
  WHERE status = 'confirmed'
    AND booking_date < CURRENT_DATE
    AND (booking_date || ' ' || start_time)::TIMESTAMP < NOW();
END;
$$;

-- ============================================================================
-- 14. TRIGGERS
-- ============================================================================

-- Validate Booking No Overlap Trigger Function
CREATE OR REPLACE FUNCTION public.validate_booking_no_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  has_overlap BOOLEAN;
BEGIN
  IF NEW.status IN ('confirmed', 'in-progress') THEN
    SELECT public.check_booking_overlap(
      NEW.station_id,
      NEW.booking_date,
      NEW.start_time,
      NEW.end_time,
      CASE WHEN TG_OP = 'UPDATE' THEN OLD.id ELSE NULL END
    ) INTO has_overlap;
    
    IF has_overlap THEN
      RAISE EXCEPTION 'Booking conflict: Another booking already exists for station % at % from % to %',
        NEW.station_id,
        NEW.booking_date,
        NEW.start_time,
        NEW.end_time
      USING ERRCODE = '23505';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Prevent Duplicate Bookings Trigger
DROP TRIGGER IF EXISTS prevent_duplicate_bookings_trigger ON public.bookings;
CREATE TRIGGER prevent_duplicate_bookings_trigger
  BEFORE INSERT OR UPDATE ON public.bookings
  FOR EACH ROW
  WHEN (NEW.status IN ('confirmed', 'in-progress'))
  EXECUTE FUNCTION public.validate_booking_no_overlap();

-- ============================================================================
-- 15. VIEWS
-- ============================================================================

-- Tournament Public View
DROP VIEW IF EXISTS public.tournament_public_view;
CREATE VIEW public.tournament_public_view AS
SELECT 
  t.id,
  t.name,
  t.game_type,
  t.game_variant,
  t.game_title,
  t.date,
  t.status,
  t.budget,
  t.winner_prize,
  t.runner_up_prize,
  t.players,
  t.matches,
  t.winner,
  t.runner_up,
  COALESCE(reg_count.total_registrations, 0) as total_registrations,
  COALESCE(t.max_players, 
    CASE 
      WHEN t.game_type = 'Pool' THEN 8
      WHEN t.game_type = 'PS5' THEN 16
      ELSE 16
    END
  ) as max_players
FROM tournaments t
LEFT JOIN (
  SELECT 
    tournament_id,
    COUNT(*) as total_registrations
  FROM tournament_public_registrations 
  WHERE status = 'registered'
  GROUP BY tournament_id
) reg_count ON t.id = reg_count.tournament_id
WHERE t.status IN ('upcoming', 'in-progress', 'completed')
ORDER BY 
  CASE 
    WHEN t.status = 'upcoming' THEN 1
    WHEN t.status = 'in-progress' THEN 2
    WHEN t.status = 'completed' THEN 3
  END,
  t.date ASC;

-- Tournament Stats View
DROP VIEW IF EXISTS public.tournament_stats;
CREATE VIEW public.tournament_stats AS
SELECT 
  t.id,
  t.name,
  t.game_type,
  t.game_variant,
  t.game_title,
  t.date,
  t.status,
  t.budget,
  t.winner_prize,
  t.runner_up_prize,
  t.players,
  t.matches,
  t.winner,
  COALESCE(reg_count.total_registrations, 0) as total_registrations,
  t.max_players
FROM tournaments t
LEFT JOIN (
  SELECT 
    tournament_id,
    COUNT(*) as total_registrations
  FROM tournament_public_registrations 
  WHERE status = 'registered'
  GROUP BY tournament_id
) reg_count ON t.id = reg_count.tournament_id;

-- ============================================================================
-- 16. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_vault ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_vault_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_bank_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_winners DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_public_registrations DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_registrations DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_winner_images DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_work_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Create permissive policies (allow all operations for 2-user app)
DO $$
BEGIN
  -- Core tables
  DROP POLICY IF EXISTS "Allow all operations on categories" ON public.categories;
  CREATE POLICY "Allow all operations on categories" ON public.categories FOR ALL USING (true);
  
  DROP POLICY IF EXISTS "Allow all operations on cash_vault" ON public.cash_vault;
  CREATE POLICY "Allow all operations on cash_vault" ON public.cash_vault FOR ALL USING (true);
  
  DROP POLICY IF EXISTS "Allow all operations on cash_bank_deposits" ON public.cash_bank_deposits;
  CREATE POLICY "Allow all operations on cash_bank_deposits" ON public.cash_bank_deposits FOR ALL USING (true);
  
  DROP POLICY IF EXISTS "Allow all operations on sessions" ON public.sessions;
  CREATE POLICY "Allow all operations on sessions" ON public.sessions FOR ALL USING (true);
  
  DROP POLICY IF EXISTS "Allow all operations on expenses" ON public.expenses;
  CREATE POLICY "Allow all operations on expenses" ON public.expenses FOR ALL USING (true);
  
  DROP POLICY IF EXISTS "Allow all operations on cash_vault_transactions" ON public.cash_vault_transactions;
  CREATE POLICY "Allow all operations on cash_vault_transactions" ON public.cash_vault_transactions FOR ALL USING (true);
  
  DROP POLICY IF EXISTS "Allow all operations on cash_summary" ON public.cash_summary;
  CREATE POLICY "Allow all operations on cash_summary" ON public.cash_summary FOR ALL USING (true);
  
  -- Offers
  DROP POLICY IF EXISTS "Allow read access for offers" ON public.offers;
  CREATE POLICY "Allow read access for offers" ON public.offers FOR SELECT USING (true);
  
  DROP POLICY IF EXISTS "Allow full access for authenticated users on offers" ON public.offers;
  CREATE POLICY "Allow full access for authenticated users on offers" ON public.offers FOR ALL USING (true);
END $$;

-- ============================================================================
-- 17. STORAGE BUCKETS
-- ============================================================================

-- Create storage bucket for expense receipts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'expense-receipts',
  'expense-receipts',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for expense receipts
DO $$
BEGIN
  DROP POLICY IF EXISTS "Allow all to upload expense receipts" ON storage.objects;
  CREATE POLICY "Allow all to upload expense receipts"
  ON storage.objects FOR INSERT
  TO public
  WITH CHECK (bucket_id = 'expense-receipts');

  DROP POLICY IF EXISTS "Allow all to update expense receipts" ON storage.objects;
  CREATE POLICY "Allow all to update expense receipts"
  ON storage.objects FOR UPDATE
  TO public
  USING (bucket_id = 'expense-receipts')
  WITH CHECK (bucket_id = 'expense-receipts');

  DROP POLICY IF EXISTS "Allow all to delete expense receipts" ON storage.objects;
  CREATE POLICY "Allow all to delete expense receipts"
  ON storage.objects FOR DELETE
  TO public
  USING (bucket_id = 'expense-receipts');

  DROP POLICY IF EXISTS "Allow all to read expense receipts" ON storage.objects;
  CREATE POLICY "Allow all to read expense receipts"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'expense-receipts');
END $$;

-- ============================================================================
-- 18. REALTIME REPLICATION
-- ============================================================================

-- Enable realtime replication for bookings table
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;

-- ============================================================================
-- 19. COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.pending_payments IS 'Stores payment intents for reconciliation. Payments are verified against Razorpay API to create bookings even if customer doesnt return to browser.';
COMMENT ON COLUMN public.pending_payments.status IS 'Payment status: pending (awaiting payment), success (payment verified), failed (payment failed), expired (payment expired)';
COMMENT ON COLUMN public.pending_payments.station_names IS 'Array of station names being booked (for display purposes)';
COMMENT ON COLUMN public.pending_payments.timeslots IS 'JSONB array of timeslot objects with start_time and end_time (for display purposes)';
COMMENT ON COLUMN public.pending_payments.failure_reason IS 'Reason for payment/booking failure (populated when status is failed)';
COMMENT ON COLUMN public.expenses.photo_url IS 'URL of the photo/receipt uploaded for this expense';
COMMENT ON COLUMN public.bookings.payment_mode IS 'Payment method: razorpay, venue, cash, upi, etc.';
COMMENT ON COLUMN public.bookings.payment_txn_id IS 'Transaction ID from payment gateway (e.g., Razorpay payment ID)';
COMMENT ON FUNCTION public.get_available_slots IS 'Returns available time slots for a station on a given date. Slots end at 23:59:59. PERFORMANCE OPTIMIZED: Uses single query with CTEs instead of loops.';
COMMENT ON FUNCTION public.check_booking_overlap IS 'Checks if a booking time slot overlaps with existing confirmed/in-progress bookings. Handles both old bookings (00:00:00) and new slots (23:59:59) for backward compatibility.';
COMMENT ON FUNCTION public.check_stations_availability IS 'Checks availability of multiple stations for a given date and time range';
COMMENT ON FUNCTION public.get_booking_conflicts IS 'Returns details of bookings that conflict with the given time slot';
COMMENT ON FUNCTION public.check_booking_overlap_with_details IS 'Enhanced version of check_booking_overlap that returns conflict details';
COMMENT ON TRIGGER prevent_duplicate_bookings_trigger ON public.bookings IS 'Prevents duplicate/overlapping bookings at the database level';
COMMENT ON VIEW public.tournament_public_view IS 'Public view of tournaments with registration counts for public website';

-- ============================================================================
-- 20. DEFAULT DATA
-- ============================================================================

-- Create default admin user for Cuephoria POS
INSERT INTO public.admin_users (username, password, is_admin)
VALUES ('Cuephoria_admin', 'Cuephoria@123', true)
ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- 
-- This migration creates a complete duplicate of the POS system for Cuephoria POS.
-- All tables, functions, triggers, views, indexes, and policies have been created.
-- 
-- Default admin credentials:
-- Username: Cuephoria_admin
-- Password: Cuephoria@123
-- 
-- Note: Change the default password after first login for security.
-- ============================================================================

