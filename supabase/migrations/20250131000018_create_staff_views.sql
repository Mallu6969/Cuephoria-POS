-- Create missing views for staff management functionality
-- These views are required by the Staff Management and Staff Portal pages

-- ============================================================================
-- 0. ADD MISSING COLUMNS FIRST (Before creating views that reference them)
-- ============================================================================

-- Add missing columns to STAFF_PROFILES
ALTER TABLE public.staff_profiles
ADD COLUMN IF NOT EXISTS designation TEXT,
ADD COLUMN IF NOT EXISTS monthly_salary NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS shift_start_time TIME,
ADD COLUMN IF NOT EXISTS shift_end_time TIME,
ADD COLUMN IF NOT EXISTS default_shift_hours NUMERIC(5, 2),
ADD COLUMN IF NOT EXISTS joining_date DATE,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add missing columns to STAFF_ATTENDANCE
ALTER TABLE public.staff_attendance
ADD COLUMN IF NOT EXISTS break_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS break_end_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS break_duration_minutes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_working_hours NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS daily_earnings NUMERIC(10, 2);

-- Add missing columns to STAFF_LEAVE_REQUESTS
ALTER TABLE public.staff_leave_requests
ADD COLUMN IF NOT EXISTS leave_type TEXT DEFAULT 'paid_leave',
ADD COLUMN IF NOT EXISTS total_days INTEGER;

-- ============================================================================
-- 1. TODAY_ACTIVE_SHIFTS VIEW
-- Shows all staff members who are currently clocked in (no clock_out time)
-- ============================================================================
DROP VIEW IF EXISTS public.today_active_shifts;
CREATE VIEW public.today_active_shifts AS
SELECT 
  sa.id,
  sa.staff_id,
  sa.date,
  sa.clock_in,
  sa.clock_out,
  sa.status,
  sp.username as staff_name,
  sp.full_name,
  COALESCE(sp.designation, 'Staff') as designation,
  sp.user_id,
  EXTRACT(EPOCH FROM (NOW() - sa.clock_in)) / 3600.0 as hours_so_far,
  sa.break_start_time,
  sa.break_end_time,
  sa.break_duration_minutes
FROM public.staff_attendance sa
INNER JOIN public.staff_profiles sp ON sa.staff_id = sp.id
WHERE sa.date = CURRENT_DATE
  AND sa.clock_out IS NULL
  AND sa.status = 'active'
ORDER BY sa.clock_in ASC;

-- ============================================================================
-- 2. PENDING_LEAVES_VIEW
-- Shows all leave requests that are pending approval
-- ============================================================================
DROP VIEW IF EXISTS public.pending_leaves_view;
CREATE VIEW public.pending_leaves_view AS
SELECT 
  slr.id,
  slr.staff_id,
  slr.start_date,
  slr.end_date,
  slr.reason,
  slr.status,
  slr.remarks,
  slr.created_at,
  sp.username as staff_name,
  sp.full_name,
  COALESCE(sp.designation, 'Staff') as designation,
  (slr.end_date - slr.start_date + 1) as total_days
FROM public.staff_leave_requests slr
INNER JOIN public.staff_profiles sp ON slr.staff_id = sp.id
WHERE slr.status = 'pending'
ORDER BY slr.created_at ASC;

-- ============================================================================
-- 3. STAFF_PAYSLIP_VIEW
-- Shows payslip information for staff members
-- Note: This is a basic view. You may need to add more fields based on your payroll system
-- ============================================================================
DROP VIEW IF EXISTS public.staff_payslip_view;
CREATE VIEW public.staff_payslip_view AS
SELECT 
  sp.id as staff_id,
  sp.username as staff_name,
  sp.full_name,
  COALESCE(sp.designation, 'Staff') as designation,
  -- Placeholder fields - you'll need to create actual payroll tables/calculations
  NULL::INTEGER as month,
  NULL::INTEGER as year,
  NULL::NUMERIC(10, 2) as gross_earnings,
  NULL::NUMERIC(10, 2) as total_allowances,
  NULL::NUMERIC(10, 2) as total_deductions,
  NULL::NUMERIC(10, 2) as net_salary,
  NULL::INTEGER as total_working_days,
  NULL::NUMERIC(10, 2) as total_working_hours,
  NULL::TEXT as payment_status,
  NULL::UUID as payroll_id
