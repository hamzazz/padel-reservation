import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../state/court_provider.dart';
import '../services/match_service.dart';
import '../services/user_preferences.dart';
import '../state/auth_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';
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
  int _levelFilter = 0;
  String _cityFilter = '';

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
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FutureBuilder<List<Match>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? [];
                final now = DateTime.now();
                var upcoming = all
                    .where((m) =>
                        m.date.isAfter(now.subtract(const Duration(hours: 2))))
                    .toList();

                if (_levelFilter > 0) {
                  upcoming = upcoming.where((m) => m.level == _levelFilter).toList();
                }
                if (_cityFilter.isNotEmpty) {
                  upcoming = upcoming.where((m) => m.city == _cityFilter).toList();
                }

                final user = context.read<AuthProvider>().currentUser;
                final userId = user?.id ?? '';
                final myName = (user?.fullName ?? _currentPlayerName ?? '').toLowerCase();
                final mine = upcoming.where((m) =>
                    (userId.isNotEmpty && m.organizerId == userId) ||
                    m.organizerName.toLowerCase() == myName ||
                    m.players.any((p) => p.name.toLowerCase() == myName)
                ).toList();

                final locale = context.read<LocaleProvider>();
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _matchList(upcoming, locale.tr('noMatchAvailable')),
                    _matchList(mine, locale.tr('noMyMatch')),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.black87),
        label: Text(context.watch<LocaleProvider>().tr('createMatch'),
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
          );
          await _loadName();
          _refresh();
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🎾', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Text(context.watch<LocaleProvider>().tr('matches'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                FutureBuilder<List<Match>>(
                  future: _future,
                  builder: (_, snap) {
                    final count = snap.data?.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count match${count != 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    );
                  },
                ),
              ],
            ),
          ),
          // Filtre par ville
          Builder(builder: (ctx) {
            final courts = ctx.read<CourtProvider>().courts;
            final cities = courts
                .map((c) => c.city)
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
            if (cities.length <= 1) return const SizedBox.shrink();
            return SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _cityFilterChip('', 'Toutes villes'),
                  ...cities.map((c) => _cityFilterChip(c, c)),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          // Filtre par niveau
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _levelFilterChip(0, 'Tous'),
                ...List.generate(8, (i) => _levelFilterChip(i + 1, 'Niv.${i + 1}')),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Builder(builder: (ctx) {
            final locale = ctx.watch<LocaleProvider>();
            return TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: locale.tr('allMatches')),
                Tab(text: locale.tr('myMatches')),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _cityFilterChip(String city, String label) {
    final sel = _cityFilter == city;
    return GestureDetector(
      onTap: () => setState(() => _cityFilter = city),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? Colors.white : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sel) ...[
              Icon(Icons.location_city, size: 11, color: AppTheme.primary),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppTheme.primary : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _levelFilterChip(int level, String label) {
    final sel = _levelFilter == level;
    return GestureDetector(
      onTap: () => setState(() => _levelFilter = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? AppTheme.primary : Colors.white)),
      ),
    );
  }

  Widget _matchList(List<Match> matches, String emptyMsg) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_tennis, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
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
                  builder: (_) => MatchDetailScreen(matchId: matches[i].id)),
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

  Future<void> _openMaps(BuildContext context) async {
    final court = context.read<CourtProvider>().findById(match.courtId);
    final query = court != null
        ? '${court.latitude},${court.longitude}'
        : Uri.encodeComponent(match.courtName);
    final uri = Uri.parse('https://maps.google.com/maps?q=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFull = match.isFull;
    final statusColor = isFull ? Colors.red : const Color(0xFF1565C0);
    final statusText = isFull ? 'Complet' : '${match.availableSpots} place(s)';

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
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sports_tennis,
                            color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.courtName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Par ${match.organizerName}',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
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
                          border:
                              Border.all(color: statusColor.withOpacity(0.3)),
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
                  if (match.level > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Niv.${match.level}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
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
                      _info(Icons.monetization_on_outlined,
                          '${match.pricePerPlayer.toStringAsFixed(0)}DH/joueur'),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openMaps(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 5),
                      Text(match.courtName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 5),
                      const Icon(Icons.open_in_new, size: 12, color: AppTheme.primary),
                    ],
                  ),
                ),
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
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
