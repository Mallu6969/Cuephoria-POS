-- Create default staff user for testing staff login functionality
-- This allows staff members to log in and access the staff portal

-- First, insert the staff user in admin_users (for login)
DO $$
DECLARE
  staff_user_id UUID;
BEGIN
  -- Insert staff user in admin_users table
  INSERT INTO public.admin_users (username, password, is_admin)
  VALUES ('staff_user', 'staff@123', false)
  ON CONFLICT (username) DO UPDATE SET is_admin = false
  RETURNING id INTO staff_user_id;

  -- Create corresponding staff profile if it doesn't exist
  -- Note: Only using fields that exist in the base staff_profiles table
  INSERT INTO public.staff_profiles (
    username,
    full_name,
    role,
    user_id
  )
  SELECT 
    'staff_user',
    'Staff User',
    'staff',
    staff_user_id::TEXT
  WHERE NOT EXISTS (
    SELECT 1 FROM public.staff_profiles WHERE username = 'staff_user'
  );
END $$;

-- Add comment for documentation
COMMENT ON TABLE public.admin_users IS 'Stores admin and staff user accounts. is_admin=true for administrators, is_admin=false for staff members.';

