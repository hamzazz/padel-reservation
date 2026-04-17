import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../services/match_service.dart';
import '../services/user_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/court_painter.dart';
import 'create_match_screen.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  final _service = MatchService();
  late TabController _tabController;
  late Future<List<Match>> _future;
  String? _currentPlayerName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadName();
    _refresh();
  }

  Future<void> _loadName() async {
    final name = await UserPreferences.getPlayerName();
    setState(() => _currentPlayerName = name);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A5C20),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Matchs',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              background: buildCourtSliverBackground(),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: AppTheme.accent,
              tabs: const [
                Tab(text: 'Tous les matchs'),
                Tab(text: 'Mes matchs'),
              ],
            ),
          ),
        ],
        body: FutureBuilder<List<Match>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data ?? [];
            final now = DateTime.now();
            final upcoming = all
                .where((m) => m.date
                    .isAfter(now.subtract(const Duration(hours: 2))))
                .toList();

            final myName = _currentPlayerName?.toLowerCase();
            final mine = myName != null
                ? upcoming
                    .where((m) =>
                        m.organizerName.toLowerCase() == myName ||
                        m.players.any(
                            (p) => p.name.toLowerCase() == myName))
                    .toList()
                : <Match>[];

            return TabBarView(
              controller: _tabController,
              children: [
                _matchList(
                  upcoming,
                  'Aucun match disponible\nCréez le premier !',
                ),
                _matchList(
                  mine,
                  'Vous n\'avez aucun match\nRejoignez ou créez-en un !',
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.black87),
        label: const Text('Créer un match',
            style: TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateMatchScreen()),
          );
          await _loadName();
          _refresh();
        },
      ),
    );
  }

  Widget _matchList(List<Match> matches, String emptyMsg) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_tennis,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: matches.length,
        itemBuilder: (ctx, i) => _MatchCard(
          match: matches[i],
          currentPlayerName: _currentPlayerName,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MatchDetailScreen(matchId: matches[i].id),
              ),
            );
            await _loadName();
            _refresh();
          },
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final String? currentPlayerName;
  final VoidCallback onTap;

  const _MatchCard({
    required this.match,
    required this.currentPlayerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = match.isFull;
    final statusColor = isFull ? Colors.red : const Color(0xFF2E7D32);
    final statusText =
        isFull ? 'Complet' : '${match.availableSpots} place(s)';

    final myName = currentPlayerName?.toLowerCase();
    final isIn = myName != null &&
        match.players.any((p) => p.name.toLowerCase() == myName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sports_tennis,
                            color: Color(0xFF2E7D32), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.courtName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                              'Par ${match.organizerName}',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(statusText,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (isIn)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Inscrit',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  _info(Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(match.date)),
                  const SizedBox(width: 12),
                  _info(Icons.access_time, match.timeSlot),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _info(Icons.people,
                          '${match.players.length}/${match.maxPlayers} joueurs'),
                      const SizedBox(width: 12),
                      _info(Icons.euro,
                          '${match.pricePerPlayer.toStringAsFixed(0)}€/joueur'),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
