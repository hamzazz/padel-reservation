import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/club.dart';
import '../models/court.dart';
import '../services/auth_service.dart';
import '../services/club_service.dart';
import '../services/geocoding_service.dart';
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
  final _clubSvc = ClubService();
  late TabController _tabs;

  List<AppUser> _users = [];
  List<Club> _clubs = [];
  int _reservationsCount = 0;
  int _tournamentsCount = 0;
  int _productsCount = 0;
  bool _loading = true;

  final _userSearchCtrl = TextEditingController();
  final _courtSearchCtrl = TextEditingController();
  String _userQuery = '';
  String _courtQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _userSearchCtrl.dispose();
    _courtSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _authSvc.getAllUsers(),
      _resSvc.getAll(),
      _tourSvc.getAll(),
      _mktSvc.getAll(),
      _clubSvc.getAll(),
    ]);
    setState(() {
      _users = results[0] as List<AppUser>;
      _reservationsCount = (results[1] as List).length;
      _tournamentsCount = (results[2] as List).length;
      _productsCount = (results[3] as List).length;
      _clubs = results[4] as List<Club>;
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
            Tab(text: 'Dashboard'),
            Tab(text: 'Utilisateurs'),
            Tab(text: 'Terrains'),
            Tab(text: 'Clubs'),
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
                _buildClubs(),
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
    final filtered = _userQuery.isEmpty
        ? _users
        : _users
            .where((u) =>
                u.fullName.toLowerCase().contains(_userQuery) ||
                u.email.toLowerCase().contains(_userQuery) ||
                u.phone.contains(_userQuery))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _userSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, email, téléphone…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _userQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _userSearchCtrl.clear();
                        setState(() => _userQuery = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _userQuery = v.toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text('${filtered.length} utilisateur(s)',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final u = filtered[i];
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
          ),
        ),
      ],
    );
  }

  Widget _buildCourts() {
    final allCourts = context.watch<CourtProvider>().courts;
    final courts = _courtQuery.isEmpty
        ? allCourts
        : allCourts
            .where((c) =>
                c.name.toLowerCase().contains(_courtQuery) ||
                c.address.toLowerCase().contains(_courtQuery))
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
        onPressed: () => _showCourtForm(null),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _courtSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un terrain par nom ou adresse…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _courtQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _courtSearchCtrl.clear();
                          setState(() => _courtQuery = '');
                        })
                    : null,
              ),
              onChanged: (v) => setState(() => _courtQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: courts.isEmpty
                ? const Center(child: Text('Aucun terrain'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
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
                          '${c.pricePerHour.toStringAsFixed(0)} DH/h · ${c.isIndoor ? 'Couvert' : 'Extérieur'} · max ${c.maxReservationsPerSlot}/créneau',
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
          ),
        ],
      ),
    );
  }

  Future<void> _showCourtForm(Court? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.pricePerHour.toStringAsFixed(0) : '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    bool isIndoor = existing?.isIndoor ?? false;
    double? lat = existing?.latitude;
    double? lng = existing?.longitude;
    bool geocoding = false;
    String? geocodeStatus;
    int maxReservationsPerSlot = existing?.maxReservationsPerSlot ?? 1;
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
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(existing == null ? 'Ajouter un terrain' : 'Modifier le terrain',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom du terrain'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
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
                        (v == null || double.tryParse(v) == null) ? 'Prix invalide' : null,
                  ),
                  const SizedBox(height: 10),
                  // ── Adresse + bouton géocodage ──────────────────
                  TextFormField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Adresse complète',
                        hintText: 'Ex: 12 Rue Mohammed V, Casablanca',
                        prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: geocoding
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              lat != null ? Icons.check_circle_outline : Icons.my_location,
                              color: lat != null ? Colors.green : AppTheme.primary),
                      label: Text(
                        geocoding
                            ? 'Localisation en cours…'
                            : lat != null
                                ? 'Localisé ✓'
                                : 'Localiser l\'adresse',
                        style: TextStyle(
                          color: lat != null ? Colors.green : AppTheme.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: lat != null ? Colors.green : AppTheme.primary),
                      ),
                      onPressed: geocoding ? null : () async {
                        final addr = addrCtrl.text.trim();
                        if (addr.isEmpty) {
                          setS(() => geocodeStatus = 'Saisissez une adresse d\'abord');
                          return;
                        }
                        setS(() { geocoding = true; geocodeStatus = null; });
                        final result = await GeocodingService().geocode(addr);
                        if (result != null) {
                          setS(() {
                            lat = result.latitude;
                            lng = result.longitude;
                            geocoding = false;
                            geocodeStatus = '📍 ${result.displayName.split(',').take(3).join(', ')}';
                          });
                        } else {
                          setS(() {
                            geocoding = false;
                            geocodeStatus = '❌ Adresse introuvable. Essayez d\'être plus précis.';
                          });
                        }
                      },
                    ),
                  ),
                  if (geocodeStatus != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (lat != null ? Colors.green : Colors.red).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: (lat != null ? Colors.green : Colors.red).withOpacity(0.2)),
                      ),
                      child: Text(geocodeStatus!,
                          style: TextStyle(
                              fontSize: 12,
                              color: lat != null ? Colors.green.shade700 : Colors.red.shade700)),
                    ),
                  ],
                  if (lat != null && lng != null) ...[
                    const SizedBox(height: 4),
                    Text('Coordonnées : ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  const SizedBox(height: 14),
                  // ── Réservations max par créneau ───────────────────
                  Row(
                    children: [
                      const Icon(Icons.event_available, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Réservations max par créneau :',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.primary,
                        onPressed: maxReservationsPerSlot > 1
                            ? () => setS(() => maxReservationsPerSlot--)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$maxReservationsPerSlot',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppTheme.primary,
                        onPressed: maxReservationsPerSlot < 20
                            ? () => setS(() => maxReservationsPerSlot++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Type ──────────────────────────────────────────
                  Row(
                    children: [
                      const Text('Type : ', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setS(() => isIndoor = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: !isIndoor ? Colors.orange : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Extérieur',
                              style: TextStyle(
                                  color: !isIndoor ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setS(() => isIndoor = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isIndoor ? Colors.blue : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Couvert',
                              style: TextStyle(
                                  color: isIndoor ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(existing == null ? Icons.add : Icons.save),
                    label: Text(existing == null ? 'Ajouter le terrain' : 'Enregistrer'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (lat == null || lng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Veuillez localiser l\'adresse d\'abord'),
                          backgroundColor: Colors.orange,
                        ));
                        return;
                      }
                      final provider = context.read<CourtProvider>();
                      if (existing == null) {
                        await provider.addCourt(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          pricePerHour: double.parse(priceCtrl.text),
                          isIndoor: isIndoor,
                          address: addrCtrl.text.trim(),
                          latitude: lat!,
                          longitude: lng!,
                          maxReservationsPerSlot: maxReservationsPerSlot,
                        );
                      } else {
                        await provider.updateCourt(existing.copyWith(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          pricePerHour: double.parse(priceCtrl.text),
                          isIndoor: isIndoor,
                          address: addrCtrl.text.trim(),
                          latitude: lat!,
                          longitude: lng!,
                          maxReservationsPerSlot: maxReservationsPerSlot,
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

  // ── Clubs ─────────────────────────────────────────────────────────────

  Widget _buildClubs() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau club', style: TextStyle(color: Colors.white)),
        onPressed: () => _showClubForm(null),
      ),
      body: _clubs.isEmpty
          ? const Center(child: Text('Aucun club créé'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: _clubs.length,
              itemBuilder: (ctx, i) {
                final club = _clubs[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sports_tennis,
                          color: Color(0xFF1565C0)),
                    ),
                    title: Text(club.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(club.address,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${club.courtIds.length} terrain(s) assigné(s) · ${club.adminIds.length} admin(s)',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.manage_accounts_outlined,
                              color: Color(0xFF1565C0)),
                          tooltip: 'Gérer',
                          onPressed: () => _showClubDetail(club),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _confirmDeleteClub(club),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showClubForm(Club? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
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
              Text(existing == null ? 'Créer un club' : 'Modifier le club',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nom du club',
                    prefixIcon: Icon(Icons.sports_tennis)),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: addrCtrl,
                decoration: const InputDecoration(
                    labelText: 'Adresse',
                    prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(existing == null ? Icons.add : Icons.save),
                label: Text(existing == null ? 'Créer le club' : 'Enregistrer'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (existing == null) {
                    final club = await _clubSvc.create(
                      name: nameCtrl.text.trim(),
                      address: addrCtrl.text.trim(),
                    );
                    setState(() => _clubs.add(club));
                  } else {
                    final updated = existing.copyWith(
                      name: nameCtrl.text.trim(),
                      address: addrCtrl.text.trim(),
                    );
                    await _clubSvc.update(updated);
                    setState(() {
                      final idx = _clubs.indexWhere((c) => c.id == existing.id);
                      if (idx != -1) _clubs[idx] = updated;
                    });
                  }
                  if (mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      )),
    );
  }

  void _showClubDetail(Club club) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ClubDetailSheet(
        club: club,
        allCourts: context.read<CourtProvider>().courts,
        allUsers: _users,
        clubService: _clubSvc,
        onUpdated: (updated) {
          setState(() {
            final idx = _clubs.indexWhere((c) => c.id == updated.id);
            if (idx != -1) _clubs[idx] = updated;
          });
        },
      ),
    );
  }

  Future<void> _confirmDeleteClub(Club club) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le club'),
        content: Text('Supprimer "${club.name}" ? Les admins perdront leur accès.'),
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
      for (final uid in club.adminIds) {
        await _clubSvc.removeAdmin(club.id, uid);
      }
      await _clubSvc.delete(club.id);
      setState(() => _clubs.removeWhere((c) => c.id == club.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${club.name} supprimé'),
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

// ── Club Detail Sheet ─────────────────────────────────────────────────────────

class _ClubDetailSheet extends StatefulWidget {
  final Club club;
  final List<Court> allCourts;
  final List<AppUser> allUsers;
  final ClubService clubService;
  final ValueChanged<Club> onUpdated;

  const _ClubDetailSheet({
    required this.club,
    required this.allCourts,
    required this.allUsers,
    required this.clubService,
    required this.onUpdated,
  });

  @override
  State<_ClubDetailSheet> createState() => _ClubDetailSheetState();
}

class _ClubDetailSheetState extends State<_ClubDetailSheet> {
  late Club _club;
  AppUser? _selectedUser;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _club = widget.club;
  }

  Future<void> _toggleCourt(String courtId) async {
    setState(() => _saving = true);
    final ids = List<String>.from(_club.courtIds);
    if (ids.contains(courtId)) {
      ids.remove(courtId);
    } else {
      ids.add(courtId);
    }
    await widget.clubService.setCourtIds(_club.id, ids);
    final updated = _club.copyWith(courtIds: ids);
    setState(() {
      _club = updated;
      _saving = false;
    });
    widget.onUpdated(updated);
  }

  Future<void> _addAdmin() async {
    final user = _selectedUser;
    if (user == null) return;
    if (_club.adminIds.contains(user.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déjà admin de ce club')));
      }
      return;
    }
    setState(() => _saving = true);
    await widget.clubService.addAdmin(_club.id, user.id);
    final ids = List<String>.from(_club.adminIds)..add(user.id);
    final updated = _club.copyWith(adminIds: ids);
    setState(() {
      _club = updated;
      _selectedUser = null;
      _saving = false;
    });
    widget.onUpdated(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} nommé admin du club'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeAdmin(String userId) async {
    setState(() => _saving = true);
    await widget.clubService.removeAdmin(_club.id, userId);
    final ids = List<String>.from(_club.adminIds)..remove(userId);
    final updated = _club.copyWith(adminIds: ids);
    setState(() {
      _club = updated;
      _saving = false;
    });
    widget.onUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final adminUsers = widget.allUsers
        .where((u) => _club.adminIds.contains(u.id))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.sports_tennis, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_club.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (_saving)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // ── Terrains ──────────────────────────────────────
                const Text('Terrains du club',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ...widget.allCourts.map((court) {
                  final assigned = _club.courtIds.contains(court.id);
                  return CheckboxListTile(
                    value: assigned,
                    onChanged: (_) => _toggleCourt(court.id),
                    title: Text(court.name),
                    subtitle: Text(
                        '${court.pricePerHour.toStringAsFixed(0)} DH/h · ${court.isIndoor ? 'Couvert' : 'Extérieur'}',
                        style: const TextStyle(fontSize: 12)),
                    activeColor: const Color(0xFF1565C0),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const Divider(height: 24),
                // ── Admins ────────────────────────────────────────
                const Text('Administrateurs du club',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (adminUsers.isEmpty)
                  Text('Aucun admin assigné',
                      style: TextStyle(color: Colors.grey.shade600)),
                ...adminUsers.map((u) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF1565C0).withOpacity(0.1),
                        child: Text(u.avatarEmoji),
                      ),
                      title: Text(u.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(u.email,
                          style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove_outlined,
                            color: Colors.red),
                        onPressed: () => _removeAdmin(u.id),
                      ),
                    )),
                const SizedBox(height: 10),
                _UserPickerDropdown(
                  users: widget.allUsers
                      .where((u) =>
                          !u.isAdmin && !_club.adminIds.contains(u.id))
                      .toList(),
                  selected: _selectedUser,
                  onChanged: (u) => setState(() => _selectedUser = u),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Assigner comme admin'),
                  onPressed: _selectedUser == null ? null : _addAdmin,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      minimumSize: const Size(double.infinity, 48)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPickerDropdown extends StatefulWidget {
  final List<AppUser> users;
  final AppUser? selected;
  final ValueChanged<AppUser?> onChanged;

  const _UserPickerDropdown({
    required this.users,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_UserPickerDropdown> createState() => _UserPickerDropdownState();
}

class _UserPickerDropdownState extends State<_UserPickerDropdown> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users
        .where((u) =>
            u.fullName.toLowerCase().contains(_query) ||
            u.email.toLowerCase().contains(_query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: 'Rechercher un utilisateur',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
        ),
        if (widget.selected != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(widget.selected!.avatarEmoji,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.selected!.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(widget.selected!.email,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => widget.onChanged(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        if (_query.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Aucun utilisateur trouvé',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (ctx, i) {
                      final u = filtered[i];
                      final isSelected = widget.selected?.id == u.id;
                      return ListTile(
                        dense: true,
                        leading: Text(u.avatarEmoji,
                            style: const TextStyle(fontSize: 20)),
                        title: Text(u.fullName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(u.email,
                            style: const TextStyle(fontSize: 11)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF1565C0), size: 18)
                            : null,
                        onTap: () {
                          widget.onChanged(u);
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
