import 'package:flutter/material.dart';
import '../smart_image.dart';

class TopRatedCard extends StatelessWidget {
  final String name;
  final String services;
  final double rating;
  final String imageUrl;
  final bool isPremium;
  final VoidCallback onChat;
  final VoidCallback onTap;

  const TopRatedCard({
    super.key,
    required this.name,
    required this.services,
    required this.rating,
    required this.imageUrl,
    required this.onChat,
    required this.onTap,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Photo
            SmartImage(
              source: imageUrl,
              width: 60,
              height: 60,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 4),
                        const Text('👑', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  Text(
                    services,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(
                        rating.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bouton chat
            IconButton(
              onPressed: onChat,
              icon: Icon(
                Icons.chat_bubble_outline,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}