FROM public.staff_profiles sp
WHERE 1 = 0; -- Empty view for now - needs actual payroll data

-- ============================================================================
-- 4. MONTHLY_STAFF_SUMMARY VIEW
-- Shows monthly summary statistics for each staff member
-- ============================================================================
DROP VIEW IF EXISTS public.monthly_staff_summary;
CREATE VIEW public.monthly_staff_summary AS
SELECT 
  sp.user_id,
  sp.id as staff_id,
  sp.username as staff_name,
  EXTRACT(MONTH FROM sa.date)::INTEGER as month,
  EXTRACT(YEAR FROM sa.date)::INTEGER as year,
  COUNT(DISTINCT sa.date) as days_worked,
  COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE(sa.clock_out, NOW()) - sa.clock_in)) / 3600.0), 0) as total_hours,
  -- Calculate earnings based on hourly rate (if available)
  COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE(sa.clock_out, NOW()) - sa.clock_in)) / 3600.0) * 
    COALESCE(sp.hourly_rate, 0), 0) as total_earnings
FROM public.staff_profiles sp
LEFT JOIN public.staff_attendance sa ON sa.staff_id = sp.id AND sa.clock_in IS NOT NULL
GROUP BY sp.user_id, sp.id, sp.username, sp.hourly_rate, EXTRACT(MONTH FROM sa.date), EXTRACT(YEAR FROM sa.date);

-- ============================================================================
-- 5. STAFF_BREAK_VIOLATIONS TABLE/VIEW
-- Tracks break time violations (breaks exceeding 60 minutes)
-- Note: staff_id is TEXT to match user_id from staff_profiles
-- ============================================================================
DROP TABLE IF EXISTS public.staff_break_violations;
CREATE TABLE IF NOT EXISTS public.staff_break_violations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id TEXT NOT NULL, -- Matches user_id from staff_profiles
  attendance_id UUID NOT NULL REFERENCES public.staff_attendance(id),
  date DATE NOT NULL,
  break_duration_minutes INTEGER NOT NULL,
  excess_minutes INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_staff_break_violations_staff_id ON public.staff_break_violations(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_break_violations_date ON public.staff_break_violations(date);

-- Enable RLS
ALTER TABLE public.staff_break_violations ENABLE ROW LEVEL SECURITY;

-- Create RLS policy
DROP POLICY IF EXISTS "Allow all operations on staff_break_violations" ON public.staff_break_violations;
CREATE POLICY "Allow all operations on staff_break_violations" ON public.staff_break_violations FOR ALL USING (true);

-- ============================================================================
-- 6. ACTIVE_BREAKS TABLE
-- ============================================================================
-- Note: active_breaks table might be referenced but not created
-- Creating it if needed
CREATE TABLE IF NOT EXISTS public.active_breaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES public.staff_profiles(id),
  attendance_id UUID NOT NULL REFERENCES public.staff_attendance(id),
  break_start TIMESTAMPTZ NOT NULL,
  break_end TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_active_breaks_staff_id ON public.active_breaks(staff_id);
CREATE INDEX IF NOT EXISTS idx_active_breaks_attendance_id ON public.active_breaks(attendance_id);
CREATE INDEX IF NOT EXISTS idx_active_breaks_is_active ON public.active_breaks(is_active);

-- Enable RLS
ALTER TABLE public.active_breaks ENABLE ROW LEVEL SECURITY;

-- Create RLS policy
DROP POLICY IF EXISTS "Allow all operations on active_breaks" ON public.active_breaks;
CREATE POLICY "Allow all operations on active_breaks" ON public.active_breaks FOR ALL USING (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS ON VIEWS
-- ============================================================================
GRANT SELECT ON public.today_active_shifts TO anon, authenticated;
GRANT SELECT ON public.pending_leaves_view TO anon, authenticated;
GRANT SELECT ON public.staff_payslip_view TO anon, authenticated;
GRANT SELECT ON public.monthly_staff_summary TO anon, authenticated;

-- Add comments
COMMENT ON VIEW public.today_active_shifts IS 'Shows all staff members currently clocked in today';
COMMENT ON VIEW public.pending_leaves_view IS 'Shows all pending leave requests awaiting approval';
COMMENT ON VIEW public.staff_payslip_view IS 'Shows payslip information for staff members';
COMMENT ON VIEW public.monthly_staff_summary IS 'Shows monthly summary statistics for each staff member';

