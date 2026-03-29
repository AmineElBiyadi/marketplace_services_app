import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
    return SafeArea(
      top: false,
      child: Container(
        height: 70, // Slight height adjustment
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
          elevation: 0, // Elevation is handled by Container
          backgroundColor: Colors.transparent, // Background is handled by Container
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/provider/$expertId/dashboard');
                break;
              case 1:
                context.go('/provider/$expertId/services');
                break;
              case 2:
                context.go('/provider/$expertId/bookings');
                break;
              case 3:
                context.go('/provider/$expertId/agenda');
                break;
              case 4:
                context.go('/provider/$expertId/messages');
                break;
              case 5:
                context.go('/provider/$expertId/profile');
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: const Color(0xFF64748B),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Services'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Bookings'),
            BottomNavigationBarItem(
                icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: 'Agenda'),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.messageSquare), activeIcon: Icon(Icons.message), label: 'Messages'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

