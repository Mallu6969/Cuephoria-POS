import React from 'react';
// import { useSubscription } from '@/context/SubscriptionContext';
// import SubscriptionDialog from './SubscriptionDialog';
// import { useLocation } from 'react-router-dom';

const SubscriptionGuard: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // DISABLED: Subscription guard removed for replica site - always allow access
  // const { isSubscriptionValid, isLoading } = useSubscription();
  // const location = useLocation();

  // Allow access to login, admin subscription page, subscription page, and public pages
  // const allowedPaths = [
  //   '/login',
  //   '/admin-subscription',
  //   '/subscription',
  //   '/public/tournaments',
  //   '/public/stations',
  //   '/public/booking',
  //   '/public/payment/success',
  //   '/public/payment/failed',
  //   '/',
  // ];

  // Don't show dialog on allowed paths
  // if (allowedPaths.includes(location.pathname)) {
  //   return <>{children}</>;
  // }

  // Show dialog if subscription is invalid (but still render children in background)
  // const showDialog = !isLoading && !isSubscriptionValid;

  // Always allow access - no subscription check
  return <>{children}</>;
};

export default SubscriptionGuard;

