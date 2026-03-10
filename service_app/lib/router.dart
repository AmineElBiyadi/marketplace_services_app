import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/Authentificcation/client/login_screen.dart' as client_login;
import 'screens/Authentificcation/client/signup_screen.dart' as client_signup;
import 'screens/Authentificcation/client/otp_screen.dart' as client_otp;
import 'screens/Authentificcation/provider/provider_login_screen.dart' as provider_login;
import 'screens/Authentificcation/provider/provider_signup_screen.dart' as provider_signup;
import 'screens/Authentificcation/admin/admin_login_screen.dart' as admin_login;

// GoRouter configuration
final GoRouter router = GoRouter(
  initialLocation: '/login',
  routes: [
    // Client Authentification
    GoRoute(
      path: '/login',
      builder: (context, state) => const client_login.LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const client_signup.SignupScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return client_otp.OTPScreen(extraData: extra);
      },
    ),
    // Provider Authentification
    GoRoute(
      path: '/provider/login',
      builder: (context, state) => const provider_login.ProviderLoginScreen(),
    ),
    GoRoute(
      path: '/provider/signup',
      builder: (context, state) => const provider_signup.ProviderSignupScreen(),
    ),
    // Admin Authentification
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const admin_login.AdminLoginScreen(),
    ),
    // Dummy routes to prevent crash after login
    GoRoute(
      path: '/home',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: const Center(child: Text('Home Screen')),
      ),
    ),
    GoRoute(
      path: '/provider/dashboard',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Provider Dashboard')),
        body: const Center(child: Text('Provider Dashboard Screen')),
      ),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Forgot Password')),
        body: const Center(child: Text('Forgot Password Screen')),
      ),
    ),
  ],
);
