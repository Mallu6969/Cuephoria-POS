-- Add RLS policy for staff_profiles table
-- This allows staff members to access their profiles

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow all operations on staff_profiles" ON public.staff_profiles;

-- Create permissive policy for staff_profiles (allow all operations for 2-user app)
CREATE POLICY "Allow all operations on staff_profiles" ON public.staff_profiles FOR ALL USING (true);

