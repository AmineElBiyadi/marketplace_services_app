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
              Image.asset(
                'assets/logo.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) => const SizedBox(height: 120),
              ),
              const SizedBox(height: 32),
              // ── Title ──
              const Text(
                'Presto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A237E),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'snap your fingers, we handle the rest.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontStyle: FontStyle.italic,
                  ),
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
