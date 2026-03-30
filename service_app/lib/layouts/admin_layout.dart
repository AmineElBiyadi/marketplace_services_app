import 'package:flutter/material.dart';
import '../widgets/admin_sidebar.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final String activeRoute;

  const AdminLayout({
    super.key,
    required this.child,
    required this.activeRoute,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      drawer: isMobile 
          ? SafeArea(
              top: true,
              bottom: true,
              child: AdminSidebar(activeRoute: widget.activeRoute, isMobile: true),
            )
          : null,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          if (!isMobile)
            AdminSidebar(
              activeRoute: widget.activeRoute,
              isOpen: _sidebarOpen,
              onToggle: () => setState(() => _sidebarOpen = !_sidebarOpen),
            ),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
