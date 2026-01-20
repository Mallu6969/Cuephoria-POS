import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { supabase } from "@/integrations/supabase/client";
import type { Database } from '@/integrations/supabase/types';
import { toast } from 'sonner';

interface AdminUser {
  id: string;
  username: string;
  isAdmin: boolean;
}

interface LoginMetadata {
  ip?: string;
  city?: string;
  region?: string;
  country?: string;
  timezone?: string;
  isp?: string;
  browser?: string;
  browserVersion?: string;
  os?: string;
  osVersion?: string;
  deviceType?: string;
  deviceModel?: string;
  deviceVendor?: string;
  loginTime?: string;
  userAgent?: string;
  latitude?: number;
  longitude?: number;
  locationAccuracy?: number;
  selfieUrl?: string | null;
  screenResolution?: string;
  colorDepth?: number;
  pixelRatio?: number;
  cpuCores?: number;
  deviceMemory?: number;
  touchSupport?: boolean;
  connectionType?: string;
  batteryLevel?: number;
  canvasFingerprint?: string;
  installedFonts?: string;
}

export interface LoginLog {
  id: string;
  username: string;
  is_admin: boolean;
  login_success: boolean;
  ip_address?: string;
  city?: string;
  region?: string;
  country?: string;
  timezone?: string;
  isp?: string;
  browser?: string;
  browser_version?: string;
  os?: string;
  os_version?: string;
  device_type?: string;
  device_model?: string;
  device_vendor?: string;
  user_agent?: string;
  latitude?: number;
  longitude?: number;
  location_accuracy?: number;
  selfie_url?: string;
  screen_resolution?: string;
  color_depth?: number;
  pixel_ratio?: number;
  cpu_cores?: number;
  device_memory?: number;
  touch_support?: boolean;
  connection_type?: string;
  battery_level?: number;
  canvas_fingerprint?: string;
  installed_fonts?: string;
  login_time: string;
  created_at: string;
}

interface AuthContextType {
  user: AdminUser | null;
  login: (username: string, password: string, isAdminLogin: boolean, metadata?: LoginMetadata) => Promise<boolean>;
  logout: () => void;
  isLoading: boolean;
  addStaffMember: (username: string, password: string) => Promise<boolean>;
  getStaffMembers: () => Promise<AdminUser[]>;
  updateStaffMember: (id: string, data: Partial<AdminUser>) => Promise<boolean>;
  deleteStaffMember: (id: string) => Promise<boolean>;
  resetPassword: (username: string, newPassword: string) => Promise<boolean>;
  getLoginLogs: () => Promise<LoginLog[]>;
  deleteLoginLog: (logId: string) => Promise<boolean>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const inactivityTimerRef = useRef<NodeJS.Timeout | null>(null);
  const INACTIVITY_LIMIT_MS = 5 * 60 * 60 * 1000;

  const clearInactivityTimer = () => {
    if (inactivityTimerRef.current) {
      clearTimeout(inactivityTimerRef.current);
      inactivityTimerRef.current = null;
    }
  };

  const startInactivityTimer = () => {
    clearInactivityTimer();
    inactivityTimerRef.current = setTimeout(() => {
      setUser(null);
      localStorage.removeItem('cuephoriaAdmin');
      toast.warning('You have been logged out due to inactivity. Please login again.');
    }, INACTIVITY_LIMIT_MS);
  };

  useEffect(() => {
    if (user) {
      const events = [
        'mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll', 'resize',
        'focus'
      ];
      const resetTimer = () => startInactivityTimer();

      events.forEach(event =>
        window.addEventListener(event, resetTimer, true)
      );
      startInactivityTimer();

      return () => {
        events.forEach(event =>
          window.removeEventListener(event, resetTimer, true)
        );
        clearInactivityTimer();
      };
    } else {
      clearInactivityTimer();
    }
  }, [user]);

  useEffect(() => {
    const checkExistingUser = async () => {
      try {
        // Clear any old admin sessions when Supabase project changes
        // This ensures we don't use cached sessions from old project
        const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
        const isOldProject = supabaseUrl.includes('hxjomxplhbrxtqibgrxw');
        
        if (isOldProject) {
          console.warn('⚠️ Still using old Supabase project! Please update environment variables.');
        }
        
        // Only check for existing stored session - no auto-login
        const storedAdmin = localStorage.getItem('cuephoriaAdmin');
        if (storedAdmin) {
          // Verify the stored admin is still valid by checking Supabase connection
          try {
            const { data: testData, error } = await supabase
              .from('admin_users')
              .select('id')
              .limit(1);
            
            if (error) {
              console.error('Supabase connection error, clearing cached admin:', error);
              localStorage.removeItem('cuephoriaAdmin');
              return;
            }
            
            // If connection is successful, restore the admin session
            setUser(JSON.parse(storedAdmin));
          } catch (error) {
            console.error('Error verifying Supabase connection:', error);
            localStorage.removeItem('cuephoriaAdmin');
          }
        }
      } catch (error) {
        console.error('Error checking existing user:', error);
        // Clear invalid stored data
        localStorage.removeItem('cuephoriaAdmin');
      } finally {
        setIsLoading(false);
      }
    };

    checkExistingUser();
  }, []);

