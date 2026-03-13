import 'package:flutter/material.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_sidebar.dart';

class ProviderLayout extends StatefulWidget {
  final Widget child;
  final bool showBottomNav;
  final String activeRoute;
  final String expertId;

  const ProviderLayout({
    super.key,
    required this.child,
    this.showBottomNav = true,
    this.activeRoute = '/provider/dashboard',
    required this.expertId,
  });

  @override
  State<ProviderLayout> createState() => _ProviderLayoutState();
}

class _ProviderLayoutState extends State<ProviderLayout> {
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      drawer: isMobile 
          ? ProviderSidebar(
              activeRoute: widget.activeRoute, 
              isMobile: true,
              expertId: widget.expertId,
            ) 
          : null,
      body: Row(
        children: [
          if (!isMobile)
            ProviderSidebar(
              activeRoute: widget.activeRoute,
              isOpen: _sidebarOpen,
              onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
              expertId: widget.expertId,
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: widget.child,
                ),
                if (isMobile && widget.showBottomNav)
                  ProviderBottomNav(
                    currentIndex: _getSelectedIndex(widget.activeRoute),
                    expertId: widget.expertId,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String route) {
    if (route.endsWith('/messages')) {
      return 4;
    }
    
    switch (route) {
      case '/provider/dashboard':
        return 0;
      case '/provider/services':
        return 1;
      case '/provider/bookings':
        return 2;
      case '/provider/agenda':
        return 3;
      case '/provider/profile':
        return 5;
      default:
        if (route.endsWith('/dashboard')) return 0;
        if (route.endsWith('/services')) return 1;
        if (route.endsWith('/bookings')) return 2;
        if (route.endsWith('/agenda')) return 3;
        if (route.endsWith('/messages')) return 4;
        if (route.endsWith('/profile')) return 5;
        return 0;
    }
  }
}
