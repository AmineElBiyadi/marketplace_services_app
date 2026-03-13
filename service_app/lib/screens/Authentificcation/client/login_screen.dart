import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _showPassword = false;
  bool _isLoading = false;

  bool get _isValid =>
      _phoneController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);
    
    try {
      final user = await _firestoreService.loginClient(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_client_id', user['id']);
        if (mounted) context.go('/home');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Identifiant ou mot de passe incorrect.'),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                  context.pushReplacement('/login'); // Or another default route
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
                  Icons.construction,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bon retour !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Connectez-vous pour continuer',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              hintText: 'Email ou numéro de téléphone',
              keyboardType: TextInputType.emailAddress,
              controller: _phoneController,
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.go('/forgot-password'),
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: _isLoading ? 'Connexion en cours...' : 'Se connecter',
              height: 48,
              onPressed: _isValid && !_isLoading ? _handleLogin : null,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Pas encore de compte ? ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/signup'),
                  child: const Text(
                    "S'inscrire",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.border)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: "Accéder à l'espace Prestataire",
              isOutlined: true,
              height: 44,
              onPressed: () => context.go('/provider/login'),
            ),
            const SizedBox(height: 16),
            // Admin access button (discreet)
            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/admin/login'),
                icon: const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                label: const Text(
                  "Espace Administration",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
