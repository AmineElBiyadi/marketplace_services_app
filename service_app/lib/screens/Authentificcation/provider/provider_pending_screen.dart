import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderPendingScreen extends StatelessWidget {
  const ProviderPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEEF2FF),
              Colors.white,
              Color(0xFFFFFBEB),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // ── Top illustration ──
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(80),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.home_repair_service_rounded,
                          size: 70, color: Color(0xFF2B4B9B)),
                      Positioned(
                        top: 22,
                        right: 18,
                        child: Icon(Icons.handyman,
                            size: 26, color: const Color(0xFFE8A020)),
                      ),
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Icon(Icons.plumbing,
                            size: 22, color: const Color(0xFF4CAF50)),
                      ),
                      Positioned(
                        bottom: 22,
                        left: 22,
                        child: Icon(Icons.electrical_services,
                            size: 20, color: const Color(0xFFE8A020)),
                      ),
                      Positioned(
                        bottom: 20,
                        right: 22,
                        child: Icon(Icons.carpenter,
                            size: 22, color: const Color(0xFF2B4B9B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // ── Hourglass badge ──
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFEDE68), width: 2),
                  ),
                  child: const Center(
                    child: Text('⏳', style: TextStyle(fontSize: 34)),
                  ),
                ),
                const SizedBox(height: 24),
                // ── Title ──
                const Text(
                  'Compte en cours de validation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre compte est en cours de validation par notre équipe. Vous serez notifié par SMS dès que votre profil sera approuvé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                // ── Status card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAB308),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vérification en cours...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Délai estimé : 24 à 48 heures',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // ── Back to welcome button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.go('/welcome'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF3F64B5), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      "Retour à l'accueil",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3F64B5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
