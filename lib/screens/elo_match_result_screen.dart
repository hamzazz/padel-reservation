import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/elo_match.dart';
import '../services/auth_service.dart';
import '../services/elo_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/elo_tier_badge.dart';

class EloMatchResultScreen extends StatefulWidget {
  const EloMatchResultScreen({super.key});
  @override
  State<EloMatchResultScreen> createState() => _EloMatchResultScreenState();
}

class _EloMatchResultScreenState extends State<EloMatchResultScreen> {
  final _eloSvc = EloService();
  final _authSvc = AuthService();

  List<EloMatch> _pending = [];
  List<AppUser> _allUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;
    final results = await Future.wait([
      _eloSvc.getPendingForUser(me.id),
      _authSvc.getAllUsers(),
    ]);
    if (!mounted) return;
    setState(() {
      _pending = results[0] as List<EloMatch>;
      _allUsers = results[1] as List<AppUser>;
      _loading = false;
    });
  }

  Future<void> _confirm(EloMatch m, bool agree) async {
    final me = context.read<AuthProvider>().currentUser!;
    if (agree) {
      final err = await _eloSvc.confirmResult(m.id, me.id);
      if (mounted && err == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Résultat confirmé ✅ ELO mis à jour'),
            backgroundColor: Colors.green));
      }
    } else {
      await _eloSvc.disputeResult(m.id, me.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Résultat contesté — un admin va trancher'),
            backgroundColor: Colors.orange));
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: const Text('Résultats de matchs',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Déclarer un résultat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showSubmitSheet(me),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _pending.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _sectionTitle(
                            '⏳ En attente de votre confirmation (${_pending.length})'),
                        ..._pending.map((m) => _PendingCard(
                              match: m,
                              me: me!,
                              onConfirm: () => _confirm(m, true),
                              onDispute: () => _confirm(m, false),
                            )),
                      ],
                    ),
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎾', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          const Text('Aucun résultat en attente',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Déclarez un résultat après votre match',
              style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Déclarer un résultat'),
            onPressed: () =>
                _showSubmitSheet(context.read<AuthProvider>().currentUser),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 46)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
      );

  // ── Submit sheet ────────────────────────────────────────────────────────────

  void _showSubmitSheet(AppUser? me) {
    if (me == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _SubmitSheet(
        me: me,
        allUsers: _allUsers.where((u) => u.id != me.id).toList(),
        eloSvc: _eloSvc,
        onDone: _load,
      ),
    );
  }
}

