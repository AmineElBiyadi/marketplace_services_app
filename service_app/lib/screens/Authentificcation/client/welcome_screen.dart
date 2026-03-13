import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // ── Illustration ──
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(110),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Toolbox icon cluster
                    const Icon(Icons.home_repair_service_rounded,
                        size: 100, color: Color(0xFF2B4B9B)),
                    Positioned(
                      top: 30,
                      right: 28,
                      child: Icon(Icons.handyman,
                          size: 32, color: const Color(0xFFE8A020)),
                    ),
                    Positioned(
                      top: 28,
                      left: 30,
                      child: Icon(Icons.plumbing,
                          size: 28, color: const Color(0xFF4CAF50)),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 34,
                      child: Icon(Icons.electrical_services,
                          size: 26, color: const Color(0xFFE8A020)),
                    ),
                    Positioned(
                      bottom: 28,
                      right: 32,
                      child: Icon(Icons.carpenter,
                          size: 28, color: const Color(0xFF2B4B9B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ── Title ──
              const Text(
                'Bienvenue sur ServiConnect',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: 'Trouvez des '),
                    TextSpan(
                      text: 'professionnels de confiance',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' ou proposez vos services.'),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // ── CTA Buttons ──
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/signup'),
                  icon: const Icon(Icons.person_outline,
                      color: Colors.white, size: 22),
                  label: const Text(
                    'Je suis Client',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F64B5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/provider/signup'),
                  icon: const Icon(Icons.build_outlined,
                      color: Color(0xFFB8860B), size: 22),
                  label: const Text(
                    'Je suis Prestataire',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF9E6),
                    side: const BorderSide(
                        color: Color(0xFFE8C060), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // ── Login links ──
              _loginLink(
                context,
                prefix: 'Déjà un compte client ? ',
                label: 'Se connecter',
                onTap: () => context.go('/login'),
              ),
              const SizedBox(height: 10),
              _loginLink(
                context,
                prefix: 'Déjà un compte prestataire ? ',
                label: 'Se connecter',
                onTap: () => context.go('/provider/login'),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginLink(BuildContext context,
      {required String prefix,
      required String label,
      required VoidCallback onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prefix,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF64748B))),
        GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3F64B5),
            ),
          ),
        ),
      ],
    );
  }
}
