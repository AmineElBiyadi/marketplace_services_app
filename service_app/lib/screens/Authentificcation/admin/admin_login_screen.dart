import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/hash_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  int _attempts = 0;
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool get _isValid =>
      _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_attempts >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte verrouillé. Trop de tentatives.'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Hash the password input
      final hashedPassword = HashService.hashPassword(_passwordController.text);

      // 2. Find the user in 'utilisateurs' using email and hashed password
      final userQuery = await _firestoreService.getFirestoreInstance()
          .collection('utilisateurs')
          .where('email', isEqualTo: _emailController.text.trim())
          .where('motDePasse', isEqualTo: hashedPassword)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userId = userQuery.docs.first.id;

        // 3. Verify this user is an admin by checking the 'admins' collection
        final adminQuery = await _firestoreService.getFirestoreInstance()
            .collection('admins')
            .where('idUtilisateur', isEqualTo: userId)
            .limit(1)
            .get();

        if (adminQuery.docs.isNotEmpty) {
          final adminId = adminQuery.docs.first.id;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('logged_admin_id', adminId);
          if (mounted) context.go('/admin');
          return;
        }
      }

      // If we reach here, either the email wasn't found or the password didn't match
      setState(() => _attempts++);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Identifiants incorrects. ${5 - _attempts} tentative(s) restante(s).',
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.pushReplacement('/login');
                }
              },
              icon: const Icon(Icons.arrow_back, color: AppColors.foreground),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.shield,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Espace Administration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Accédez à votre espace admin',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              hintText: 'Mot de passe',
              obscureText: !_showPassword,
              controller: _passwordController,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.mutedForeground,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: _isLoading ? 'Connexion en cours...' : 'Se connecter',
              height: 48,
              onPressed: _isValid && !_isLoading ? _handleLogin : null,
              isLoading: _isLoading,
            ),
            if (_attempts > 0 && _attempts < 5) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${5 - _attempts} tentative(s) restante(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
