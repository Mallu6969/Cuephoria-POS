-- Fix RLS policy for admin_users table
-- The table has RLS enabled but no policy, which blocks all queries
-- This migration adds a permissive policy to allow all operations

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow all operations on admin_users" ON public.admin_users;

-- Create permissive policy for admin_users (allow all operations for 2-user app)
CREATE POLICY "Allow all operations on admin_users" ON public.admin_users FOR ALL USING (true);

-- Ensure the default admin user exists
INSERT INTO public.admin_users (username, password, is_admin)
VALUES ('Cuephoria_admin', 'Cuephoria@123', true)
ON CONFLICT (username) DO NOTHING;

