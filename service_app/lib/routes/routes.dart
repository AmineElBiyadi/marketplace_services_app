import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/Authentificcation/client/login_screen.dart' as client_login;
import '../screens/Authentificcation/client/signup_screen.dart' as client_signup;
import '../screens/Authentificcation/client/otp_screen.dart' as client_otp;
import '../screens/Authentificcation/provider/provider_login_screen.dart' as provider_login;
import '../screens/Authentificcation/provider/provider_signup_screen.dart' as provider_signup;
import '../screens/Authentificcation/provider/provider_pending_screen.dart' as provider_pending;
import '../screens/Authentificcation/admin/admin_login_screen.dart' as admin_login;
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/provider/provider_dashboard_screen.dart';
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
  static const String providerDashboard = '/provider/dashboard';
  static const String providerPending = '/provider/pending';

  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
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
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final expertId = extra['expertId'] as String? ?? '';
        return ProviderDashboardScreen(expertId: expertId);
      },
    ),

    // ── Admin ──
    GoRoute(
      path: AppRoutes.adminLogin,
      builder: (context, state) => const admin_login.AdminLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
  ],
);