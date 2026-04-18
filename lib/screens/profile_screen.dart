import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
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
  AppUser? _viewUser;
  double _avgRating = 0;
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
    final auth = context.read<AuthProvider>();
    if (widget.viewUserId == null ||
        widget.viewUserId == auth.currentUser?.id) {
      _viewUser = auth.currentUser;
    } else {
      final all = await _authSvc.getAllUsers();
      try {
        _viewUser =
            all.firstWhere((u) => u.id == widget.viewUserId);
      } catch (_) {}
    }
    if (_viewUser != null) {
      _avgRating = await _reviewSvc.averageRating(_viewUser!.id);
    }
    setState(() => _loading = false);
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
          // Wallet (own only)
          if (isOwnProfile) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet,
                    color: AppTheme.primary),
                title: const Text('Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Solde : ${u.walletBalance.toStringAsFixed(2)} €'),
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
          // Logout (own profile)
          if (isOwnProfile) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Se déconnecter',
                  style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await auth.logout();
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
