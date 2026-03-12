import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../screens/chat/chat_list_screen.dart';

class ProviderBottomNav extends StatelessWidget {
  final int currentIndex;
  final String expertId;

  const ProviderBottomNav({
    Key? key,
    required this.currentIndex,
    required this.expertId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/provider/dashboard');
              break;
            case 1:
              context.go('/provider/agenda');
              break;
            case 2:
              // Messages: push ChatListScreen for the expert
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatListScreen(
                    currentUserRole: 'expert',
                    expertId: expertId,
                  ),
                ),
              );
              break;
            case 3:
              context.go('/provider/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Messages'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

