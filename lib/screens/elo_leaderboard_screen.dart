import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/elo_match.dart';
import '../services/elo_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/elo_tier_badge.dart';
import 'profile_screen.dart';

class EloLeaderboardScreen extends StatefulWidget {
  const EloLeaderboardScreen({super.key});
  @override
  State<EloLeaderboardScreen> createState() => _EloLeaderboardScreenState();
}

class _EloLeaderboardScreenState extends State<EloLeaderboardScreen> {
  final _svc = EloService();
  List<AppUser> _players = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _svc.getLeaderboard(limit: 50);
    if (mounted) setState(() { _players = list; _loading = false; });
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
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Classement ELO',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  // Podium top 3
                  if (_players.length >= 3) _buildPodium(_players, me),
                  // Rest of the list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount:
                          _players.length > 3 ? _players.length - 3 : 0,
                      itemBuilder: (ctx, i) {
                        final rank = i + 4;
                        final p = _players[i + 3];
                        final isMe = p.id == me?.id;
                        return _PlayerRow(
                            rank: rank, player: p, isMe: isMe);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPodium(List<AppUser> players, AppUser? me) {
    final p1 = players[0];
    final p2 = players[1];
    final p3 = players[2];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.05),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd
          Expanded(child: _PodiumColumn(rank: 2, player: p2, height: 80, isMe: p2.id == me?.id)),
          const SizedBox(width: 6),
          // 1st
          Expanded(child: _PodiumColumn(rank: 1, player: p1, height: 110, isMe: p1.id == me?.id)),
          const SizedBox(width: 6),
          // 3rd
          Expanded(child: _PodiumColumn(rank: 3, player: p3, height: 60, isMe: p3.id == me?.id)),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final int rank;
  final AppUser player;
  final double height;
  final bool isMe;

  const _PodiumColumn(
      {required this.rank,
      required this.player,
      required this.height,
      required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = Color(eloTierColorValue(player.eloRating));
    final medals = ['', '🥇', '🥈', '🥉'];

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileScreen(viewUserId: player.id))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(player.avatarEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            player.firstName,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isMe ? AppTheme.primary : Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
          Text('${player.eloRating}',
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: isMe
                  ? AppTheme.primary.withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(
                  color: isMe ? AppTheme.primary : Colors.grey.shade200),
            ),
            child: Center(
              child: Text(medals[rank],
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final int rank;
  final AppUser player;
  final bool isMe;

  const _PlayerRow(
      {required this.rank, required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = Color(eloTierColorValue(player.eloRating));
    final winRate = player.eloMatchesPlayed > 0
        ? (player.eloWins / player.eloMatchesPlayed * 100).round()
        : 0;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileScreen(viewUserId: player.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isMe
                  ? AppTheme.primary.withOpacity(0.3)
                  : Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#$rank',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500),
              ),
            ),
            Text(player.avatarEmoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(player.fullName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color:
                                  isMe ? AppTheme.primary : Colors.black87)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Moi',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${player.eloMatchesPlayed} matchs · $winRate% victoires',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.eloRating}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color),
                ),
                EloTierBadge(elo: player.eloRating),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
