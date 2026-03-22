import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/routes.dart';
import 'theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'services/maintenance_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('fr', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => MaintenanceService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // Initialize the router with the maintenance service
    _appRouter = AppRouter(context.read<MaintenanceService>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Marketplace Services',
      theme: AppTheme.lightTheme,
      routerConfig: _appRouter.router,
      builder: (context, child) {
        return Consumer<MaintenanceService>(
          builder: (context, maintenance, _) {
            // While we are waiting for Firestore initial state, show a fake splash
            if (!maintenance.initialized) {
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
            // Once initialized, let GoRouter control navigation
            return child!;
          },
        );
      },
    );
  }
}