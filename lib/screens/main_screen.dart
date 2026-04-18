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
    if (_index != 0) return null;
    return PreferredSize(
      preferredSize: const Size.fromHeight(62),
      child: AppBar(
        toolbarHeight: 62,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🎾', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Padel Club',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3)),
                if (auth.currentUser != null)
                  Text('Bonjour, ${auth.currentUser!.firstName} 👋',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          _iconBtn(
            Icons.calendar_month_outlined,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReservationsScreen())),
          ),
          _notifBtn(unread),
          if (auth.isAdmin)
            _iconBtn(
              Icons.admin_panel_settings_outlined,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminScreen())),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _notifBtn(int unread) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 22),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Text(unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
        ],
      ),
    );
  }
}
