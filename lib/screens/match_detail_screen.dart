import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/match.dart';
import '../services/auth_service.dart';
import '../services/match_service.dart';
import '../services/notification_service.dart';
import '../services/user_preferences.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/court_painter.dart';
import 'payment_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final _service = MatchService();
  Match? _match;
  String? _currentPlayerName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final name = await UserPreferences.getPlayerName();
    final m = await _service.getById(widget.matchId);
    setState(() {
      _currentPlayerName = name;
      _match = m;
      _loading = false;
    });
  }

  Future<void> _reload() async {
    final m = await _service.getById(widget.matchId);
    setState(() => _match = m);
  }

  MatchPlayer? get _myPlayer {
    if (_match == null || _currentPlayerName == null) return null;
    final lower = _currentPlayerName!.toLowerCase();
    try {
      return _match!.players
          .firstWhere((p) => p.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  bool get _isAlreadyIn => _myPlayer != null;

  Future<void> _joinMatch() async {
    final nameCtrl =
        TextEditingController(text: _currentPlayerName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rejoindre le match'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person),
            hintText: 'Votre nom',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, nameCtrl.text.trim()),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    await UserPreferences.setPlayerName(name);
    setState(() => _currentPlayerName = name);

    final player = MatchPlayer(
      id: const Uuid().v4(),
      name: name,
      hasPaid: false,
      joinedAt: DateTime.now(),
    );

    final ok = await _service.joinMatch(widget.matchId, player);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Vous avez rejoint le match !'
          : 'Impossible — match complet ou déjà inscrit'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) _reload();
  }

  Future<void> _inviteFriend() async {
    final me = context.read<AuthProvider>().currentUser;

    // Load all users, exclude self + already in match
    final authSvc = AuthService();
    final allUsers = await authSvc.getAllUsers();
    final available = allUsers
        .where((u) => u.id != me?.id)
        .where((u) => !(_match?.players
            .any((p) => p.name.toLowerCase() == u.fullName.toLowerCase()) ?? false))
        .toList();

    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tous les joueurs sont déjà dans ce match')));
      return;
    }

    // Split: friends first, then others
    final friendIds = me?.friendIds ?? [];
    final friends = available.where((u) => friendIds.contains(u.id)).toList();
    final others = available.where((u) => !friendIds.contains(u.id)).toList();
    final sorted = [...friends, ...others];

    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _InviteSheet(
        users: sorted,
        friendIds: friendIds,
      ),
    );

    if (selected == null || !mounted) return;

    await NotificationService().push(
      userId: selected.id,
      title: 'Invitation au match 🎾',
      body: '${me?.fullName ?? 'Quelqu\'un'} vous a invité à rejoindre un match sur ${_match?.courtName ?? 'un terrain'}. Rejoignez-le depuis l\'onglet Matches !',
      type: 'match_invite',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Invitation envoyée à ${selected.fullName} !'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _pay(MatchPlayer player) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          amount: _match!.pricePerPlayer,
          matchName: _match!.courtName,
          playerName: player.name,
        ),
      ),
    );
    if (result == true) {
      await _service.payForMatch(widget.matchId, player.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match introuvable')),
        body: const Center(child: Text('Ce match n\'existe plus.')),
      );
    }

    final match = _match!;
    final myPlayer = _myPlayer;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF0D47A1),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(match.courtName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              background: buildCourtSliverBackground(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusBanner(match),
                  const SizedBox(height: 16),
                  _infoCard(match),
                  const SizedBox(height: 16),
                  _playersCard(match, myPlayer),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(match, myPlayer),
    );
  }

  Widget _statusBanner(Match match) {
    final color = match.isFull ? Colors.orange : const Color(0xFF1565C0);
    final icon = match.isFull ? Icons.lock : Icons.lock_open;
    final text = match.isFull
        ? 'Match complet'
        : '${match.availableSpots} place(s) disponible(s)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoCard(Match match) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Détails du match',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _row(Icons.person, 'Organisateur', match.organizerName),
            _row(
              Icons.calendar_today,
              'Date',
              DateFormat('EEEE dd MMMM yyyy', 'fr').format(match.date),
            ),
            _row(Icons.access_time, 'Créneau', match.timeSlot),
            _row(Icons.people, 'Max joueurs', '${match.maxPlayers}'),
            _row(Icons.monetization_on_outlined, 'Prix / joueur',
                '${match.pricePerPlayer.toStringAsFixed(2)} DH'),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Text('$label : ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _playersCard(Match match, MatchPlayer? myPlayer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Joueurs inscrits',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text('${match.players.length}/${match.maxPlayers}',
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold)),
                    if (_isAlreadyIn && !match.isFull) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _inviteFriend,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add,
                                  color: AppTheme.primary, size: 14),
                              SizedBox(width: 4),
                              Text('Inviter',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            ...match.players.map((p) {
              final isOrganizer = p.name.toLowerCase() ==
                  match.organizerName.toLowerCase();
              final isMe = p.id == myPlayer?.id;
              return _playerTile(
                player: p,
                isOrganizer: isOrganizer,
                onPay: (!p.hasPaid && isMe) ? () => _pay(p) : null,
              );
            }),
            // Empty slots
            for (int i = match.players.length;
                i < match.maxPlayers;
                i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  child: Icon(Icons.person_add,
                      color: Colors.grey.shade400, size: 20),
                ),
                title: Text('Place libre #${i + 1}',
                    style: TextStyle(
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playerTile({
    required MatchPlayer player,
    required bool isOrganizer,
    VoidCallback? onPay,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isOrganizer
            ? AppTheme.accent.withOpacity(0.2)
            : const Color(0xFF1565C0).withOpacity(0.1),
        child: Text(
          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: isOrganizer ? AppTheme.accent : const Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(player.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(isOrganizer ? 'Organisateur' : 'Joueur'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: player.hasPaid
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              player.hasPaid ? '✓ Payé' : 'Non payé',
              style: TextStyle(
                fontSize: 12,
                color: player.hasPaid ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onPay != null) ...[
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
              child: const Text('Payer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _bottomBar(Match match, MatchPlayer? myPlayer) {
    if (_isAlreadyIn) {
      if (myPlayer != null && !myPlayer.hasPaid) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: Text(
                  'Payer ma part — ${match.pricePerPlayer.toStringAsFixed(2)} DH'),
              onPressed: () => _pay(myPlayer),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        );
      }
      return null;
    }

    if (!match.isFull) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.sports_tennis),
            label: const Text('Rejoindre le match'),
            onPressed: _joinMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
      );
    }

    return null;
  }
}

class _InviteSheet extends StatefulWidget {
  final List<AppUser> users;
  final List<String> friendIds;
  const _InviteSheet({required this.users, required this.friendIds});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.users
        : widget.users
            .where((u) =>
                u.fullName.toLowerCase().contains(_query) ||
                u.email.toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.person_add, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Inviter au match',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${widget.users.length} joueur(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Aucun joueur trouvé'))
                : ListView.builder(
                    controller: scroll,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      final isFriend = widget.friendIds.contains(u.id);
                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.1),
                              child: Text(u.avatarEmoji,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                            if (isFriend)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.people,
                                      color: Colors.white, size: 8),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(u.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (isFriend) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Ami',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text('Niv. ${u.level}  •  ${u.email}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: ElevatedButton(
                          onPressed: () => Navigator.pop(context, u),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Inviter',
                              style: TextStyle(fontSize: 13)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
