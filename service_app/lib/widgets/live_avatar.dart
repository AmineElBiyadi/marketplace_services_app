import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class LiveAvatar extends StatelessWidget {
  final String? id;
  final String? fallbackPhoto;
  final String? fallbackName;
  final double radius;
  final String type; // 'expert' or 'client'

  const LiveAvatar({
    super.key,
    required this.id,
    this.fallbackPhoto,
    this.fallbackName,
    this.radius = 20,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (id == null || id!.isEmpty) {
      return _buildPlaceholder(fallbackPhoto, fallbackName);
    }

    final collection = type == 'expert' ? 'experts' : 'utilisateurs';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).doc(id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildPlaceholder(fallbackPhoto, fallbackName);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final livePhoto = data['photo'] ?? data['image_profile'] ?? fallbackPhoto;
        final liveName = data['nom'] ?? fallbackName;

        return _buildAvatar(livePhoto, liveName);
      },
    );
  }

  Widget _buildAvatar(String? photo, String? name) {
    if (photo != null && photo.isNotEmpty && photo.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    
    // Initials logic
    String initials = '?';
    if (name != null && name.isNotEmpty) {
      final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String? photo, String? name) {
    return _buildAvatar(photo, name);
  }
}
