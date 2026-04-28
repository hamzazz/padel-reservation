import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/court.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../state/court_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/court_image_widget.dart';
import 'booking_screen.dart';
import 'courts_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = 'all';
  DateTime _slotDate = DateTime.now();
  String? _selectedSlot;
  bool _checkingSlots = false;
  // courtId → count of reservations for selected slot
  Map<String, int> _slotCounts = {};
  final _resSvc = ReservationService();

  List<Court> _filtered(List<Court> all) {
    var list = all;
    if (_filter == 'indoor') list = list.where((c) => c.isIndoor).toList();
    if (_filter == 'outdoor') list = list.where((c) => !c.isIndoor).toList();

    if (_selectedSlot != null && _slotCounts.isNotEmpty) {
      list = list.where((c) {
        final count = _slotCounts[c.id] ?? 0;
        return count < c.maxReservationsPerSlot;
      }).toList();
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
      counts[c.id] =
          await _resSvc.countSlotReservations(c.id, _slotDate, _selectedSlot!);
    }));
    if (mounted) setState(() { _slotCounts = counts; _checkingSlots = false; });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _slotDate = picked; _slotCounts = {}; });
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
            // Handle + titre (fixe)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Choisir un créneau',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Liste scrollable
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
                      setState(() { _selectedSlot = null; _slotCounts = {}; });
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
                        ? const Icon(Icons.check_circle, color: AppTheme.primary)
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
            MaterialPageRoute(builder: (_) => BookingScreen(preselectedCourt: court)),
          );
        },
        onViewMap: () {
          Navigator.pop(ctx);
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const CourtsMapScreen()));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCourts = context.watch<CourtProvider>().courts;
    final courts = _filtered(allCourts);
    final locale = context.watch<LocaleProvider>();
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          _buildSlotFilterBar(),
          if (_checkingSlots)
            const LinearProgressIndicator(minHeight: 2, color: AppTheme.accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Text(
              _selectedSlot != null
                  ? '${courts.length} terrain${courts.length > 1 ? 's' : ''} libre${courts.length > 1 ? 's' : ''} pour ce créneau'
                  : '${courts.length} terrain${courts.length > 1 ? 's' : ''} disponible${courts.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: courts.isEmpty && _selectedSlot != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Aucun terrain libre\npour ce créneau',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() { _selectedSlot = null; _slotCounts = {}; }),
                          child: const Text('Voir tous les terrains'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: courts.length,
                    itemBuilder: (ctx, i) => _CourtCard(
                      court: courts[i],
                      slotCount: _selectedSlot != null ? (_slotCounts[courts[i].id] ?? 0) : null,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.calendar_today, color: Colors.black87, size: 18),
        label: Text(locale.tr('book'),
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        onPressed: _showCourtPicker,
      ),
    );
  }

  Widget _buildFilterBar() {
    final locale = context.watch<LocaleProvider>();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _chip('all', Icons.grid_view_rounded, locale.tr('allCourts')),
                const SizedBox(width: 8),
                _chip('indoor', Icons.home_outlined, locale.tr('indoor')),
                const SizedBox(width: 8),
                _chip('outdoor', Icons.wb_sunny_outlined, locale.tr('outdoor')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CourtsMapScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, color: Colors.white, size: 15),
                  const SizedBox(width: 5),
                  Text(locale.tr('map'),
                      style: const TextStyle(
                          color: Colors.white,
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
      color: AppTheme.primaryDark,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          // Date
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('dd/MM').format(_slotDate),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Slot picker
          Expanded(
            child: GestureDetector(
              onTap: _showSlotPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasFilter ? Colors.white : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: hasFilter ? Border.all(color: AppTheme.accent, width: 1.5) : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: hasFilter ? AppTheme.primary : Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _selectedSlot ?? 'Filtrer par créneau libre',
                        style: TextStyle(
                            color: hasFilter ? AppTheme.primary : Colors.white70,
                            fontSize: 12,
                            fontWeight: hasFilter ? FontWeight.bold : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasFilter)
                      GestureDetector(
                        onTap: () => setState(() { _selectedSlot = null; _slotCounts = {}; }),
                        child: const Icon(Icons.close, size: 14, color: AppTheme.primary),
                      )
                    else
                      const Icon(Icons.expand_more, color: Colors.white54, size: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: sel ? AppTheme.primary : Colors.white),
            const SizedBox(width: 4),
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
}

class _CourtPickerSheet extends StatelessWidget {
  final void Function(Court) onCourtSelected;
  final VoidCallback onViewMap;
  const _CourtPickerSheet({required this.onCourtSelected, required this.onViewMap});

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
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Choisir un terrain',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Voir carte', style: TextStyle(fontSize: 13)),
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
                  color: court.isIndoor ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  court.isIndoor ? Icons.home_outlined : Icons.wb_sunny_outlined,
                  color: court.isIndoor ? Colors.blue.shade700 : Colors.orange.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(court.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(court.address,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${court.pricePerHour.toStringAsFixed(0)}DH',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: court.isIndoor ? Colors.blue.shade50 : Colors.orange.shade50,
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
              Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  final Court court;
  final int? slotCount;
  const _CourtCard({required this.court, this.slotCount});

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
    final availableSlots = slotCount != null
        ? court.maxReservationsPerSlot - slotCount!
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingScreen(preselectedCourt: court)),
        ),
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
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          if (availableSlots != null)
                            Text(
                              '$availableSlots/${court.maxReservationsPerSlot} places libres',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: availableSlots > 0
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
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                                      fontSize: 12, color: Colors.grey.shade600),
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
                              Text('Voir sur la carte',
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