  const login = async (
    username: string, 
    password: string, 
    isAdminLogin: boolean,
    metadata: LoginMetadata = {}
  ): Promise<boolean> => {
    let loginSuccess = false;
    let attemptedUsername = username;

    try {
      const query = supabase
        .from('admin_users')
        .select('id, username, is_admin, password');
      
      if (isAdminLogin) {
        query.eq('is_admin', true);
      } else {
        query.eq('is_admin', false);
      }
      
      query.eq('username', username);
      
      const { data, error } = await query.single();

      if (!error && data && data.password === password) {
        loginSuccess = true;
        const adminUser = {
          id: data.id,
          username: data.username,
          isAdmin: data.is_admin
        };
        setUser(adminUser);
        localStorage.setItem('cuephoriaAdmin', JSON.stringify(adminUser));
      }

      // Save comprehensive login attempt to database
      try {
        const { error: logError } = await supabase
          .from('login_logs')
          .insert({
            username: attemptedUsername,
            is_admin: isAdminLogin,
            login_success: loginSuccess,
            ip_address: metadata.ip || null,
            city: metadata.city || null,
            region: metadata.region || null,
            country: metadata.country || null,
            timezone: metadata.timezone || null,
            isp: metadata.isp || null,
            browser: metadata.browser || null,
            browser_version: metadata.browserVersion || null,
            os: metadata.os || null,
            os_version: metadata.osVersion || null,
            device_type: metadata.deviceType || null,
            device_model: metadata.deviceModel || null,
            device_vendor: metadata.deviceVendor || null,
            user_agent: metadata.userAgent || null,
            latitude: metadata.latitude || null,
            longitude: metadata.longitude || null,
            location_accuracy: metadata.locationAccuracy || null,
            selfie_url: metadata.selfieUrl || null,
            screen_resolution: metadata.screenResolution || null,
            color_depth: metadata.colorDepth || null,
            pixel_ratio: metadata.pixelRatio || null,
            cpu_cores: metadata.cpuCores || null,
            device_memory: metadata.deviceMemory || null,
            touch_support: metadata.touchSupport || null,
            connection_type: metadata.connectionType || null,
            battery_level: metadata.batteryLevel || null,
            canvas_fingerprint: metadata.canvasFingerprint || null,
            installed_fonts: metadata.installedFonts || null,
            login_time: new Date().toISOString()
          });
        
        if (logError) {
          console.error('Error saving login log:', logError);
        } else {
          console.log(loginSuccess ? '✅ Successful login logged with enhanced data' : '❌ Failed login attempt logged');
        }
      } catch (logError) {
        console.error('Error saving login log:', logError);
      }
      
      return loginSuccess;
    } catch (error) {
      console.error('Login error:', error);
      
      try {
        await supabase
          .from('login_logs')
          .insert({
            username: attemptedUsername,
            is_admin: isAdminLogin,
            login_success: false,
            ip_address: metadata.ip || null,
            city: metadata.city || null,
            region: metadata.region || null,
            country: metadata.country || null,
            timezone: metadata.timezone || null,
            isp: metadata.isp || null,
            browser: metadata.browser || null,
            browser_version: metadata.browserVersion || null,
            os: metadata.os || null,
            os_version: metadata.osVersion || null,
            device_type: metadata.deviceType || null,
            device_model: metadata.deviceModel || null,
            device_vendor: metadata.deviceVendor || null,
            user_agent: metadata.userAgent || null,
            latitude: metadata.latitude || null,
            longitude: metadata.longitude || null,
            location_accuracy: metadata.locationAccuracy || null,
            selfie_url: metadata.selfieUrl || null,
            screen_resolution: metadata.screenResolution || null,
            color_depth: metadata.colorDepth || null,
            pixel_ratio: metadata.pixelRatio || null,
            cpu_cores: metadata.cpuCores || null,
            device_memory: metadata.deviceMemory || null,
            touch_support: metadata.touchSupport || null,
            connection_type: metadata.connectionType || null,
            battery_level: metadata.batteryLevel || null,
            canvas_fingerprint: metadata.canvasFingerprint || null,
            installed_fonts: metadata.installedFonts || null,
            login_time: new Date().toISOString()
          });
      } catch (logError) {
        console.error('Error saving failed login log:', logError);
      }
      
      return false;
    }
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem('cuephoriaAdmin');
  };

  const getLoginLogs = async (): Promise<LoginLog[]> => {
    try {
      const { data, error } = await supabase
        .from('login_logs')
        .select('*')
        .order('login_time', { ascending: false })
        .limit(100);
      
      if (error) {
        console.error('Error fetching login logs:', error);
        toast.error('Error fetching login logs');
        return [];
      }
      
      return data || [];
    } catch (error) {
      console.error('Error fetching login logs:', error);
      toast.error('Error fetching login logs');
      return [];
    }
  };

