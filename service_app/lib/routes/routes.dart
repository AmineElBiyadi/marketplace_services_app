import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/Authentificcation/client/login_screen.dart' as client_login;
import '../screens/Authentificcation/client/signup_screen.dart' as client_signup;
import '../screens/Authentificcation/client/otp_screen.dart' as client_otp;
import '../screens/Authentificcation/provider/provider_login_screen.dart' as provider_login;
import '../screens/Authentificcation/provider/provider_signup_screen.dart' as provider_signup;
import '../screens/Authentificcation/provider/provider_pending_screen.dart' as provider_pending;
import '../screens/Authentificcation/client/welcome_screen.dart';
import '../screens/Authentificcation/admin/admin_login_screen.dart' as admin_login;
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/admin/admin_providers_screen.dart';
import '../screens/admin/admin_reservations_screen.dart';
import '../screens/admin/admin_reviews_screen.dart';
import '../screens/admin/admin_finances_screen.dart';
import '../screens/admin/admin_statistics_screen.dart';
import '../screens/admin/admin_settings_screen.dart';
import '../screens/provider/provider_dashboard_screen.dart';
import '../screens/provider/provider_reservations_screen.dart';
import '../screens/provider/provider_services_screen.dart';
import '../navigation/main_navigation.dart';

// ─── Route name constants ──────────────────────────────────────────
class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';

  static const String providerLogin = '/provider/login';
  static const String providerSignup = '/provider/signup';
  static const String providerPending = '/provider/pending';
  static const String providerDashboard = '/provider/:expertId/dashboard';
  static const String providerBookings = '/provider/:expertId/bookings';
  static const String providerServices = '/provider/:expertId/services';
  static const String providerAgenda = '/provider/:expertId/agenda';
  static const String providerProfile = '/provider/:expertId/profile';
  static const String providerNotifications = '/provider/:expertId/notifications';
  static const String providerSubscription = '/provider/:expertId/subscription';
  static const String providerSettings = '/provider/:expertId/settings';

  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminProviders = '/admin/providers';
  static const String adminReservations = '/admin/reservations';
  static const String adminReviews = '/admin/reviews';
  static const String adminFinances = '/admin/finances';
  static const String adminStatistics = '/admin/statistics';
  static const String adminSettings = '/admin/settings';
}

// ─── GoRouter configuration ────────────────────────────────────────
final GoRouter router = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    // ── Client ──
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const client_login.LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const client_signup.SignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.otp,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return client_otp.OTPScreen(extraData: extra);
      },
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainNavigation(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Mot de passe oublié')),
        body: const Center(child: Text('Forgot Password Screen')),
      ),
    ),

    // ── Provider ──
    GoRoute(
      path: AppRoutes.providerLogin,
      builder: (context, state) => const provider_login.ProviderLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerSignup,
      builder: (context, state) => const provider_signup.ProviderSignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerPending,
      builder: (context, state) => const provider_pending.ProviderPendingScreen(),
    ),
    GoRoute(
      path: AppRoutes.providerDashboard,
      builder: (context, state) {
        final expertId = state.pathParameters['expertId'] ?? '';
        return ProviderDashboardScreen(expertId: expertId);
      },
    ),
    GoRoute(
      path: AppRoutes.providerBookings,
      builder: (context, state) {
        final expertId = state.pathParameters['expertId'] ?? '';
        return ProviderReservationsScreen(expertId: expertId);
      },
    ),
    GoRoute(
      path: AppRoutes.providerServices,
      builder: (context, state) {
        final expertId = state.pathParameters['expertId'] ?? '';
        return ProviderServicesScreen(expertId: expertId);
      },
    ),
    // Additional Provider Routes (Agenda, Profile, etc.)
    GoRoute(
      path: AppRoutes.providerAgenda,
      builder: (context, state) {
        final expertId = state.pathParameters['expertId'] ?? '';
        return ProviderDashboardScreen(expertId: expertId); // Fallback to dashboard for now
      },
    ),
    GoRoute(
      path: AppRoutes.providerProfile,
      builder: (context, state) {
        final expertId = state.pathParameters['expertId'] ?? '';
        return ProviderDashboardScreen(expertId: expertId); // Fallback
      },
    ),

    // ── Admin ──
    GoRoute(
      path: AppRoutes.adminLogin,
      builder: (context, state) => const admin_login.AdminLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminDashboardScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminUsers,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminUsersScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminProviders,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminProvidersScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminReservations,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminReservationsScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminReviews,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminReviewsScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminFinances,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminFinancesScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminStatistics,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminStatisticsScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminSettings,
      pageBuilder: (context, state) => const NoTransitionPage(child: AdminSettingsScreen()),
    ),
  ],
);