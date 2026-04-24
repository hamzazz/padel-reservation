import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/reservation.dart';
import '../models/tournament.dart';
import '../services/club_service.dart';
import '../services/tournament_service.dart';
import '../state/auth_provider.dart';
import '../state/court_provider.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class ClubAdminScreen extends StatefulWidget {
  const ClubAdminScreen({super.key});
  @override
  State<ClubAdminScreen> createState() => _ClubAdminScreenState();
}

class _ClubAdminScreenState extends State<ClubAdminScreen>
    with SingleTickerProviderStateMixin {
  final _clubSvc = ClubService();
  final _tourSvc = TournamentService();
  late TabController _tabs;

  Club? _club;
  List<Reservation> _reservations = [];
  List<Match> _matches = [];
  List<Tournament> _tournaments = [];
  bool _loading = true;

  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final clubId = context.read<AuthProvider>().clubId;
    if (clubId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _club = await _clubSvc.getById(clubId);
    if (_club == null) {
      setState(() => _loading = false);
      return;
    }
    final courtIds = _club!.courtIds;
    final res = await _clubSvc.getReservations(courtIds);
    final mat = await _clubSvc.getMatches(courtIds);
    final tou = await _clubSvc.getTournaments(courtIds);
    setState(() {
      _reservations = res;
      _matches = mat;
      _tournaments = tou;
      _loading = false;
    });
  }

  // ── Helpers calendrier ────────────────────────────────────────────────

  List<Reservation> _reservationsForDay(DateTime day) {
    return _reservations.where((r) =>
        r.date.year == day.year &&
        r.date.month == day.month &&
        r.date.day == day.day).toList()
      ..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
  }

  List<Reservation> _reservationsForMonth() {
    return _reservations.where((r) =>
        r.date.year == _calendarMonth.year &&
        r.date.month == _calendarMonth.month).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_club == null)
            const Expanded(
                child: Center(child: Text('Aucun club associé à ce compte')))
          else
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildCalendar(),
                  _buildReservations(),
                  _buildTournaments(),
                  _buildProfile(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🏟️', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _club?.name ?? 'Admin Club',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_reservations.length} réservations · ${_tournaments.length} tournois',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _load,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Calendrier'),
              Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Réservations'),
              Tab(icon: Icon(Icons.emoji_events, size: 18), text: 'Tournois'),
              Tab(icon: Icon(Icons.person, size: 18), text: 'Profil'),
            ],
          ),
        ],
      ),
    );
  }

  // ── CALENDRIER ────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final monthRes = _reservationsForMonth();
    return Column(
      children: [
        // Navigation mois
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                      _calendarMonth.year, _calendarMonth.month - 1);
                  _selectedDay = null;
                }),
              ),
              Text(
                DateFormat('MMMM yyyy', 'fr').format(_calendarMonth),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                      _calendarMonth.year, _calendarMonth.month + 1);
                  _selectedDay = null;
                }),
              ),
            ],
          ),
        ),
        // Jours de la semaine
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Grille calendrier
        _buildCalendarGrid(monthRes),
        const Divider(height: 1),
        // Détail du jour sélectionné
        Expanded(
          child: _selectedDay == null
              ? _buildMonthSummary(monthRes)
              : _buildDayDetail(_selectedDay!),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<Reservation> monthRes) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    // Lundi = 1, donc offset = weekday - 1
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    // Map jour → nombre de réservations
    final Map<int, int> countByDay = {};
    for (final r in monthRes) {
      countByDay[r.date.day] = (countByDay[r.date.day] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - startOffset + 1;
              if (dayNum < 1 || dayNum > lastDay.day) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final day =
                  DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
              final count = countByDay[dayNum] ?? 0;
              final isSelected = _selectedDay?.day == dayNum &&
                  _selectedDay?.month == _calendarMonth.month &&
                  _selectedDay?.year == _calendarMonth.year;
              final isToday = day.year == DateTime.now().year &&
                  day.month == DateTime.now().month &&
                  day.day == DateTime.now().day;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1565C0)
                          : isToday
                              ? const Color(0xFF1565C0).withOpacity(0.1)
                              : count > 0
                                  ? AppTheme.primary.withOpacity(0.08)
                                  : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: const Color(0xFF1565C0), width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? const Color(0xFF1565C0)
                                    : Colors.black87,
                          ),
                        ),
                        if (count > 0)
                          Container(
                            width: 16,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        if (count > 0)
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? Colors.white70
                                  : AppTheme.primaryDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildMonthSummary(List<Reservation> monthRes) {
    if (monthRes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune réservation ce mois',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Appuie sur un jour pour voir les détails',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${monthRes.length} réservation${monthRes.length > 1 ? 's' : ''} ce mois',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        ...monthRes.map((r) => _reservationTile(r)),
      ],
    );
  }

  Widget _buildDayDetail(DateTime day) {
    final dayRes = _reservationsForDay(day);
    final courts = context.read<CourtProvider>().courts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 16, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE dd MMMM yyyy', 'fr').format(day),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text('${dayRes.length} rés.',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        if (dayRes.isEmpty)
          Expanded(
            child: Center(
              child: Text('Aucune réservation ce jour',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Grouper par terrain
                ..._groupByCourtAndSlot(dayRes, courts),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _groupByCourtAndSlot(
      List<Reservation> dayRes, List<Court> courts) {
    final Map<String, List<Reservation>> byCourtId = {};
    for (final r in dayRes) {
      byCourtId.putIfAbsent(r.courtId, () => []).add(r);
    }

    return byCourtId.entries.map((entry) {
      final court = courts.firstWhere((c) => c.id == entry.key,
          orElse: () => Court(
              id: entry.key,
              name: entry.value.first.courtName,
              description: '',
              pricePerHour: 0,
              isIndoor: false,
              address: '',
              latitude: 0,
              longitude: 0));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8, top: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: court.isIndoor
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  court.isIndoor
                      ? Icons.home_outlined
                      : Icons.wb_sunny_outlined,
                  size: 16,
                  color: court.isIndoor ? Colors.blue : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(court.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          ...entry.value.map((r) => _reservationTile(r)),
          const SizedBox(height: 8),
        ],
      );
    }).toList();
  }

  Widget _reservationTile(Reservation r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: Text(
            r.playerName.isNotEmpty ? r.playerName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(r.playerName,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(r.timeSlot,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${r.numberOfPlayers} joueurs',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text('${r.totalPrice.toStringAsFixed(0)} DH',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── RÉSERVATIONS ─────────────────────────────────────────────────────

  Widget _buildReservations() {
    if (_reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune réservation',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // Grouper par date
    final Map<String, List<Reservation>> byDate = {};
    for (final r in _reservations) {
      final key = DateFormat('yyyy-MM-dd').format(r.date);
      byDate.putIfAbsent(key, () => []).add(r);
    }
    final sortedKeys = byDate.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sortedKeys.length,
        itemBuilder: (ctx, i) {
          final key = sortedKeys[i];
          final date = DateTime.parse(key);
          final dayRes = byDate[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  DateFormat('EEEE dd MMMM', 'fr').format(date),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade700),
                ),
              ),
              ...dayRes.map((r) => _reservationTile(r)),
            ],
          );
        },
      ),
    );
  }

  // ── TOURNOIS ──────────────────────────────────────────────────────────

  Widget _buildTournaments() {
    final courts = context.watch<CourtProvider>().courts;
    final clubCourts =
        courts.where((c) => _club?.courtIds.contains(c.id) ?? false).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Créer tournoi',
            style: TextStyle(color: Colors.white)),
        onPressed: () => _showCreateTournament(clubCourts),
      ),
      body: _tournaments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events,
                      size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Aucun tournoi',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _tournaments.length,
                itemBuilder: (ctx, i) => _tournamentCard(_tournaments[i]),
              ),
            ),
    );
  }

  Widget _tournamentCard(Tournament t) {
    final isOpen = t.status == 'open';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events,
                    color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppTheme.primary.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOpen ? 'Ouvert' : t.status,
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isOpen ? AppTheme.primaryDark : Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(DateFormat('dd/MM/yyyy').format(t.date),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 12),
                Icon(Icons.people,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                    '${t.participantIds.length}/${t.maxParticipants} participants',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 12),
                Icon(Icons.monetization_on_outlined,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('${t.entryFee.toStringAsFixed(0)} DH',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            if (t.participantNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Participants :',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: t.participantNames
                    .map((name) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTournament(List<Court> clubCourts) async {
    if (clubCourts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucun terrain assigné à ce club'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final user = context.read<AuthProvider>().currentUser!;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '50');
    Court court = clubCourts.first;
    int max = 8;
    DateTime date = DateTime.now().add(const Duration(days: 7));
    String format = 'single';
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
                  const Text('Créer un tournoi',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nom du tournoi'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Court>(
                    value: court,
                    decoration:
                        const InputDecoration(labelText: 'Terrain'),
                    items: clubCourts
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setS(() => court = v!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Frais inscription (DH)',
                        prefixIcon:
                            Icon(Icons.monetization_on_outlined)),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('dd/MM/yyyy').format(date)),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) setS(() => date = picked);
                    },
                  ),
                  Row(
                    children: [
                      const Text('Participants max : '),
                      const SizedBox(width: 8),
                      ...[4, 8, 16, 32].map((n) => GestureDetector(
                            onTap: () => setS(() => max = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: max == n
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$n',
                                  style: TextStyle(
                                      color: max == n
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Créer le tournoi'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await _tourSvc.create(
                        organizerId: user.id,
                        organizerName: user.fullName,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        date: date,
                        courtId: court.id,
                        courtName: court.name,
                        maxParticipants: max,
                        entryFee:
                            double.tryParse(feeCtrl.text) ?? 0,
                        format: format,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _load();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, 50)),
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

  Widget _buildProfile() {
    return const ProfileScreen();
  }
}
