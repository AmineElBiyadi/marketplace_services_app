import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const CategoryCard({
    Key? key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3D5A99)
                  : _getPastelColor(label),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : _getIconColor(label),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF3D5A99) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPastelColor(String label) {
    switch (label.toLowerCase()) {
      case 'plomberie':
        return const Color(0xFFE3F2FD);
      case 'électricité':
        return const Color(0xFFFFFDE7);
      case 'nettoyage':
        return const Color(0xFFE8F5E9);
      case 'jardinage':
        return const Color(0xFFF1F8E9);
      case 'coiffure':
        return const Color(0xFFFCE4EC);
      default:
        return Colors.blue.shade50;
    }
  }

  Color _getIconColor(String label) {
    switch (label.toLowerCase()) {
      case 'plomberie':
        return const Color(0xFF1976D2);
      case 'électricité':
        return const Color(0xFFFBC02D);
      case 'nettoyage':
        return const Color(0xFF2E7D32);
      case 'jardinage':
        return const Color(0xFF558B2F);
      case 'coiffure':
        return const Color(0xFFC2185B);
      default:
        return Colors.blue.shade700;
    }
  }
}