-- Update admin user credentials for NerfTurf rebrand
-- Change username from tipntop_admin to Nerfturf_admin and password to Nerfturf@123

UPDATE public.admin_users
SET 
  username = 'Nerfturf_admin',
  password = 'Nerfturf@123'
WHERE username = 'tipntop_admin' OR is_admin = true;

-- If no admin user exists, create one
INSERT INTO public.admin_users (username, password, is_admin)
SELECT 'Nerfturf_admin', 'Nerfturf@123', true
WHERE NOT EXISTS (
  SELECT 1 FROM public.admin_users WHERE is_admin = true
);

