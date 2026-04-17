import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _service = ReservationService();
  late Future<List<Reservation>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la réservation ?'),
        content: Text(
            'Voulez-vous annuler le ${r.courtName} du ${DateFormat('dd/MM/yyyy').format(r.date)} à ${r.timeSlot} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              content: Text('Réservation annulée'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: FutureBuilder<List<Reservation>>(
        future: _future,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reservations = snapshot.data ?? [];
          if (reservations.isEmpty) {
            return _buildEmpty(context);
          }
          final upcoming = reservations
              .where((r) => r.date.isAfter(DateTime.now().subtract(const Duration(hours: 1))))
              .toList();
          final past = reservations
              .where((r) => r.date.isBefore(DateTime.now().subtract(const Duration(hours: 1))))
              .toList()
              .reversed
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                _sectionHeader('À venir', upcoming.length),
                ...upcoming.map((r) => _ReservationCard(
                    reservation: r, onDelete: () => _delete(r), isPast: false)),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('Passées', past.length),
                ...past.map((r) => _ReservationCard(
                    reservation: r, onDelete: null, isPast: true)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.black87),
        label: const Text('Nouvelle réservation',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookingScreen()),
          );
          _refresh();
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
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
              _refresh();
            },
          ),
        ],
      ),
    );
  }
}

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
                            color:
                                isPast ? Colors.grey : AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reservation.courtName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(reservation.playerName,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  if (!isPast && onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                  _chip(Icons.people, '${reservation.numberOfPlayers} joueurs'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${reservation.totalPrice.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPast ? Colors.grey : AppTheme.primary,
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
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
