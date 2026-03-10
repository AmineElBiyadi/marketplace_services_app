import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;

  const AdminLayout({
    super.key,
    required this.child,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _sidebarOpen = true;
  bool _mobileMenuOpen = false;
  bool _notifOpen = false;

  final List<_NavItem> _sidebarItems = const [
    _NavItem(label: 'Tableau de bord', icon: Icons.home, path: '/admin/dashboard'),
    _NavItem(label: 'Utilisateurs', icon: Icons.people, path: '/admin/users'),
    _NavItem(label: 'Prestataires', icon: Icons.build, path: '/admin/providers'),
    _NavItem(label: 'Réservations', icon: Icons.calendar_today, path: '/admin/reservations'),
    _NavItem(label: 'Avis & Réclamations', icon: Icons.star, path: '/admin/reviews'),
    _NavItem(label: 'Finances', icon: Icons.attach_money, path: '/admin/finances'),
    _NavItem(label: 'Statistiques', icon: Icons.bar_chart, path: '/admin/statistics'),
    _NavItem(label: 'Paramètres', icon: Icons.settings, path: '/admin/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.foreground,
          foregroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              setState(() {
                _mobileMenuOpen = !_mobileMenuOpen;
              });
            },
          ),
          title: Row(
            children: [
              Icon(Icons.shield, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Admin',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.destructive,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () {
                setState(() {
                  _notifOpen = !_notifOpen;
                });
              },
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16, left: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Text('SA', style: TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            widget.child,
            if (_mobileMenuOpen)
              GestureDetector(
                onTap: () => setState(() => _mobileMenuOpen = false),
                child: Container(
                  color: Colors.black54,
                  child: _buildSidebar(isMobile: true),
                ),
              ),
            if (_notifOpen)
              _buildNotificationPopup(),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _sidebarOpen ? 260 : 70,
            child: _buildSidebar(isMobile: false),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isMobile: false),
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar({required bool isMobile}) {
    return Container(
      color: AppColors.foreground,
      child: Column(
        children: [
          // Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.background.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                if (isMobile || _sidebarOpen)
                  Row(
                    children: [
                      Icon(Icons.shield, color: AppColors.primary, size: 28),
                      const SizedBox(width: 8),
                      if (isMobile || _sidebarOpen)
                        const Text(
                          'Admin',
                          style: TextStyle(
                            color: AppColors.background,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                if (!isMobile)
                  IconButton(
                    icon: Icon(
                      _sidebarOpen ? Icons.close : Icons.menu,
                      color: AppColors.background.withOpacity(0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _sidebarOpen = !_sidebarOpen;
                      });
                    },
                  ),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) {
                final item = _sidebarItems[index];
                final location = GoRouterState.of(context).matchedLocation;
                final isActive = location == item.path;

                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.background.withOpacity(0.6),
                    size: 22,
                  ),
                  title: (isMobile || _sidebarOpen)
                      ? Text(
                          item.label,
                          style: TextStyle(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.background.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  tileColor: isActive ? AppColors.primary : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    context.go(item.path);
                    if (isMobile) {
                      setState(() {
                        _mobileMenuOpen = false;
                      });
                    }
                  },
                );
              },
            ),
          ),
          // Logout
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.background.withOpacity(0.1)),
              ),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.destructive,
                size: 22,
              ),
              title: (isMobile || _sidebarOpen)
                  ? const Text(
                      'Déconnexion',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => context.go('/admin/login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({required bool isMobile}) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.muted.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          GestureDetector(
            onTap: () {
              setState(() {
                _notifOpen = !_notifOpen;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined, size: 20),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.destructive,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '4',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'SA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (_sidebarOpen) ...[
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Super Admin',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPopup() {
    final notifications = [
      _Notification(id: 1, text: 'Nouveau prestataire à valider', type: 'warning', time: 'Il y a 5 min'),
      _Notification(id: 2, text: 'Réclamation urgente déposée', type: 'error', time: 'Il y a 20 min'),
      _Notification(id: 3, text: 'Paiement abonnement échoué', type: 'warning', time: 'Il y a 1h'),
      _Notification(id: 4, text: 'Rapport mensuel disponible', type: 'info', time: 'Il y a 3h'),
    ];

    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Tout lire',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  Color dotColor;
                  switch (notif.type) {
                    case 'error':
                      dotColor = AppColors.destructive;
                      break;
                    case 'warning':
                      dotColor = AppColors.accent;
                      break;
                    default:
                      dotColor = AppColors.primary;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                notif.time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            InkWell(
              onTap: () {
                context.go('/admin/notifications');
                setState(() {
                  _notifOpen = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: const Text(
                  'Voir toutes →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String path;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}

class _Notification {
  final int id;
  final String text;
  final String type;
  final String time;

  _Notification({
    required this.id,
    required this.text,
    required this.type,
    required this.time,
  });
}
