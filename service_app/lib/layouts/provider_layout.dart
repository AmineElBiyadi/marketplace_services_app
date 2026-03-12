import 'package:flutter/material.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_sidebar.dart';

class ProviderLayout extends StatefulWidget {
  final Widget child;
  final bool showBottomNav;
  final String activeRoute;

  const ProviderLayout({
    super.key,
    required this.child,
    this.showBottomNav = true,
    this.activeRoute = '/provider/dashboard',
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
          ? ProviderSidebar(activeRoute: widget.activeRoute, isMobile: true) 
          : null,
      body: Row(
        children: [
          if (!isMobile)
            ProviderSidebar(
              activeRoute: widget.activeRoute,
              isOpen: _sidebarOpen,
              onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String route) {
    switch (route) {
      case '/provider/dashboard':
        return 0;
      case '/provider/agenda':
        return 3; // Based on ProviderBottomNav items
      case '/provider/profile':
        return 4;
      default:
        return 0;
    }
  }
}
