import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? imagePath;
  final VoidCallback onTap;
  final bool isSelected;

  const CategoryCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.imagePath,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3D5A99)
                  : _getPastelColor(label).withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                      ? const Color(0xFF3D5A99).withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: imagePath != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        imagePath!,
                        fit: BoxFit.contain,
                        color: isSelected
                            ? const Color(0xFF3D5A99)
                            : _getPastelColor(label),
                        colorBlendMode: BlendMode.multiply,
                      ),
                    )
                  : Icon(
                      icon,
                      color: isSelected ? Colors.white : _getIconColor(label),
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF3D5A99) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPastelColor(String label) {
    switch (label.toLowerCase()) {
      case 'plumbing':
      case 'plomberie':
        return const Color(0xFFE3F2FD);
      case 'electricity':
      case 'électricité':
        return const Color(0xFFFFFDE7);
      case 'cleaning':
      case 'nettoyage':
        return const Color(0xFFE8F5E9);
      case 'gardening':
      case 'jardinage':
        return const Color(0xFFF1F8E9);
      case 'hair':
      case 'coiffure':
        return const Color(0xFFFCE4EC);
      default:
        return Colors.blue.shade50;
    }
  }

  Color _getIconColor(String label) {
    switch (label.toLowerCase()) {
      case 'plumbing':
      case 'plomberie':
        return const Color(0xFF1E88E5);
      case 'electricity':
      case 'électricité':
        return const Color(0xFFFDD835);
      case 'cleaning':
      case 'nettoyage':
        return const Color(0xFF43A047);
      case 'gardening':
      case 'jardinage':
        return const Color(0xFF7CB342);
      case 'hair':
      case 'coiffure':
        return const Color(0xFFD81B60);
      default:
        return Colors.blue.shade700;
    }
  }
}