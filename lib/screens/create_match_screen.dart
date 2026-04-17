import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/reservation.dart';
import '../services/match_service.dart';
import '../services/user_preferences.dart';
import '../widgets/court_painter.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _service = MatchService();

  Court? _selectedCourt;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  int _maxPlayers = 4;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedCourt = availableCourts.first;
    UserPreferences.getPlayerName()
        .then((n) => _nameController.text = n ?? '');
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
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF2E7D32)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez un créneau horaire'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _loading = true);

    final organizerName = _nameController.text.trim();
    await UserPreferences.setPlayerName(organizerName);

    final pricePerPlayer =
        _selectedCourt!.pricePerHour * 1.5 / _maxPlayers;

    final match = Match(
      id: const Uuid().v4(),
      courtId: _selectedCourt!.id,
      courtName: _selectedCourt!.name,
      date: _selectedDate,
      timeSlot: _selectedSlot!,
      organizerName: organizerName,
      maxPlayers: _maxPlayers,
      players: [
        MatchPlayer(
          id: const Uuid().v4(),
          name: organizerName,
          hasPaid: false,
          joinedAt: DateTime.now(),
        ),
      ],
      pricePerPlayer: pricePerPlayer,
      status: 'open',
      createdAt: DateTime.now(),
    );

    await _service.save(match);
    setState(() => _loading = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Match lancé avec succès !'),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF1A5C20),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Créer un match',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              background: buildCourtSliverBackground(),
            ),
          ),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Votre nom (organisateur)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Entrez votre nom',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nom requis'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _label('Terrain'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Court>(
                      value: _selectedCourt,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.sports_tennis)),
                      items: availableCourts
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                    '${c.name} — ${c.pricePerHour.toStringAsFixed(0)}€/h'),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCourt = v),
                    ),
                    const SizedBox(height: 20),
                    _label('Nombre de joueurs'),
                    const SizedBox(height: 8),
                    Row(
                      children: [2, 4].map((n) {
                        final sel = _maxPlayers == n;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _maxPlayers = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF2E7D32)
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFF2E7D32)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.people,
                                      color: sel
                                          ? Colors.white
                                          : Colors.grey,
                                      size: 28),
                                  const SizedBox(height: 4),
                                  Text('$n joueurs',
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    _label('Date'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Color(0xFF2E7D32)),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE dd MMMM yyyy', 'fr')
                                  .format(_selectedDate),
                              style: const TextStyle(fontSize: 15),
                            ),
                            const Spacer(),
                            const Icon(Icons.edit,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label('Créneau horaire'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timeSlots.map((slot) {
                        final sel = _selectedSlot == slot;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSlot = slot),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF2E7D32)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              slot,
                              style: TextStyle(
                                fontSize: 13,
                                color: sel
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    if (_selectedCourt != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2E7D32)
                                  .withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('Prix / joueur',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey)),
                                Text(
                                  '${(_selectedCourt!.pricePerHour * 1.5 / _maxPlayers).toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.euro_symbol,
                                color: Color(0xFF2E7D32), size: 38),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.sports_tennis),
                        label: Text(
                            _loading ? 'Création...' : 'Lancer le match'),
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}
