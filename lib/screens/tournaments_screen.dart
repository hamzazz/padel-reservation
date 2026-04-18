import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/court.dart';
import '../models/tournament.dart';
import '../services/notification_service.dart';
import '../services/tournament_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});
  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final _svc = TournamentService();
  List<Tournament> _tournaments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tournaments = await _svc.getAll();
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    final user = context.read<AuthProvider>().currentUser!;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '10');
    Court court = availableCourts.first;
    int max = 8;
    String format = 'single';
    DateTime date = DateTime.now().add(const Duration(days: 7));
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Créer un tournoi',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nom du tournoi'),
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
                    decoration: const InputDecoration(labelText: 'Terrain'),
                    items: availableCourts
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setS(() => court = v!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Frais d\'inscription (€)'),
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
                        lastDate:
                            DateTime.now().add(const Duration(days: 180)),
                      );
                      if (picked != null) setS(() => date = picked);
                    },
                  ),
                  Row(
                    children: [
                      const Text('Format : '),
                      ChoiceChip(
                          label: const Text('Simple'),
                          selected: format == 'single',
                          onSelected: (_) => setS(() => format = 'single')),
                      const SizedBox(width: 8),
                      ChoiceChip(
                          label: const Text('Double'),
                          selected: format == 'double',
                          onSelected: (_) => setS(() => format = 'double')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Créer le tournoi'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await _svc.create(
                        organizerId: user.id,
                        organizerName: user.fullName,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        date: date,
                        courtId: court.id,
                        courtName: court.name,
                        maxParticipants: max,
                        entryFee: double.tryParse(feeCtrl.text) ?? 0,
                        format: format,
                      );
                      Navigator.pop(ctx);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tournaments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🏆',
                                style: TextStyle(
                                    fontSize: 64,
                                    color: Colors.grey.shade300)),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun tournoi\nCréez le premier !',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tournaments.length,
                          itemBuilder: (ctx, i) => _TournamentCard(
                            tournament: _tournaments[i],
                            onRefresh: _load,
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accent,
              icon: const Icon(Icons.emoji_events, color: Colors.black87),
              label: const Text('Créer tournoi',
                  style: TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.bold)),
              onPressed: _create,
            )
          : null,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('🏆', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tournois',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text(
                '${_tournaments.length} tournoi${_tournaments.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                  '${_tournaments.where((t) => t.status == 'open').length} ouverts',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onRefresh;

  const _TournamentCard({required this.tournament, required this.onRefresh});

  void _showParticipants(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Joueurs inscrits — ${tournament.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${tournament.participantNames.length}/${tournament.maxParticipants}',
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: tournament.maxParticipants > 0
                  ? tournament.participantNames.length /
                      tournament.maxParticipants
                  : 0,
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 14),
            ...tournament.participantNames.asMap().entries.map((e) {
              final idx = e.key;
              final name = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: idx == 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Organisateur',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold)),
                      )
                    : Text('#${idx + 1}',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold)),
              );
            }),
            ...List.generate(
              tournament.maxParticipants - tournament.participantNames.length,
              (i) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  child: Icon(Icons.person_add,
                      color: Colors.grey.shade400, size: 18),
                ),
                title: Text(
                  'Place disponible #${tournament.participantNames.length + i + 1}',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic,
                      fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final svc = TournamentService();
    final notif = NotificationService();

    if (tournament.entryFee > 0) {
      if (user.walletBalance < tournament.entryFee) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Solde insuffisant — rechargez votre wallet'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      await auth.debitWallet(
          tournament.entryFee, 'Inscription tournoi: ${tournament.name}');
    }
    final ok = await svc.join(tournament.id, user.id, user.fullName);
    if (ok) {
      await notif.push(
        userId: user.id,
        title: 'Tournoi rejoint',
        body: 'Vous participez à "${tournament.name}"',
        type: 'tournament',
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Inscription réussie !'),
        backgroundColor: Colors.green,
      ));
      onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    final isIn = tournament.participantIds.contains(user?.id);
    final statusColor = {
          'open': Colors.green,
          'full': Colors.orange,
          'ongoing': Colors.blue,
          'completed': Colors.grey,
          'cancelled': Colors.red,
        }[tournament.status] ??
        Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tournament.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    tournament.status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (tournament.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tournament.description,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ),
            const Divider(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _chip(Icons.calendar_today,
                    DateFormat('dd/MM/yy').format(tournament.date)),
                _chip(Icons.sports_tennis, tournament.courtName),
                _chip(Icons.people,
                    '${tournament.participantIds.length}/${tournament.maxParticipants}'),
                _chip(Icons.euro,
                    '${tournament.entryFee.toStringAsFixed(0)}€/pers.'),
                _chip(Icons.format_list_numbered,
                    tournament.format == 'single' ? 'Simple' : 'Double'),
              ],
            ),
            if (tournament.participantNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showParticipants(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Joueurs inscrits (${tournament.participantNames.length}/${tournament.maxParticipants})',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          ),
                          const Icon(Icons.expand_more,
                              size: 16, color: AppTheme.primary),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tournament.participantNames
                            .take(6)
                            .map((name) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor:
                                            AppTheme.primary.withOpacity(0.15),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(name.split(' ').first,
                                          style:
                                              const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                      if (tournament.participantNames.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${tournament.participantNames.length - 6} autres',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (tournament.status == 'open' && !isIn) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.emoji_events),
                label: const Text('S\'inscrire'),
                onPressed: () => _join(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                ),
              ),
            ] else if (isIn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text('Inscrit',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(text,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
