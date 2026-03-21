import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';

class ProviderStatisticsScreen extends StatefulWidget {
  final String expertId;

  const ProviderStatisticsScreen({Key? key, required this.expertId}) : super(key: key);

  @override
  State<ProviderStatisticsScreen> createState() => _ProviderStatisticsScreenState();
}

class _ProviderStatisticsScreenState extends State<ProviderStatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/profile',
      expertId: widget.expertId,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            "Statistiques",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: false,
        ),
        body: StreamBuilder<bool>(
          stream: _firestoreService.isExpertPremium(widget.expertId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final isPremium = snapshot.data ?? false;

            if (!isPremium) {
              return _buildLockedPremiumState(context);
            }

            // Normal statistics if premium
            return _buildPremiumStatistics();
          },
        ),
      ),
    );
  }

  Widget _buildLockedPremiumState(BuildContext context) {
    return Stack(
      children: [
        // Fake background content to blur
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildFakeStatCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFakeStatCard()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildFakeStatCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFakeStatCard()),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
        
        // Blur effect
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),

        // Locked content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.lock,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Disponible avec le pack Premium",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Accédez aux statistiques avancées pour booster votre activité",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/provider/${widget.expertId}/subscription');
                    },
                    icon: const Icon(LucideIcons.crown, color: Colors.white, size: 20),
                    label: const Text(
                      "Passer Premium",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFakeStatCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 10, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Container(width: 80, height: 20, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Container(width: 60, height: 10, color: Colors.grey[200]),
        ],
      ),
    );
  }

  Widget _buildPremiumStatistics() {
    return Center(
      child: Text(
        "Statistiques détaillées à venir...",
        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
      ),
    );
  }
}
