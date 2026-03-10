import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/admin_layout.dart';

class AdminReviewsScreen extends StatelessWidget {
  const AdminReviewsScreen({super.key});

  final List<Map<String, dynamic>> mockReviews = const [
    {'id': 1, 'client': 'Amina B.', 'provider': 'Ahmed K.', 'rating': 5, 'comment': 'Excellent service!', 'date': '2026-03-10'},
    {'id': 2, 'client': 'Omar T.', 'provider': 'Sarah M.', 'rating': 4, 'comment': 'Very good', 'date': '2026-03-09'},
    {'id': 3, 'client': 'Fatima Z.', 'provider': 'Youssef B.', 'rating': 2, 'comment': 'Could be better', 'date': '2026-03-08'},
    {'id': 4, 'client': 'Karim H.', 'provider': 'Nadia F.', 'rating': 5, 'comment': 'Amazing work!', 'date': '2026-03-07'},
  ];

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avis & Réclamations',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestion des avis clients et réclamations',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mockReviews.length,
                  itemBuilder: (context, index) {
                    final review = mockReviews[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.person, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        review['client'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'For: ${review['provider']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 16, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${review['rating']}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(review['comment'] as String),
                          const SizedBox(height: 8),
                          Text(
                            review['date'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
