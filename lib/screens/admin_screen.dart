import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/court.dart';
import '../services/auth_service.dart';
import '../services/market_service.dart';
import '../services/reservation_service.dart';
import '../services/tournament_service.dart';
import '../state/auth_provider.dart';
import '../state/court_provider.dart';
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
    _tabs = TabController(length: 3, vsync: this);
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
    if (user.id == me.id || user.isAdmin) return;

    final willBlock = !user.isBlockedByAdmin;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willBlock ? 'Bloquer l\'utilisateur' : 'Débloquer l\'utilisateur'),
        content: Text(willBlock
            ? 'Bloquer ${user.fullName} ? Il ne pourra plus se connecter.'
            : 'Débloquer ${user.fullName} ? Il pourra à nouveau se connecter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? Colors.red : Colors.green,
            ),
            child: Text(willBlock ? 'Bloquer' : 'Débloquer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (willBlock) {
      await context.read<AuthProvider>().adminBlockUser(user);
    } else {
      await context.read<AuthProvider>().adminUnblockUser(user);
    }

    setState(() {
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = user.copyWith(isBlockedByAdmin: willBlock);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(willBlock
            ? '${user.fullName} bloqué'
            : '${user.fullName} débloqué'),
        backgroundColor: willBlock ? Colors.red : Colors.green,
      ));
    }
  }

  void _showUserDetail(AppUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UserDetailSheet(
        user: user,
        onToggleBlock: () {
          Navigator.pop(ctx);
          _toggleBlock(user);
        },
      ),
    );
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
            Tab(text: 'Terrains'),
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
                _buildCourts(),
              ],
            ),
    );
  }

  Widget _buildDashboard() {
    final totalWallet = _users.fold(0.0, (sum, u) => sum + u.walletBalance);
    final blockedCount = _users.where((u) => u.isBlockedByAdmin).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _statCard('Joueurs', '${_users.length}', Icons.people, Colors.blue),
            _statCard('Réservations', '$_reservationsCount',
                Icons.calendar_today, AppTheme.primary),
            _statCard('Tournois', '$_tournamentsCount',
                Icons.emoji_events, const Color(0xFF3949AB)),
            _statCard('Annonces', '$_productsCount',
                Icons.storefront, Colors.orange),
            _statCard('Wallets', '${totalWallet.toStringAsFixed(0)} DH',
                Icons.account_balance_wallet, Colors.green),
            _statCard('Bloqués', '$blockedCount',
                Icons.block, Colors.red),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Répartition des niveaux',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...List.generate(8, (i) {
          final lvl = i + 1;
          final count = _users.where((u) => u.level == lvl).length;
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
                    value: _users.isEmpty ? 0 : count / _users.length,
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
    final me = context.read<AuthProvider>().currentUser;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (ctx, i) {
        final u = _users[i];
        final isMe = u.id == me?.id;
        final isBlocked = u.isBlockedByAdmin;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _showUserDetail(u),
            leading: CircleAvatar(
              backgroundColor: isBlocked
                  ? Colors.red.withOpacity(0.1)
                  : u.isAdmin
                      ? Colors.orange.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
              child: Text(u.avatarEmoji, style: const TextStyle(fontSize: 20)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(u.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (isBlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Bloqué',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                  ),
                if (u.isAdmin)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Admin',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.email, style: const TextStyle(fontSize: 12)),
                Text('Niv. ${u.level} | Wallet: ${u.walletBalance.toStringAsFixed(2)}DH',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            isThreeLine: true,
            trailing: isMe || u.isAdmin
                ? const Icon(Icons.info_outline, color: Colors.grey, size: 20)
                : PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'block') _toggleBlock(u);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(
                              isBlocked ? Icons.lock_open : Icons.block,
                              color: isBlocked ? Colors.green : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(isBlocked ? 'Débloquer' : 'Bloquer'),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCourts() {
    final courts = context.watch<CourtProvider>().courts;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
        onPressed: () => _showCourtForm(null),
      ),
      body: courts.isEmpty
          ? const Center(child: Text('Aucun terrain'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: courts.length,
              itemBuilder: (ctx, i) {
                final c = courts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.isIndoor
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        c.isIndoor ? Icons.home_outlined : Icons.wb_sunny_outlined,
                        color: c.isIndoor ? Colors.blue : Colors.orange,
                      ),
                    ),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.address,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${c.pricePerHour.toStringAsFixed(0)} DH/h · ${c.isIndoor ? 'Couvert' : 'Extérieur'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppTheme.primary),
                          onPressed: () => _showCourtForm(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _confirmDeleteCourt(c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showCourtForm(Court? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.pricePerHour.toStringAsFixed(0) : '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final latCtrl = TextEditingController(
        text: existing != null ? existing.latitude.toString() : '');
    final lngCtrl = TextEditingController(
        text: existing != null ? existing.longitude.toString() : '');
    bool isIndoor = existing?.isIndoor ?? false;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(existing == null ? 'Ajouter un terrain' : 'Modifier le terrain',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom du terrain'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Prix par heure (DH)',
                        prefixIcon: Icon(Icons.monetization_on_outlined)),
                    validator: (v) =>
                        (v == null || double.tryParse(v) == null)
                            ? 'Prix invalide'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Adresse',
                        prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Latitude'),
                          validator: (v) =>
                              (v == null || double.tryParse(v) == null)
                                  ? 'Invalide'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: lngCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Longitude'),
                          validator: (v) =>
                              (v == null || double.tryParse(v) == null)
                                  ? 'Invalide'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Type : ',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setS(() => isIndoor = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: !isIndoor
                                ? Colors.orange
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Extérieur',
                              style: TextStyle(
                                  color: !isIndoor
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setS(() => isIndoor = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isIndoor
                                ? Colors.blue
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Couvert',
                              style: TextStyle(
                                  color: isIndoor
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(existing == null ? Icons.add : Icons.save),
                    label: Text(existing == null
                        ? 'Ajouter le terrain'
                        : 'Enregistrer les modifications'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final provider = context.read<CourtProvider>();
                      if (existing == null) {
                        await provider.addCourt(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          pricePerHour: double.parse(priceCtrl.text),
                          isIndoor: isIndoor,
                          address: addrCtrl.text.trim(),
                          latitude: double.parse(latCtrl.text),
                          longitude: double.parse(lngCtrl.text),
                        );
                      } else {
                        await provider.updateCourt(existing.copyWith(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          pricePerHour: double.parse(priceCtrl.text),
                          isIndoor: isIndoor,
                          address: addrCtrl.text.trim(),
                          latitude: double.parse(latCtrl.text),
                          longitude: double.parse(lngCtrl.text),
                        ));
                      }
                      if (mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCourt(Court court) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le terrain'),
        content: Text('Supprimer "${court.name}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<CourtProvider>().deleteCourt(court.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${court.name} supprimé'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
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
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  final AppUser user;
  final VoidCallback onToggleBlock;

  const _UserDetailSheet({required this.user, required this.onToggleBlock});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // Avatar + name
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: user.isBlockedByAdmin
                      ? Colors.red.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(user.avatarEmoji,
                      style: const TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(user.email,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (user.isAdmin)
                          _badge('Admin', Colors.orange),
                        if (user.isBlockedByAdmin) ...[
                          const SizedBox(width: 6),
                          _badge('Bloqué', Colors.red),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Info grid
          _infoRow(Icons.phone, 'Téléphone', user.phone.isEmpty ? 'Non renseigné' : user.phone),
          _infoRow(Icons.sports_tennis, 'Niveau', levelLabels[user.level]),
          _infoRow(Icons.account_balance_wallet, 'Wallet',
              '${user.walletBalance.toStringAsFixed(2)} DH'),
          _infoRow(Icons.people, 'Amis', '${user.friendIds.length} ami(s)'),
          _infoRow(Icons.calendar_today, 'Membre depuis',
              DateFormat('dd/MM/yyyy').format(user.createdAt)),
          if (user.subscriptionType != null)
            _infoRow(Icons.card_membership, 'Abonnement',
                user.subscriptionType!.toUpperCase()),
          const SizedBox(height: 16),
          if (!user.isAdmin)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                    user.isBlockedByAdmin ? Icons.lock_open : Icons.block),
                label: Text(user.isBlockedByAdmin
                    ? 'Débloquer le compte'
                    : 'Bloquer le compte'),
                onPressed: onToggleBlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      user.isBlockedByAdmin ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text('$label : ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
