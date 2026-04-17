import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _svc = AuthService();
  List<AppUser> _all = [];
  List<AppUser> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = context.read<AuthProvider>().currentUser;
    final all = await _svc.getAllUsers();
    _all = all
        .where((u) =>
            u.id != me?.id &&
            !(me?.blockedIds.contains(u.id) ?? false) &&
            !u.isAdmin)
        .toList();
    _filtered = _all;
    setState(() => _loading = false);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all
          .where((u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Joueurs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Rechercher un joueur...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text('Aucun joueur trouvé',
                            style: TextStyle(
                                color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) =>
                            _PlayerTile(user: _filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final AppUser user;
  const _PlayerTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().currentUser;
    final isFriend = me?.friendIds.contains(user.id) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: Text(user.avatarEmoji,
              style: const TextStyle(fontSize: 22)),
        ),
        title: Text(user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Niv. ${user.level}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Text(levelLabels[user.level],
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFriend)
              const Icon(Icons.group, color: AppTheme.primary, size: 18),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 13),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileScreen(viewUserId: user.id)),
        ),
      ),
    );
  }
}
