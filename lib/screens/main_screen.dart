import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'matches_screen.dart';
import 'market_screen.dart';
import 'tournaments_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'admin_screen.dart';
import 'club_admin_screen.dart';
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
    ReservationsScreen(),
    TournamentsScreen(),
    MarketScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final unread = auth.unreadNotifs;

    return Scaffold(
      appBar: _index == 0 ? _buildAppBar(auth, unread, locale) : null,
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: () => setState(() => _index = 0),
        child: Icon(
          Icons.home_rounded,
          color: _index == 0 ? Colors.white : Colors.white70,
          size: 30,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(locale),
    );
  }

  Widget _buildBottomBar(LocaleProvider locale) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 64,
      color: Colors.white,
      child: Row(
        children: [
          _navBtn(Icons.sports_tennis_outlined, Icons.sports_tennis,
              locale.tr('matches'), 1),
          _navBtn(Icons.event_note_outlined, Icons.event_note,
              'Réservations', 2),
          const Expanded(child: SizedBox()), // FAB notch
          _navBtn(Icons.emoji_events_outlined, Icons.emoji_events,
              locale.tr('tournaments'), 3),
          _navBtn(Icons.storefront_outlined, Icons.storefront,
              locale.tr('market'), 4),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, IconData activeIcon, String label, int idx) {
    final active = _index == idx;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _index = idx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? AppTheme.primary : Colors.grey.shade500,
                size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    color: active ? AppTheme.primary : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      AuthProvider auth, int unread, LocaleProvider locale) {
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
                Text(locale.tr('appName'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3)),
                if (auth.currentUser != null)
                  Text(
                      '${locale.locale == 'ar' ? 'مرحباً' : locale.locale == 'en' ? 'Hello' : 'Bonjour'}, ${auth.currentUser!.firstName} 👋',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          // Profile
          _iconBtn(
            Icons.person_outline,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          // Notifications
          _notifBtn(unread),
          // Club admin
          if (auth.isClubAdmin) _clubAdminBtn(),
          // Super admin
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

  Widget _clubAdminBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ClubAdminScreen())),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.manage_accounts_outlined,
                  color: Colors.white, size: 22),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: AppTheme.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.settings, color: Colors.white, size: 8),
                ),
              ),
            ],
          ),
        ),
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
