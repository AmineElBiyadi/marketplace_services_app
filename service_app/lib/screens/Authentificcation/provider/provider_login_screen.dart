import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/firestore_service.dart';


class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _showPassword = false;
  bool _isLoading = false;


  bool get _isValid =>
      _phoneController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _handleLogin() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);

    try {
      final user = await _firestoreService.loginProvider(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (user != null) {
        if (mounted) {
          final etatCompte = user['etatCompte'] ?? 'PENDING';
          final expertId = user['expertId'] ?? '';
          if (etatCompte == 'ACTIVE') {
            context.go('/provider/$expertId/dashboard');
          } else {
            context.go('/provider/pending');
          }
        }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.pushReplacement('/login');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                color: AppColors.textPrimary,
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
                  child: Icon(
                    Icons.construction,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    "Espace Prestataire",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.build,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Connectez-vous à votre compte pro",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                hint: "Email ou numéro de téléphone",
                controller: _phoneController,
                keyboardType: TextInputType.emailAddress,
                prefix: Icon(Icons.person, color: AppColors.textSecondary),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hint: "Mot de passe",
                controller: _passwordController,
                obscureText: !_showPassword,
                prefix: Icon(Icons.lock, color: AppColors.textSecondary),
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text(
                    "Mot de passe oublié ?",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _isLoading ? "Connexion en cours..." : "Se connecter",
                onPressed: _isValid && !_isLoading ? _handleLogin : null,
                disabled: !_isValid || _isLoading,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Pas encore de compte ? ",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/provider/signup'),
                    child: Text(
                      "S'inscrire",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
