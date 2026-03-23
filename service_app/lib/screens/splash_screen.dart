import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final String currentPath = GoRouterState.of(context).uri.path;

    if (user == null) {
      // Define paths that unauthenticated users are allowed to access directly
      final publicPaths = [
        '/welcome',
        '/login',
        '/signup',
        '/otp',
        '/forgot-password',
        '/provider/login',
        '/provider/signup',
        '/admin/login',
      ];

      // If the user requested a specific public page, let them stay there
      if (currentPath != '/' && publicPaths.contains(currentPath)) {
        context.go(currentPath);
      } else {
        context.go('/welcome');
      }
      return;
    }

    // Try client
    final clientData = await _firestoreService.getClientByUid(user.uid);
    if (clientData != null) {
      final activeCgu = await _firestoreService.fetchActiveCGU('CLIENT');
      final acceptedVersion = clientData['acceptedCguVersion'] ?? 'none';
      final activeVersion = activeCgu?['version'] ?? '1.0';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_client_id', user.uid);
      
      if (mounted) {
        if (acceptedVersion != activeVersion) {
          context.go('/cgu_update', extra: {'role': 'CLIENT', 'uid': user.uid, 'cgu': activeCgu});
        } else {
          context.go('/home');
        }
      }
      return;
    }

    // Try provider
    final providerData = await _firestoreService.getProviderByUid(user.uid);
    if (providerData != null) {
      final expertId = providerData['expertId'] ?? '';
      final activeCgu = await _firestoreService.fetchActiveCGU('EXPERT');
      final acceptedVersion = providerData['acceptedCguVersion'] ?? 'none';
      final activeVersion = activeCgu?['version'] ?? '1.0';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_expert_id', expertId);
      
      if (mounted) {
        if (acceptedVersion != activeVersion) {
          context.go('/cgu_update', extra: {'role': 'EXPERT', 'uid': user.uid, 'cgu': activeCgu});
          return;
        }

        final etatCompte = providerData['etatCompte'] ?? 'PENDING';
        if (etatCompte == 'ACTIVE') {
          context.go('/provider/$expertId/dashboard');
        } else {
          context.go('/provider/pending');
        }
      }
      return;
    }

    // Admin session check is handled directly by admin login/dashboard
    // If they have an active admin session, GoRouter's redirect guard handles the rest.
    if (currentPath.startsWith('/admin')) {
        context.go(currentPath);
        return;
    }

    // Firebase Auth user exists but no Firestore record — send to welcome
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.handyman,
                size: 60,
                color: Color(0xFF3F64B5),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Color(0xFF3F64B5),
            ),
          ],
        ),
      ),
    );
  }
}
