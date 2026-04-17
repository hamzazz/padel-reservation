import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'matches_screen.dart';
import 'market_screen.dart';
import 'tournaments_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'admin_screen.dart';
import 'reservations_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    MatchesScreen(),
    MarketScreen(),
    TournamentsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final unread = auth.unreadNotifs;

    return Scaffold(
      appBar: _buildAppBar(auth, unread),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_tennis_outlined),
            selectedIcon:
                Icon(Icons.sports_tennis, color: AppTheme.primary),
            label: 'Matchs',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon:
                Icon(Icons.storefront, color: AppTheme.primary),
            label: 'Marché',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon:
                Icon(Icons.emoji_events, color: AppTheme.primary),
            label: 'Tournois',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(AuthProvider auth, int unread) {
    // Only show AppBar on home tab
    if (_index != 0) return null;
    return AppBar(
      title: const Text('🎾 Padel Club',
          style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Mes réservations',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ReservationsScreen())),
        ),
        // Notifications bell
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
        if (auth.isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Administration',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            ),
          ),
      ],
    );
  }
}
