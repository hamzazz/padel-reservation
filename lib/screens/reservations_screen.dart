import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/court.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../state/auth_provider.dart';
import '../state/court_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/court_image_widget.dart';
import 'booking_screen.dart';
import 'courts_map_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = ReservationService();
  late Future<List<Reservation>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    setState(() {
      _future = _service.getForUser(userId);
    });
  }

  Future<void> _delete(Reservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la réservation ?'),
        content: Text(
            'Voulez-vous annuler le ${r.courtName} du ${DateFormat('dd/MM/yyyy').format(r.date)} à ${r.timeSlot} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la réservation'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.delete(r.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Réservation annulée'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CourtsTab(onRefreshReservations: _refresh),
                _ReservationsTab(
                  future: _future,
                  onDelete: _delete,
                  onRefresh: _refresh,
                ),
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
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🏟️',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Réservations',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.accent,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Terrains'),
              Tab(text: 'Mes Réservations'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1 : Liste des terrains (moved from HomeScreen) ──────────────────────

class _CourtsTab extends StatefulWidget {
  final VoidCallback onRefreshReservations;
  const _CourtsTab({required this.onRefreshReservations});

  @override
  State<_CourtsTab> createState() => _CourtsTabState();
}

class _CourtsTabState extends State<_CourtsTab>
    with AutomaticKeepAliveClientMixin {
  String _filter = 'all';
  DateTime _slotDate = DateTime.now();
  String? _selectedSlot;
  bool _checkingSlots = false;
  Map<String, int> _slotCounts = {};
  final _resSvc = ReservationService();

  @override
  bool get wantKeepAlive => true;

  List<Court> _filtered(List<Court> all) {
    var list = all;
    if (_filter == 'indoor') list = list.where((c) => c.isIndoor).toList();
    if (_filter == 'outdoor') list = list.where((c) => !c.isIndoor).toList();
    if (_selectedSlot != null && _slotCounts.isNotEmpty) {
      list = list
          .where((c) => (_slotCounts[c.id] ?? 0) < c.maxReservationsPerSlot)
          .toList();
    }
    return list;
  }

  Future<void> _checkAvailability() async {
    if (_selectedSlot == null) {
      setState(() => _slotCounts = {});
      return;
    }
    setState(() => _checkingSlots = true);
    final courts = context.read<CourtProvider>().courts;
    final counts = <String, int>{};
    await Future.wait(courts.map((c) async {
      counts[c.id] = await _resSvc.countSlotReservations(
          c.id, _slotDate, _selectedSlot!);
    }));
    if (mounted) {
      setState(() {
        _slotCounts = counts;
        _checkingSlots = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _slotDate = picked;
        _slotCounts = {};
      });
      if (_selectedSlot != null) _checkAvailability();
    }
  }

  void _showSlotPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
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
                  const Text('Choisir un créneau',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.clear, color: Colors.grey),
                    ),
                    title: const Text('Tous les créneaux',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      setState(() {
                        _selectedSlot = null;
                        _slotCounts = {};
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ...timeSlots.map((slot) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.access_time,
                              color: AppTheme.primary, size: 18),
                        ),
                        title: Text(slot,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: _selectedSlot == slot
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setState(() => _selectedSlot = slot);
                          Navigator.pop(context);
                          _checkAvailability();
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allCourts = context.watch<CourtProvider>().courts;
    final courts = _filtered(allCourts);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterBar(),
            _buildSlotFilterBar(),
            if (_checkingSlots)
              const LinearProgressIndicator(
                  minHeight: 2, color: AppTheme.accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Text(
                _selectedSlot != null
                    ? '${courts.length} terrain${courts.length > 1 ? 's' : ''} libre${courts.length > 1 ? 's' : ''} pour ce créneau'
                    : '${courts.length} terrain${courts.length > 1 ? 's' : ''} disponible${courts.length > 1 ? 's' : ''}',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            Expanded(
              child: courts.isEmpty && _selectedSlot != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun terrain libre\npour ce créneau',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedSlot = null;
                              _slotCounts = {};
                            }),
                            child: const Text('Voir tous les terrains'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: courts.length,
                      itemBuilder: (ctx, i) => _CourtCard(
                        court: courts[i],
                        slotCount: _selectedSlot != null
                            ? (_slotCounts[courts[i].id] ?? 0)
                            : null,
                        onBooked: widget.onRefreshReservations,
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: AppTheme.accent,
            icon: const Icon(Icons.calendar_today,
                color: Colors.black87, size: 18),
            label: const Text('Réserver',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
            onPressed: () => _showCourtPicker(),
          ),
        ),
      ],
    );
  }

  void _showCourtPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CourtPickerSheet(
        onCourtSelected: (court) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BookingScreen(preselectedCourt: court)),
          ).then((_) => widget.onRefreshReservations());
        },
        onViewMap: () {
          Navigator.pop(ctx);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CourtsMapScreen()));
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.primary.withOpacity(0.06),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _chip('all', Icons.grid_view_rounded, 'Tous'),
                const SizedBox(width: 8),
                _chip('indoor', Icons.home_outlined, 'Couvert'),
                const SizedBox(width: 8),
                _chip('outdoor', Icons.wb_sunny_outlined, 'Extérieur'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CourtsMapScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      color: AppTheme.primary, size: 15),
                  SizedBox(width: 5),
                  Text('Carte',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotFilterBar() {
    final hasFilter = _selectedSlot != null;
    return Container(
      color: AppTheme.primary.withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppTheme.primary, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('dd/MM').format(_slotDate),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _showSlotPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasFilter
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: hasFilter
                      ? Border.all(
                          color: AppTheme.primary.withOpacity(0.5),
                          width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: hasFilter
                            ? AppTheme.primary
                            : Colors.grey.shade500,
                        size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _selectedSlot ?? 'Filtrer par créneau libre',
                        style: TextStyle(
                            color: hasFilter
                                ? AppTheme.primary
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: hasFilter
                                ? FontWeight.bold
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasFilter)
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedSlot = null;
                          _slotCounts = {};
                        }),
                        child: const Icon(Icons.close,
                            size: 14, color: AppTheme.primary),
                      )
                    else
                      Icon(Icons.expand_more,
                          color: Colors.grey.shade500, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, IconData icon, String label) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppTheme.primary.withOpacity(sel ? 1 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: sel ? Colors.white : AppTheme.primary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 2 : Mes Réservations ─────────────────────────────────────────────────

class _ReservationsTab extends StatelessWidget {
  final Future<List<Reservation>> future;
  final Future<void> Function(Reservation) onDelete;
  final VoidCallback onRefresh;

  const _ReservationsTab({
    required this.future,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Reservation>>(
          future: future,
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final reservations = snapshot.data ?? [];
            if (reservations.isEmpty) {
              return _buildEmpty(context);
            }
            final upcoming = reservations
                .where((r) => r.date.isAfter(
                    DateTime.now().subtract(const Duration(hours: 1))))
                .toList();
            final past = reservations
                .where((r) => r.date.isBefore(
                    DateTime.now().subtract(const Duration(hours: 1))))
                .toList()
                .reversed
                .toList();

            return RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  if (upcoming.isNotEmpty) ...[
                    _sectionHeader('À venir', upcoming.length),
                    ...upcoming.map((r) => _ReservationCard(
                        reservation: r,
                        onDelete: () => onDelete(r),
                        isPast: false)),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sectionHeader('Passées', past.length),
                    ...past.map((r) => _ReservationCard(
                        reservation: r, onDelete: null, isPast: true)),
                  ],
                ],
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'resv_fab',
            backgroundColor: AppTheme.accent,
            icon: const Icon(Icons.add, color: Colors.black87),
            label: const Text('Nouvelle réservation',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingScreen()),
              );
              onRefresh();
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_tennis, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucune réservation',
              style:
                  TextStyle(fontSize: 18, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Réservez votre premier terrain !',
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Réserver maintenant'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Court Card ───────────────────────────────────────────────────────────────

class _CourtCard extends StatelessWidget {
  final Court court;
  final int? slotCount;
  final VoidCallback? onBooked;

  const _CourtCard({required this.court, this.slotCount, this.onBooked});

  Future<void> _openMap() async {
    final uri = Uri.parse(
        'https://maps.google.com/maps?q=${court.latitude},${court.longitude}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = slotCount != null
        ? court.maxReservationsPerSlot - slotCount!
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BookingScreen(preselectedCourt: court)),
        ).then((_) => onBooked?.call()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourtImageWidget(court: court, height: 150),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(court.name,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: court.isIndoor
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              court.isIndoor ? 'Couvert' : 'Extérieur',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: court.isIndoor
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${court.pricePerHour.toStringAsFixed(0)}DH',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          ),
                          if (available != null)
                            Text(
                              '$available/${court.maxReservationsPerSlot} places libres',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: available > 0
                                      ? AppTheme.primary
                                      : Colors.red,
                                  fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(court.description,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(court.address,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openMap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.map_outlined,
                                  size: 13, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Carte',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Court Picker Sheet ───────────────────────────────────────────────────────

class _CourtPickerSheet extends StatelessWidget {
  final void Function(Court) onCourtSelected;
  final VoidCallback onViewMap;

  const _CourtPickerSheet(
      {required this.onCourtSelected, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            children: [
              const Text('Choisir un terrain',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Voir carte',
                    style: TextStyle(fontSize: 13)),
                onPressed: onViewMap,
              ),
            ],
          ),
          const Divider(height: 16),
          ...context.read<CourtProvider>().courts.map((c) => _tile(c)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _tile(Court court) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () => onCourtSelected(court),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: court.isIndoor
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  court.isIndoor
                      ? Icons.home_outlined
                      : Icons.wb_sunny_outlined,
                  color: court.isIndoor
                      ? Colors.blue.shade700
                      : Colors.orange.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(court.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(court.address,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${court.pricePerHour.toStringAsFixed(0)}DH',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: court.isIndoor
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      court.isIndoor ? 'Couvert' : 'Extérieur',
                      style: TextStyle(
                          fontSize: 10,
                          color: court.isIndoor
                              ? Colors.blue.shade700
                              : Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios,
                  size: 13, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reservation Card ─────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onDelete;
  final bool isPast;

  const _ReservationCard({
    required this.reservation,
    required this.onDelete,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isPast ? 0.6 : 1.0,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPast
                              ? Colors.grey.shade100
                              : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.sports_tennis,
                            color: isPast
                                ? Colors.grey
                                : AppTheme.primary,
                            size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reservation.courtName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(reservation.playerName,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  if (!isPast && onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  _chip(Icons.calendar_today,
                      DateFormat('dd/MM/yyyy').format(reservation.date)),
                  const SizedBox(width: 8),
                  _chip(Icons.access_time, reservation.timeSlot),
                  const SizedBox(width: 8),
                  _chip(Icons.people,
                      '${reservation.numberOfPlayers} joueurs'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${reservation.totalPrice.toStringAsFixed(2)} DH',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          isPast ? Colors.grey : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
