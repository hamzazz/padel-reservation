import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../state/auth_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';
import '../models/elo_match.dart';
import '../services/elo_service.dart';
import '../widgets/elo_tier_badge.dart';
import 'elo_match_result_screen.dart';
import 'wallet_screen.dart';
import 'players_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewUserId; // null = view own profile
  const ProfileScreen({super.key, this.viewUserId});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authSvc = AuthService();
  final _reviewSvc = ReviewService();
  final _eloSvc = EloService();
  AppUser? _viewUser;
  double _avgRating = 0;
  List<EloMatch> _recentElo = [];
  int _pendingEloCount = 0;
  bool _loading = true;

  bool get isOwnProfile =>
      widget.viewUserId == null ||
      widget.viewUserId ==
          context.read<AuthProvider>().currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      if (widget.viewUserId == null ||
          widget.viewUserId == auth.currentUser?.id) {
        _viewUser = auth.currentUser;
      } else {
        final all = await _authSvc.getAllUsers();
        try {
          _viewUser = all.firstWhere((u) => u.id == widget.viewUserId);
        } catch (_) {}
      }
      if (_viewUser != null) {
        final results = await Future.wait([
          _reviewSvc.averageRating(_viewUser!.id),
          _eloSvc.getRecentForUser(_viewUser!.id, limit: 5),
        ]);
        _avgRating = results[0] as double;
        _recentElo = results[1] as List<EloMatch>;
      }
      if (auth.currentUser != null && isOwnProfile) {
        _pendingEloCount =
            (await _eloSvc.getPendingForUser(auth.currentUser!.id)).length;
      }
    } catch (_) {
      // Ensure spinner stops even on network/Firestore error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    if (_viewUser == null) return;
    final auth = context.read<AuthProvider>();
    final firstCtrl =
        TextEditingController(text: _viewUser!.firstName);
    final lastCtrl =
        TextEditingController(text: _viewUser!.lastName);
    final phoneCtrl =
        TextEditingController(text: _viewUser!.phone);
    int level = _viewUser!.level;
    String avatar = _viewUser!.avatarEmoji;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Modifier le profil',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: avatarEmojis.map((e) {
                    return GestureDetector(
                      onTap: () => setS(() => avatar = e),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: e == avatar
                              ? AppTheme.primary.withOpacity(0.15)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: e == avatar
                                  ? AppTheme.primary
                                  : Colors.transparent),
                        ),
                        child:
                            Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: firstCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Prénom'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: lastCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Nom'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Téléphone')),
                const SizedBox(height: 14),
                const Text('Niveau',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(8, (i) {
                    final lvl = i + 1;
                    return GestureDetector(
                      onTap: () => setS(() => level = lvl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: level == lvl
                              ? AppTheme.primary
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$lvl',
                            style: TextStyle(
                                color: level == lvl
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final updated = _viewUser!.copyWith(
                      firstName: firstCtrl.text.trim(),
                      lastName: lastCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      level: level,
                      avatarEmoji: avatar,
                    );
                    await auth.updateProfile(updated);
                    if (mounted) {
                      Navigator.pop(ctx);
                      setState(() => _viewUser = updated);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize:
                          const Size(double.infinity, 48)),
                  child: const Text('Enregistrer'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;

    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_viewUser == null && me == null) {
      return const Scaffold(
          body: Center(child: Text('Joueur introuvable')));
    }
    // Pour le profil personnel, utiliser currentUser du provider (toujours à jour)
    final u = (isOwnProfile ? me : _viewUser) ?? _viewUser!;
    final isFriend = me?.friendIds.contains(u.id) ?? false;
    final isBlocked = me?.blockedIds.contains(u.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: isOwnProfile
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(u.avatarEmoji,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  const Text('Mon profil',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              )
            : Text(u.fullName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (isOwnProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _editProfile,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ),
            ),
          if (!isOwnProfile && me != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) async {
                if (v == 'friend') {
                  if (isFriend)
                    await auth.removeFriend(u.id);
                  else
                    await auth.addFriend(u.id);
                  setState(() {});
                } else if (v == 'block') {
                  if (isBlocked)
                    await auth.unblockUser(u.id);
                  else
                    await auth.blockUser(u.id);
                  setState(() {});
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'friend',
                  child: Text(isFriend
                      ? 'Retirer des amis'
                      : 'Ajouter comme ami'),
                ),
                PopupMenuItem(
                  value: 'block',
                  child:
                      Text(isBlocked ? 'Débloquer' : 'Bloquer'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header card with gradient top
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(u.avatarEmoji,
                          style: const TextStyle(fontSize: 60)),
                      const SizedBox(height: 8),
                      Text(u.fullName,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(u.email,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _badge('Niveau ${u.level}',
                              AppTheme.primary, Icons.star),
                          const SizedBox(width: 10),
                          _badge(levelLabels[u.level], Colors.orange,
                              Icons.sports_tennis),
                          if (u.isAdmin) ...[
                            const SizedBox(width: 10),
                            _badge(
                                'Admin', Colors.red, Icons.admin_panel_settings),
                          ],
                        ],
                      ),
                      if (_avgRating > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...List.generate(5, (i) {
                              return Icon(
                                i < _avgRating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              );
                            }),
                            const SizedBox(width: 6),
                            Text(_avgRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      // ELO tier badge
                      const SizedBox(height: 12),
                      EloTierBadge(elo: u.eloRating, large: true, showScore: true),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: EloProgressBar(elo: u.eloRating),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Info card
          Card(
            child: Column(
              children: [
                _infoTile(Icons.phone, 'Téléphone', u.phone.isEmpty ? 'Non renseigné' : u.phone),
                _infoTile(Icons.calendar_today, 'Membre depuis',
                    '${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}'),
                _infoTile(Icons.group, 'Amis', '${u.friendIds.length} ami(s)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // ELO stats card
          _EloStatsCard(
            user: u,
            recentMatches: _recentElo,
            pendingCount: isOwnProfile ? _pendingEloCount : 0,
            isOwnProfile: isOwnProfile,
            onDeclare: isOwnProfile
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EloMatchResultScreen()))
                    .then((_) => _load())
                : null,
          ),
          const SizedBox(height: 12),
          // Wallet (own only)
          if (isOwnProfile) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet,
                    color: AppTheme.primary),
                title: const Text('Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Solde : ${u.walletBalance.toStringAsFixed(2)} DH'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WalletScreen())),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Actions for other users
          if (!isOwnProfile && me != null) ...[
            ElevatedButton.icon(
              icon: Icon(isFriend ? Icons.person_remove : Icons.person_add),
              label:
                  Text(isFriend ? 'Retirer des amis' : 'Ajouter comme ami'),
              onPressed: () async {
                if (isFriend)
                  await auth.removeFriend(u.id);
                else
                  await auth.addFriend(u.id);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFriend ? Colors.grey : AppTheme.primary,
                  minimumSize: const Size(double.infinity, 46)),
            ),
            const SizedBox(height: 8),
            _ReviewSection(
                targetUser: u,
                currentUser: me,
                reviewSvc: _reviewSvc),
          ],
          // Friends list (own profile)
          if (isOwnProfile && u.friendIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.group, color: AppTheme.primary),
              title: const Text('Mes amis',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PlayersScreen())),
            ),
          ],
          // Language picker (own profile)
          if (isOwnProfile) ...[
            const SizedBox(height: 12),
            _LanguageSelector(),
          ],
          // Logout (own profile)
          if (isOwnProfile) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Se déconnecter',
                  style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await auth.logout();
                if (mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary, size: 20),
      title: Text(label,
          style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

// ── ELO stats card ───────────────────────────────────────────────────────────

class _EloStatsCard extends StatelessWidget {
  final AppUser user;
  final List<EloMatch> recentMatches;
  final int pendingCount;
  final bool isOwnProfile;
  final VoidCallback? onDeclare;

  const _EloStatsCard({
    required this.user,
    required this.recentMatches,
    required this.pendingCount,
    required this.isOwnProfile,
    this.onDeclare,
  });

  @override
  Widget build(BuildContext context) {
    final winRate = user.eloMatchesPlayed > 0
        ? (user.eloWins / user.eloMatchesPlayed * 100).round()
        : 0;
    final losses = user.eloMatchesPlayed - user.eloWins;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text('Classement ELO',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (pendingCount > 0)
                  GestureDetector(
                    onTap: onDeclare,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('$pendingCount en attente',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('${user.eloRating}', 'ELO',
                    Color(eloTierColorValue(user.eloRating))),
                _stat('${user.eloMatchesPlayed}', 'Matchs',
                    AppTheme.primary),
                _stat('${user.eloWins}W / ${losses}L', 'Résultats',
                    Colors.green),
                _stat('$winRate%', 'Victoires', Colors.orange),
              ],
            ),
            // Recent ELO history
            if (recentMatches.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Historique récent',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              ...recentMatches.map((m) {
                final isTeam1 = m.team1Ids.contains(user.id);
                final won = (isTeam1 && m.winnerTeam == '1') ||
                    (!isTeam1 && m.winnerTeam == '2');
                final delta = m.eloChanges[user.id] ?? 0;
                final before = m.eloBefore[user.id] ?? user.eloRating;
                final myTeam =
                    isTeam1 ? m.team1Names : m.team2Names;
                final oppTeam =
                    isTeam1 ? m.team2Names : m.team1Names;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: won
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: won
                            ? Colors.green.shade200
                            : Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Text(won ? '🏆' : '💔',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${myTeam.join(' & ')} vs ${oppTeam.join(' & ')}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$before ELO → ${before + delta} ELO',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${delta >= 0 ? '+' : ''}$delta',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: delta >= 0
                                ? Colors.green.shade700
                                : Colors.red.shade700),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (isOwnProfile) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Déclarer un résultat de match'),
                  onPressed: onDeclare,
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: AppTheme.primary),
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(locale.tr('language'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _langBtn(context, 'fr', '🇫🇷', locale.tr('french'), locale),
              const SizedBox(width: 8),
              _langBtn(context, 'en', '🇬🇧', locale.tr('english'), locale),
              const SizedBox(width: 8),
              _langBtn(context, 'ar', '🇸🇦', locale.tr('arabic'), locale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _langBtn(BuildContext context, String code, String flag, String label,
      LocaleProvider locale) {
    final isSelected = locale.locale == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => locale.setLocale(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSection extends StatefulWidget {
  final AppUser targetUser;
  final AppUser currentUser;
  final ReviewService reviewSvc;
  const _ReviewSection(
      {required this.targetUser,
      required this.currentUser,
      required this.reviewSvc});
  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  double _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sélectionnez une note')));
      return;
    }
    setState(() => _submitting = true);
    await widget.reviewSvc.submitReview(
      reviewerId: widget.currentUser.id,
      reviewerName: widget.currentUser.fullName,
      reviewerEmoji: widget.currentUser.avatarEmoji,
      targetId: widget.targetUser.id,
      rating: _rating,
      comment: _commentCtrl.text.trim(),
    );
    setState(() {
      _submitting = false;
      _rating = 0;
      _commentCtrl.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avis envoyé !'),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Laisser un avis',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1.0),
                  child: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Votre commentaire (optionnel)',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42)),
              child: const Text('Envoyer l\'avis'),
            ),
          ],
        ),
      ),
    );
  }
}
