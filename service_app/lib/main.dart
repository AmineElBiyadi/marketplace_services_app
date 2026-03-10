import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'router.dart';

import 'navigation/main_navigation.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_providers_screen.dart';
import 'screens/admin/admin_reservations_screen.dart';
import 'screens/admin/admin_reviews_screen.dart';
import 'screens/admin/admin_finances_screen.dart';
import 'screens/admin/admin_statistics_screen.dart';
import 'screens/admin/admin_notifications_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'theme/app_theme.dart';
import 'screens/provider/provider_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marketplace Services',
      theme: ThemeData(
        primaryColor: const Color(0xFF3D5A99),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5A99)),
      ),
      home: const MainNavigation(),
      routes: {
        '/admin': (context) => const AdminDashboardScreen(),
        '/admin/users': (context) => const AdminUsersScreen(),
        '/admin/providers': (context) => const AdminProvidersScreen(),
        '/admin/reservations': (context) => const AdminReservationsScreen(),
        '/admin/reviews': (context) => const AdminReviewsScreen(),
        '/admin/finances': (context) => const AdminFinancesScreen(),
        '/admin/statistics': (context) => const AdminStatisticsScreen(),
        '/admin/notifications': (context) => const AdminNotificationsScreen(),
        '/admin/settings': (context) => const AdminSettingsScreen(),
      },
    );
  }
}