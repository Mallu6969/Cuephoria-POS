// src/App.tsx
import React, { lazy, Suspense } from "react";
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { POSProvider } from "@/context/POSContext";
import { ExpenseProvider } from "@/context/ExpenseContext";
import { SubscriptionProvider } from "@/context/SubscriptionContext";
import { BookingNotificationProvider } from "@/context/BookingNotificationContext";
import SubscriptionGuard from "@/components/SubscriptionGuard";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import AppSidebar from "@/components/AppSidebar";
import GlobalNotificationBell from "@/components/GlobalNotificationBell";

// Pages
import Login from "./pages/Login";
import LoginLogs from "./pages/LoginLogs";
import Dashboard from "./pages/Dashboard";
import Stations from "./pages/Stations";
import Products from "./pages/Products";
import POS from "./pages/POS";
import Customers from "./pages/Customers";
import Reports from "./pages/Reports";
import Settings from "./pages/Settings";
import NotFound from "./pages/NotFound";
import Index from "./pages/Index";
import PublicTournaments from "./pages/PublicTournaments";
import PublicStations from "./pages/PublicStations";
import PublicBooking from "./pages/PublicBooking";
import BookingPage from "./pages/BookingPage";
import BookingManagement from "./pages/BookingManagement";
import StaffManagement from "./pages/StaffManagement";
import StaffPortal from "./pages/StaffPortal";
import Subscription from "./pages/Subscription";
import AdminSubscription from "./pages/AdminSubscription";

// Payment routes
import PublicPaymentSuccess from "./pages/PublicPaymentSuccess";
import PublicPaymentFailed from "./pages/PublicPaymentFailed";

// Lazy load HowToUse for code splitting
const HowToUsePage = lazy(() => import("./pages/HowToUse"));

// ✅ OPTIMIZED: Aggressive caching to reduce egress by 60-80%
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 15 * 60 * 1000, // 15 minutes - data stays fresh longer
      cacheTime: 30 * 60 * 1000, // 30 minutes - keep in cache longer
      refetchOnWindowFocus: false, // Don't refetch when switching tabs
      refetchOnMount: false, // Don't refetch when component remounts
      retry: 1,
    },
  },
});

interface ProtectedRouteProps {
  children: React.ReactNode;
  requireAdmin?: boolean;
  requireStaffOnly?: boolean;
}

// Enhanced Protected route component that checks for authentication
const ProtectedRoute = ({ 
  children, 
  requireAdmin = false,
  requireStaffOnly = false 
}: ProtectedRouteProps) => {
  const { user, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#1a1a1a] via-[#1a0f1a] to-[#1a1a1a]">
        <div className="animate-spin-slow h-10 w-10 rounded-full border-4 border-nerfturf-purple border-t-transparent shadow-lg shadow-nerfturf-purple/50"></div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }

  if (requireAdmin && !user.isAdmin) {
    return <Navigate to="/dashboard" replace />;
  }

  if (requireStaffOnly && user.isAdmin) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <SidebarProvider>
      <div className="flex min-h-screen w-full overflow-x-hidden">
        <AppSidebar />
        <div className="flex-1 flex flex-col overflow-x-hidden">
          <div className="hidden md:flex items-center justify-between px-4 py-2 border-b">
            <SidebarTrigger />
            <GlobalNotificationBell />
          </div>
          {children}
          <footer className="mt-auto w-full py-2 text-center text-xs text-nerfturf-lightpurple/80 bg-black/80 border-t border-nerfturf-purple/20 font-semibold tracking-wide z-50 backdrop-blur-sm">
            Designed & Developed by Cuephoria Tech<sup className="text-nerfturf-purple">™</sup>
          </footer>
        </div>
      </div>
    </SidebarProvider>
  );
};

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <SubscriptionProvider>
        <POSProvider>
          <ExpenseProvider>
            <BookingNotificationProvider>
              <TooltipProvider>
                <Toaster />
                <Sonner />
                <BrowserRouter>
                  <SubscriptionGuard>
                    <Routes>
                <Route path="/" element={<Index />} />
                <Route path="/login" element={<Login />} />
                <Route path="/login-logs" element={<LoginLogs />} />

                {/* Public routes */}
                <Route path="/public/tournaments" element={<PublicTournaments />} />
                <Route path="/public/stations" element={<PublicStations />} />
                <Route path="/public/booking" element={<PublicBooking />} />

                {/* Payment routes */}
                <Route path="/public/payment/success" element={<PublicPaymentSuccess />} />
                <Route path="/public/payment/failed" element={<PublicPaymentFailed />} />

                {/* Protected routes */}
                <Route
                  path="/dashboard"
                  element={
                    <ProtectedRoute>
                      <Dashboard />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/pos"
                  element={
                    <ProtectedRoute>
                      <POS />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/stations"
                  element={
                    <ProtectedRoute>
                      <Stations />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/products"
                  element={
                    <ProtectedRoute>
                      <Products />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/customers"
                  element={
                    <ProtectedRoute>
                      <Customers />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/reports"
                  element={
                    <ProtectedRoute>
                      <Reports />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/booking"
                  element={
                    <ProtectedRoute>
                      <BookingPage />
                    </ProtectedRoute>
                  }
                />
                <Route
                  path="/booking-management"
                  element={
                    <ProtectedRoute>
                      <BookingManagement />
                    </ProtectedRoute>
                  }
                />

                {/* Staff Management - Admin Only */}
                <Route
                  path="/staff"
                  element={
                    <ProtectedRoute requireAdmin={true}>
                      <StaffManagement />
                    </ProtectedRoute>
                  }
                />

                {/* Staff Portal - Staff Only (NOT Admin) */}
                <Route
                  path="/staff-portal"
                  element={
                    <ProtectedRoute requireStaffOnly={true}>
                      <StaffPortal />
                    </ProtectedRoute>
                  }
                />

                {/* How to Use page - Moved to bottom */}
                <Route
                  path="/how-to-use"
                  element={
                    <ProtectedRoute>
                      <Suspense
                        fallback={
                          <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#1a1a1a] via-[#1a0f1a] to-[#1a1a1a]">
                            <div className="animate-spin-slow h-10 w-10 rounded-full border-4 border-nerfturf-purple border-t-transparent shadow-lg shadow-nerfturf-purple/50"></div>
                          </div>
                        }
                      >
                        <HowToUsePage />
                      </Suspense>
                    </ProtectedRoute>
                  }
                />

                {/* Settings */}
                <Route
                  path="/settings"
                  element={
                    <ProtectedRoute>
                      <Settings />
                    </ProtectedRoute>
                  }
                />

                {/* Subscription - User-facing */}
                <Route
                  path="/subscription"
                  element={
                    <ProtectedRoute>
                      <Subscription />
                    </ProtectedRoute>
                  }
                />

                {/* Admin Subscription - PIN Protected, not in sidebar */}
                <Route
                  path="/admin-subscription"
                  element={
                    <ProtectedRoute>
                      <AdminSubscription />
                    </ProtectedRoute>
                  }
                />

                <Route path="*" element={<NotFound />} />
                  </Routes>
                </SubscriptionGuard>
              </BrowserRouter>
            </TooltipProvider>
            </BookingNotificationProvider>
          </ExpenseProvider>
        </POSProvider>
      </SubscriptionProvider>
    </AuthProvider>
  </QueryClientProvider>
);

export default App;
