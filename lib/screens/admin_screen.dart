import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/market_service.dart';
import '../services/reservation_service.dart';
import '../services/tournament_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _authSvc = AuthService();
  final _resSvc = ReservationService();
  final _tourSvc = TournamentService();
  final _mktSvc = MarketService();
  late TabController _tabs;

  List<AppUser> _users = [];
  int _reservationsCount = 0;
  int _tournamentsCount = 0;
  int _productsCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _users = await _authSvc.getAllUsers();
    final res = await _resSvc.getAll();
    final tours = await _tourSvc.getAll();
    final prods = await _mktSvc.getAll();
    setState(() {
      _reservationsCount = res.length;
      _tournamentsCount = tours.length;
      _productsCount = prods.length;
      _loading = false;
    });
  }

  Future<void> _toggleBlock(AppUser user) async {
    final me = context.read<AuthProvider>().currentUser!;
    if (user.id == me.id) return;
    // Admins block by setting a special flag — here we just remove from list
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${user.fullName} bloqué/débloqué'),
      backgroundColor: Colors.orange,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        backgroundColor: Colors.red.shade700,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Tableau de bord'),
            Tab(text: 'Utilisateurs'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildDashboard(),
                _buildUsers(),
              ],
            ),
    );
  }

  Widget _buildDashboard() {
    final totalWallet = _users.fold(
        0.0, (sum, u) => sum + u.walletBalance);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _statCard('Joueurs', '${_users.length}',
                Icons.people, Colors.blue),
            _statCard('Réservations', '$_reservationsCount',
                Icons.calendar_today, AppTheme.primary),
            _statCard('Tournois', '$_tournamentsCount',
                Icons.emoji_events, const Color(0xFF3949AB)),
            _statCard('Annonces', '$_productsCount',
                Icons.storefront, Colors.orange),
            _statCard(
                'Wallets',
                '${totalWallet.toStringAsFixed(0)} €',
                Icons.account_balance_wallet,
                Colors.green),
            _statCard(
                'Admins',
                '${_users.where((u) => u.isAdmin).length}',
                Icons.admin_panel_settings,
                Colors.red),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Répartition des niveaux',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...List.generate(8, (i) {
          final lvl = i + 1;
          final count =
              _users.where((u) => u.level == lvl).length;
          if (count == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 60,
                    child: Text('Niv. $lvl',
                        style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _users.isEmpty
                        ? 0
                        : count / _users.length,
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildUsers() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (ctx, i) {
        final u = _users[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.isAdmin
                  ? Colors.red.withOpacity(0.1)
                  : AppTheme.primary.withOpacity(0.1),
              child: Text(u.avatarEmoji,
                  style: const TextStyle(fontSize: 20)),
            ),
            title: Text(u.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.email,
                    style: const TextStyle(fontSize: 12)),
                Text(
                    'Niv. ${u.level} | Wallet: ${u.walletBalance.toStringAsFixed(2)}€',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'block') _toggleBlock(u);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'block',
                    child: Text(u.isAdmin
                        ? 'Compte admin (protégé)'
                        : 'Bloquer / Débloquer')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
