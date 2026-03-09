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
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3D5A99)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(18),
              border: isSelected
                  ? Border.all(color: const Color(0xFF3D5A99), width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.blue.shade700,
              size: 32,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF3D5A99)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}