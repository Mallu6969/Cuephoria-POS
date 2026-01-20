import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { getPlanByName } from '@/lib/subscriptionPlans';

interface Subscription {
  id: string;
  is_active: boolean;
  subscription_type: 'monthly' | 'quarterly' | 'yearly' | 'lifetime';
  start_date: string;
  end_date: string;
  amount_paid: number;
  pages_enabled: boolean;
  plan_name?: string;
  booking_access?: boolean;
  staff_management_access?: boolean;
  allow_custom_end_date?: boolean;
  created_at: string;
  updated_at: string;
}

interface SubscriptionContextType {
  subscription: Subscription | null;
  isLoading: boolean;
  isSubscriptionValid: boolean;
  hasBookingAccess: boolean;
  hasStaffManagementAccess: boolean;
  refreshSubscription: () => Promise<void>;
  updateSubscription: (data: Partial<Subscription>) => Promise<boolean>;
}

const SubscriptionContext = createContext<SubscriptionContextType | undefined>(undefined);

export const SubscriptionProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const checkSubscriptionValidity = (sub: Subscription | null): boolean => {
    // DISABLED: Always return true for replica site - no subscription restrictions
    return true;
    
    // Original validation code (disabled):
    // if (!sub || !sub.is_active || !sub.pages_enabled) {
    //   return false;
    // }
    // 
    // const today = new Date();
    // today.setHours(0, 0, 0, 0);
    // const endDate = new Date(sub.end_date);
    // endDate.setHours(0, 0, 0, 0);
    // 
    // return endDate >= today;
  };

  const fetchSubscription = async () => {
    try {
      const { data, error } = await supabase
        .from('subscription')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (error && error.code !== 'PGRST116') {
        console.error('Error fetching subscription:', error);
        return;
      }

      if (data) {
        setSubscription(data as Subscription);
      }
    } catch (error) {
      console.error('Error fetching subscription:', error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchSubscription();
    
    // Refresh subscription every minute to check validity
    const interval = setInterval(fetchSubscription, 60000);
    return () => clearInterval(interval);
  }, []);

  const refreshSubscription = async () => {
    await fetchSubscription();
  };

  const calculateEndDate = (startDate: Date, type: 'monthly' | 'quarterly' | 'yearly'): Date => {
    const endDate = new Date(startDate);
    switch (type) {
      case 'monthly':
        endDate.setMonth(endDate.getMonth() + 1);
        break;
      case 'quarterly':
        endDate.setMonth(endDate.getMonth() + 3);
        break;
      case 'yearly':
        endDate.setFullYear(endDate.getFullYear() + 1);
        break;
    }
    return endDate;
  };

  const updateSubscription = async (data: Partial<Subscription>): Promise<boolean> => {
    try {
      if (!subscription) {
        // Create new subscription
        const subscriptionType = data.subscription_type || 'monthly';
        const startDate = data.start_date ? new Date(data.start_date) : new Date();
        
        // Use plan duration if plan_name is provided for accurate calculation
        let endDate: Date;
        if (data.plan_name) {
          const plan = getPlanByName(data.plan_name);
          if (plan && plan.type !== 'lifetime') {
            endDate = new Date(startDate);
            endDate.setMonth(endDate.getMonth() + plan.duration);
          } else if (plan && plan.type === 'lifetime') {
            endDate = new Date(startDate);
            endDate.setFullYear(endDate.getFullYear() + 100);
          } else {
            endDate = calculateEndDate(startDate, subscriptionType);
          }
        } else {
          endDate = calculateEndDate(startDate, subscriptionType);
        }
        
        const newSubscription = {
          is_active: data.is_active ?? true,
          subscription_type: subscriptionType,
          start_date: startDate.toISOString().split('T')[0],
          end_date: endDate.toISOString().split('T')[0],
          amount_paid: data.amount_paid ?? 0,
          pages_enabled: data.pages_enabled ?? true,
        };

        const { data: inserted, error } = await supabase
          .from('subscription')
          .insert(newSubscription)
          .select()
          .single();

        if (error) throw error;
        setSubscription(inserted as Subscription);
        toast.success('Subscription created successfully');
        return true;
      } else {
        // Update existing subscription
        const updateData: any = { ...data };
        
        // Only recalculate end_date if it's not already provided and we have the necessary data
        if (!data.end_date && data.start_date) {
          // If plan_name is provided, use plan duration for accurate calculation
          if (data.plan_name) {
            const plan = getPlanByName(data.plan_name);
            if (plan && plan.type !== 'lifetime') {
              const startDate = new Date(data.start_date);
              const endDate = new Date(startDate);
              endDate.setMonth(endDate.getMonth() + plan.duration);
              updateData.end_date = endDate.toISOString().split('T')[0];
            } else if (plan && plan.type === 'lifetime') {
              const startDate = new Date(data.start_date);
              const endDate = new Date(startDate);
              endDate.setFullYear(endDate.getFullYear() + 100);
              updateData.end_date = endDate.toISOString().split('T')[0];
            }
          } else if (data.subscription_type) {
            // Fallback to type-based calculation if plan_name not available
            const startDate = new Date(data.start_date);
            const endDate = calculateEndDate(startDate, data.subscription_type);
            updateData.end_date = endDate.toISOString().split('T')[0];
          }
        }
        
        updateData.updated_at = new Date().toISOString();

        const { data: updated, error } = await supabase
          .from('subscription')
          .update(updateData)
          .eq('id', subscription.id)
          .select()
          .single();

        if (error) throw error;
        setSubscription(updated as Subscription);
        toast.success('Subscription updated successfully');
        return true;
      }
    } catch (error: any) {
      console.error('Error updating subscription:', error);
      toast.error(error.message || 'Failed to update subscription');
      return false;
    }
  };

  const isSubscriptionValid = checkSubscriptionValidity(subscription);
  
  // DISABLED: Always allow access for replica site
  const hasBookingAccess = true; // subscription?.booking_access === true && isSubscriptionValid;
  const hasStaffManagementAccess = true; // subscription?.staff_management_access === true && isSubscriptionValid;

  return (
    <SubscriptionContext.Provider value={{
      subscription,
      isLoading,
      isSubscriptionValid,
      hasBookingAccess,
      hasStaffManagementAccess,
      refreshSubscription,
      updateSubscription,
    }}>
      {children}
    </SubscriptionContext.Provider>
  );
};

export const useSubscription = () => {
  const context = useContext(SubscriptionContext);
  if (context === undefined) {
    throw new Error('useSubscription must be used within a SubscriptionProvider');
  }
  return context;
};