  const deleteLoginLog = async (logId: string): Promise<boolean> => {
    try {
      const { error } = await supabase
        .from('login_logs')
        .delete()
        .eq('id', logId);
      
      if (error) {
        console.error('Error deleting login log:', error);
        toast.error('Error deleting login log');
        return false;
      }
      
      return true;
    } catch (error) {
      console.error('Error deleting login log:', error);
      toast.error('Error deleting login log');
      return false;
    }
  };

  const addStaffMember = async (username: string, password: string): Promise<boolean> => {
    try {
      if (!user?.isAdmin) {
        console.error("Only admins can add staff members");
        toast.error("Only admins can add staff members");
        return false;
      }

      const { data: existingUser } = await supabase
        .from('admin_users')
        .select('id')
        .eq('username', username)
        .single();
      
      if (existingUser) {
        console.error('Username already exists');
        toast.error('Username already exists');
        return false;
      }
      
      const basicUserData = {
        username,
        password,
        is_admin: false
      };
      
      const { error } = await supabase
        .from('admin_users')
        .insert(basicUserData);
      
      if (error) {
        console.error('Error creating staff member:', error);
        toast.error('Error creating staff member');
        return false;
      }
      
      toast.success('Staff member added successfully');
      return true;
    } catch (error) {
      console.error('Error adding staff member:', error);
      toast.error('Error adding staff member');
      return false;
    }
  };

  const getStaffMembers = async (): Promise<AdminUser[]> => {
    try {
      if (!user?.isAdmin) {
        console.error("Only admins can view staff members");
        toast.error("Only admins can view staff members");
        return [];
      }
      
      const { data, error } = await supabase
        .from('admin_users')
        .select('id, username, is_admin')
        .eq('is_admin', false);
      
      if (error) {
        console.error('Error fetching staff members:', error);
        toast.error('Error fetching staff members');
        return [];
      }
        
      if (!data || !Array.isArray(data)) {
        return [];
      }
      
      const staffMembers: AdminUser[] = data.map(staff => ({
        id: staff.id || '',
        username: staff.username || '',
        isAdmin: staff.is_admin === true,
      }));
      
      return staffMembers;
    } catch (error) {
      console.error('Error fetching staff members:', error);
      toast.error('Error fetching staff members');
      return [];
    }
  };

  const updateStaffMember = async (id: string, updatedData: Partial<AdminUser>): Promise<boolean> => {
    try {
      if (!user?.isAdmin) {
        console.error("Only admins can update staff members");
        toast.error("Only admins can update staff members");
        return false;
      }

      const dbData: Record<string, any> = {};
      
      if (updatedData.username) dbData.username = updatedData.username;

      if (Object.keys(dbData).length > 0) {
        const { error } = await supabase
          .from('admin_users')
          .update(dbData)
          .eq('id', id);
        
        if (error) {
          console.error('Error updating staff member:', error);
          toast.error('Error updating staff member');
          return false;
        }
      } else {
        console.warn("No valid fields to update");
      }
      
      toast.success('Staff member updated successfully');
      return true;
    } catch (error) {
      console.error('Error updating staff member:', error);
      toast.error('Error updating staff member');
      return false;
    }
  };

  const deleteStaffMember = async (id: string): Promise<boolean> => {
    try {
      if (!user?.isAdmin) {
        console.error("Only admins can delete staff members");
        toast.error("Only admins can delete staff members");
        return false;
      }
      
      const { error } = await supabase
        .from('admin_users')
        .delete()
        .eq('id', id);
      
      if (error) {
        console.error('Error deleting staff member:', error);
        toast.error('Error deleting staff member');
        return false;
      }
      
      toast.success('Staff member deleted successfully');
      return true;
    } catch (error) {
      console.error('Error deleting staff member:', error);
      toast.error('Error deleting staff member');
      return false;
    }
  };

  const resetPassword = async (username: string, newPassword: string): Promise<boolean> => {
    try {
      const { data, error } = await supabase
        .from('admin_users')
        .select('id')
        .eq('username', username)
        .single();
        
      if (error || !data) {
        console.error('Error finding user for password reset:', error);
        return false;
      }
      
      const { error: updateError } = await supabase
        .from('admin_users')
        .update({ password: newPassword })
        .eq('id', data.id);
        
      if (updateError) {
        console.error('Error updating password:', updateError);
        return false;
      }
      
      return true;
    } catch (error) {
      console.error('Error in resetPassword:', error);
      return false;
    }
  };

  return (
    <AuthContext.Provider value={{ 
      user, 
      login, 
      logout, 
      isLoading, 
      addStaffMember, 
      getStaffMembers,
      updateStaffMember,
      deleteStaffMember,
      resetPassword,
      getLoginLogs,
      deleteLoginLog
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
