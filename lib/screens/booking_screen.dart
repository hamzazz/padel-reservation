import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../state/auth_provider.dart';
import '../state/court_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/court_image_widget.dart';

class BookingScreen extends StatefulWidget {
  final Court? preselectedCourt;
  const BookingScreen({super.key, this.preselectedCourt});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _service = ReservationService();

  Court? _selectedCourt;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  int _players = 2;
  bool _loading = false;
  bool _checkingSlot = false;
  bool _slotTaken = false;
  int _slotCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final courts = context.read<CourtProvider>().courts;
      if (_selectedCourt == null && courts.isNotEmpty) {
        setState(() => _selectedCourt = widget.preselectedCourt ?? courts.first);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
        _slotTaken = false;
      });
    }
  }

  Future<void> _checkAndSelectSlot(String slot) async {
    setState(() {
      _checkingSlot = true;
      _selectedSlot = slot;
    });
    final court = _selectedCourt!;
    final count = await _service.countSlotReservations(court.id, _selectedDate, slot);
    setState(() {
      _slotCount = count;
      _slotTaken = count >= court.maxReservationsPerSlot;
      _checkingSlot = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlot == null) {
      _showSnack('Veuillez sélectionner un créneau horaire', isError: true);
      return;
    }
    if (_slotTaken) {
      _showSnack('Ce créneau est déjà réservé', isError: true);
      return;
    }

    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final reservation = Reservation(
      id: const Uuid().v4(),
      userId: auth.currentUser?.id ?? '',
      courtId: _selectedCourt!.id,
      courtName: _selectedCourt!.name,
      date: _selectedDate,
      timeSlot: _selectedSlot!,
      playerName: _nameController.text.trim(),
      numberOfPlayers: _players,
      totalPrice: _selectedCourt!.pricePerHour,
      createdAt: DateTime.now(),
    );

    await _service.save(reservation);
    setState(() => _loading = false);

    if (mounted) {
      _showSuccessDialog(reservation);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : AppTheme.primary,
    ));
  }

  void _showSuccessDialog(Reservation r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.primary, size: 56),
            ),
            const SizedBox(height: 16),
            const Text('Réservation confirmée !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.sports_tennis, r.courtName),
            _infoRow(Icons.calendar_today, DateFormat('EEEE dd MMMM yyyy', 'fr').format(r.date)),
            _infoRow(Icons.access_time, r.timeSlot),
            _infoRow(Icons.people, '${r.numberOfPlayers} joueurs'),
            _infoRow(Icons.monetization_on_outlined, '${r.totalPrice.toStringAsFixed(2)} DH'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Fermer', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle réservation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Court image + location
            if (_selectedCourt != null) ...[
              CourtImageWidget(court: _selectedCourt!, height: 180),
              const SizedBox(height: 10),
              _buildLocationRow(_selectedCourt!),
              const SizedBox(height: 16),
            ],
            _sectionTitle('Votre nom'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
                hintText: 'Entrez votre nom complet',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 20),
            _sectionTitle('Terrain'),
            const SizedBox(height: 8),
            _buildCourtSelector(),
            const SizedBox(height: 20),
            _sectionTitle('Nombre de joueurs'),
            const SizedBox(height: 8),
            _buildPlayerSelector(),
            const SizedBox(height: 20),
            _sectionTitle('Date'),
            const SizedBox(height: 8),
            _buildDateSelector(),
            const SizedBox(height: 20),
            _sectionTitle('Créneau horaire'),
            const SizedBox(height: 8),
            _buildTimeSlots(),
            const SizedBox(height: 20),
            _buildPriceSummary(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmer la réservation'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildLocationRow(Court court) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(court.address,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse(
                'https://maps.google.com/?q=${court.latitude},${court.longitude}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.map_outlined, size: 13, color: AppTheme.primary),
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
    );
  }

  Widget _buildCourtSelector() {
    return DropdownButtonFormField<Court>(
      value: _selectedCourt,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.sports_tennis)),
      items: context.read<CourtProvider>().courts
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.name} — ${c.pricePerHour.toStringAsFixed(0)}DH'),
              ))
          .toList(),
      onChanged: (v) => setState(() {
        _selectedCourt = v;
        _selectedSlot = null;
        _slotTaken = false;
      }),
    );
  }

  Widget _buildPlayerSelector() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: AppTheme.primary,
          onPressed: _players > 2 ? () => setState(() => _players--) : null,
        ),
        Expanded(
          child: Center(
            child: Text('$_players joueurs',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: AppTheme.primary,
          onPressed: _players < 4 ? () => setState(() => _players++) : null,
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE dd MMMM yyyy', 'fr').format(_selectedDate),
              style: const TextStyle(fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.edit, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: timeSlots.map((slot) {
        final isSelected = _selectedSlot == slot;
        return GestureDetector(
          onTap: () => _checkAndSelectSlot(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (_slotTaken ? Colors.red : AppTheme.primary)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? (_slotTaken ? Colors.red : AppTheme.primary)
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_checkingSlot && isSelected)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else if (isSelected && _slotTaken)
                      const Icon(Icons.block, size: 14, color: Colors.white)
                    else if (isSelected)
                      const Icon(Icons.check, size: 14, color: Colors.white),
                    if (isSelected) const SizedBox(width: 4),
                    Text(
                      slot,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (isSelected && !_checkingSlot &&
                    (_selectedCourt?.maxReservationsPerSlot ?? 1) > 1)
                  Text(
                    '${(_selectedCourt!.maxReservationsPerSlot) - _slotCount}/${_selectedCourt!.maxReservationsPerSlot} libres',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceSummary() {
    if (_selectedCourt == null) return const SizedBox.shrink();
    final total = _selectedCourt!.pricePerHour;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total (1h30)', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text(
                '${total.toStringAsFixed(2)} DH',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          Icon(Icons.monetization_on_outlined, color: AppTheme.primary.withOpacity(0.4), size: 40),
        ],
      ),
    );
  }
}