// ── Pending card ─────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final EloMatch match;
  final AppUser me;
  final VoidCallback onConfirm;
  final VoidCallback onDispute;

  const _PendingCard({
    required this.match,
    required this.me,
    required this.onConfirm,
    required this.onDispute,
  });

  @override
  Widget build(BuildContext context) {
    final isTeam1 = match.team1Ids.contains(me.id);
    final myTeamNames = isTeam1 ? match.team1Names : match.team2Names;
    final oppTeamNames = isTeam1 ? match.team2Names : match.team1Names;
    final myTeamWon = (isTeam1 && match.winnerTeam == '1') ||
        (!isTeam1 && match.winnerTeam == '2');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Résultat soumis le ${DateFormat('dd/MM').format(match.createdAt)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (match.courtName.isNotEmpty)
                  Text(match.courtName,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Teams
                Row(
                  children: [
                    Expanded(
                      child: _TeamBox(
                        names: match.team1Names,
                        label: 'Équipe 1',
                        isWinner: match.winnerTeam == '1',
                        isMyTeam: match.team1Ids.contains(me.id),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('VS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade400)),
                    ),
                    Expanded(
                      child: _TeamBox(
                        names: match.team2Names,
                        label: 'Équipe 2',
                        isWinner: match.winnerTeam == '2',
                        isMyTeam: match.team2Ids.contains(me.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Result label
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: myTeamWon
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        myTeamWon ? '🏆 Victoire déclarée' : '😔 Défaite déclarée',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: myTeamWon
                                ? Colors.green.shade700
                                : Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDispute,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Contester',
                            style:
                                TextStyle(color: Colors.red.shade400)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Confirmer ✓',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamBox extends StatelessWidget {
  final List<String> names;
  final String label;
  final bool isWinner;
  final bool isMyTeam;

  const _TeamBox({
    required this.names,
    required this.label,
    required this.isWinner,
    required this.isMyTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWinner
            ? Colors.green.shade50
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isWinner
                ? Colors.green.shade300
                : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              if (isWinner) ...[
                const SizedBox(width: 4),
                const Text('🏆', style: TextStyle(fontSize: 10)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ...names.map((n) => Text(
                n,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isMyTeam
                        ? FontWeight.bold
                        : FontWeight.normal),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              )),
        ],
      ),
    );
  }
}

// ── Submit sheet ──────────────────────────────────────────────────────────────

class _SubmitSheet extends StatefulWidget {
  final AppUser me;
  final List<AppUser> allUsers;
  final EloService eloSvc;
  final VoidCallback onDone;

  const _SubmitSheet({
    required this.me,
    required this.allUsers,
    required this.eloSvc,
    required this.onDone,
  });

  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  AppUser? _partner;
  AppUser? _opp1;
  AppUser? _opp2;
  String _winner = 'my'; // 'my' | 'opp'
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_partner == null || _opp1 == null || _opp2 == null) {
      setState(() => _error = 'Sélectionnez les 3 autres joueurs');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final team1 = [widget.me, _partner!];
    final team2 = [_opp1!, _opp2!];
    final winnerTeam = _winner == 'my' ? '1' : '2';

    await widget.eloSvc.submitResult(
      submittedBy: widget.me.id,
      team1: team1,
      team2: team2,
      winnerTeam: winnerTeam,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Résultat soumis ✅ En attente de confirmation'),
          backgroundColor: AppTheme.primary));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.allUsers
        .where((u) =>
            u.id != _partner?.id &&
            u.id != _opp1?.id &&
            u.id != _opp2?.id)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Déclarer un résultat',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Mon équipe : moi + partenaire vs 2 adversaires',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 20),

            // My team
            _sectionLabel('🤝 Mon équipe'),
            _playerChip(widget.me, isFixed: true),
            const SizedBox(height: 8),
            _playerPicker(
              label: 'Choisir mon partenaire',
              selected: _partner,
              users: available,
              onPick: (u) => setState(() => _partner = u),
              onClear: () => setState(() => _partner = null),
            ),
            const SizedBox(height: 16),

            // Opponent team
            _sectionLabel('⚔️ Équipe adverse'),
            _playerPicker(
              label: 'Adversaire 1',
              selected: _opp1,
              users: available,
              onPick: (u) => setState(() => _opp1 = u),
              onClear: () => setState(() => _opp1 = null),
            ),
            const SizedBox(height: 8),
            _playerPicker(
              label: 'Adversaire 2',
              selected: _opp2,
              users: available,
              onPick: (u) => setState(() => _opp2 = u),
              onClear: () => setState(() => _opp2 = null),
            ),
            const SizedBox(height: 20),

            // Winner
            _sectionLabel('🏆 Qui a gagné ?'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _winnerBtn('my', '🏆 Mon équipe')),
                const SizedBox(width: 10),
                Expanded(
                    child: _winnerBtn('opp', '💀 L\'équipe adverse')),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Soumettre le résultat',
                        style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));

  Widget _playerChip(AppUser u, {bool isFixed = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(u.avatarEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(u.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          EloTierBadge(elo: u.eloRating),
        ],
      ),
    );
  }

  Widget _playerPicker({
    required String label,
    required AppUser? selected,
    required List<AppUser> users,
    required void Function(AppUser) onPick,
    required VoidCallback onClear,
  }) {
    if (selected != null) {
      return Row(
        children: [
          Expanded(child: _playerChip(selected)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
            color: Colors.grey,
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _showUserPicker(users, onPick),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.person_search,
                color: Colors.grey.shade500, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500)),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _winnerBtn(String value, String label) {
    final selected = _winner == value;
    return GestureDetector(
      onTap: () => setState(() => _winner = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? Colors.white : Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _showUserPicker(List<AppUser> users, void Function(AppUser) onPick) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final query = ctrl.text.toLowerCase();
          final filtered = users
              .where((u) =>
                  query.isEmpty ||
                  u.fullName.toLowerCase().contains(query) ||
                  u.phone.contains(query))
              .toList();

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    onChanged: (_) => setModal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un joueur...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final u = filtered[i];
                      return ListTile(
                        leading: Text(u.avatarEmoji,
                            style: const TextStyle(fontSize: 22)),
                        title: Text(u.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text('Niv.${u.level} · ${u.eloRating} ELO',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500)),
                        trailing: EloTierBadge(elo: u.eloRating),
                        onTap: () {
                          onPick(u);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
