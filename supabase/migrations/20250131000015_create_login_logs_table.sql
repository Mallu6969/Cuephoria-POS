-- Create login_logs table for tracking login attempts
-- This table stores comprehensive login metadata for security auditing

CREATE TABLE IF NOT EXISTS public.login_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  login_success BOOLEAN NOT NULL DEFAULT false,
  ip_address TEXT,
  city TEXT,
  region TEXT,
  country TEXT,
  timezone TEXT,
  isp TEXT,
  browser TEXT,
  browser_version TEXT,
  os TEXT,
  os_version TEXT,
  device_type TEXT,
  device_model TEXT,
  device_vendor TEXT,
  user_agent TEXT,
  latitude NUMERIC(10, 8),
  longitude NUMERIC(11, 8),
  location_accuracy NUMERIC(10, 2),
  selfie_url TEXT,
  screen_resolution TEXT,
  color_depth INTEGER,
  pixel_ratio NUMERIC(5, 2),
  cpu_cores INTEGER,
  device_memory NUMERIC(10, 2),
  touch_support BOOLEAN,
  connection_type TEXT,
  battery_level NUMERIC(5, 2),
  canvas_fingerprint TEXT,
  installed_fonts TEXT,
  login_time TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_login_logs_username ON public.login_logs(username);
CREATE INDEX IF NOT EXISTS idx_login_logs_login_success ON public.login_logs(login_success);
CREATE INDEX IF NOT EXISTS idx_login_logs_login_time ON public.login_logs(login_time DESC);
CREATE INDEX IF NOT EXISTS idx_login_logs_is_admin ON public.login_logs(is_admin);

-- Enable RLS
ALTER TABLE public.login_logs ENABLE ROW LEVEL SECURITY;

-- Create permissive policy (allow all operations for 2-user app)
DROP POLICY IF EXISTS "Allow all operations on login_logs" ON public.login_logs;
CREATE POLICY "Allow all operations on login_logs" ON public.login_logs FOR ALL USING (true);

-- Add comments for documentation
COMMENT ON TABLE public.login_logs IS 'Stores comprehensive login attempt logs with metadata for security auditing';
COMMENT ON COLUMN public.login_logs.login_success IS 'Whether the login attempt was successful';
COMMENT ON COLUMN public.login_logs.login_time IS 'Timestamp when the login attempt occurred';

