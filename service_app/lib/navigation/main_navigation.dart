import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/client/home_screen.dart';
import '../screens/client/search_screen.dart';
import '../screens/client/bookings_screen.dart';
import '../screens/client/profile_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../services/chat_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  String _clientId = '';
  bool _isLoading = true;
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _loadClientId();
  }

  Future<void> _loadClientId() async {
    final id = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (mounted) {
      setState(() {
        _clientId = id;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      const HomeScreen(),
      const SearchScreen(),
      const ChatListScreen(currentUserRole: 'client'),
      BookingsScreen(clientId: _clientId),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF3D5A99),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: _chatService.getTotalUnreadCount('client'),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.chat_bubble_outline),
                );
              },
            ),
            activeIcon: StreamBuilder<int>(
              stream: _chatService.getTotalUnreadCount('client'),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.chat_bubble),
                );
              },
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}