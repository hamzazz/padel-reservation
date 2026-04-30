import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/reservation.dart';
import '../services/match_service.dart';
import '../services/reservation_service.dart';
import '../services/user_preferences.dart';
import '../state/auth_provider.dart';
import '../state/court_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _matchSvc = MatchService();
  final _resSvc = ReservationService();

  List<Reservation> _reservations = [];
  Reservation? _selectedReservation;
  int _maxPlayers = 4;
  int _level = 0;
  bool _loading = false;
  bool _loadingRes = true;

  LocaleProvider get _locale => context.read<LocaleProvider>();

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';
    // Pre-fill name from auth user
    _nameController.text = auth.currentUser?.fullName ?? '';
    await UserPreferences.setPlayerName(_nameController.text);

    final all = await _resSvc.getForUser(userId);
    final now = DateTime.now();
    // Only show future reservations
    final future = all
        .where((r) => r.date.isAfter(now.subtract(const Duration(hours: 2))))
        .toList();
    setState(() {
      _reservations = future;
      _loadingRes = false;
    });
  }

  Court? _courtFor(Reservation r) {
    return context.read<CourtProvider>().findById(r.courtId);
  }

  Future<void> _openMaps(Court court) async {
    final uri = Uri.parse(
        'https://maps.google.com/maps?q=${court.latitude},${court.longitude}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri);
    }
  }

  double get _pricePerPlayer {
    if (_selectedReservation == null) return 0;
    final court = _courtFor(_selectedReservation!);
    if (court == null) return 0;
    return court.pricePerHour / _maxPlayers;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReservation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_locale.tr('selectReservation')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final organizerName = _nameController.text.trim();
    await UserPreferences.setPlayerName(organizerName);

    final res = _selectedReservation!;
    final match = Match(
      id: const Uuid().v4(),
      organizerId: auth.currentUser?.id ?? '',
      courtId: res.courtId,
      courtName: res.courtName,
      date: res.date,
      timeSlot: res.timeSlot,
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
      pricePerPlayer: _pricePerPlayer,
      status: 'open',
      createdAt: DateTime.now(),
      level: _level,
    );

    await _matchSvc.save(match);
    setState(() => _loading = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_locale.tr('matchCreatedSuccess')),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _label(_locale.tr('organizerName')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      hintText: _locale.tr('enterYourName'),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? _locale.tr('nameRequired') : null,
                  ),
                  const SizedBox(height: 24),
                  _label(_locale.tr('chooseReservation')),
                  const SizedBox(height: 4),
                  Text(_locale.tr('selectUpcomingReservation'),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  _buildReservationPicker(),
                  if (_selectedReservation != null) ...[
                    const SizedBox(height: 24),
                    _label(_locale.tr('numberOfPlayers')),
                    const SizedBox(height: 8),
                    Row(
                      children: [2, 4].map((n) {
                        final sel = _maxPlayers == n;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _maxPlayers = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: sel ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel
                                      ? AppTheme.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.people,
                                      color: sel ? Colors.white : Colors.grey,
                                      size: 28),
                                  const SizedBox(height: 4),
                                  Text('$n ${_locale.tr("players")}',
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
                    _label(_locale.tr('matchLevel')),
                    const SizedBox(height: 8),
                    _buildLevelSelector(),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_locale.tr('pricePerPlayer'),
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              Text(
                                '${_pricePerPlayer.toStringAsFixed(2)} DH',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.monetization_on_outlined,
                              color: AppTheme.primary, size: 38),
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
                            _loading ? _locale.tr('launching') : _locale.tr('launchMatch')),
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
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
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('🎾', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_locale.tr('createMatchTitle'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text(_locale.tr('basedOnReservations'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReservationPicker() {
    if (_loadingRes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reservations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.calendar_today, color: Colors.orange.shade600, size: 36),
            const SizedBox(height: 10),
            Text(
              _locale.tr('noUpcomingReservation2'),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800),
            ),
            const SizedBox(height: 4),
            Text(
              _locale.tr('bookFirstToCreateMatch'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(_locale.tr('bookCourt')),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _reservations.map((res) {
        final isSelected = _selectedReservation?.id == res.id;
        final court = _courtFor(res);
        return GestureDetector(
          onTap: () => setState(() => _selectedReservation = res),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    court?.isIndoor == true
                        ? Icons.home_outlined
                        : Icons.wb_sunny_outlined,
                    color: isSelected ? AppTheme.primary : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(res.courtName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.black87)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('EEE dd MMM yyyy', 'fr').format(res.date),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(res.timeSlot,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      if (court != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _openMaps(court),
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 12,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  court.address,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : Colors.grey.shade500,
                                      decoration: TextDecoration.underline),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.open_in_new,
                                  size: 10,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 16),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      court != null
                          ? '${court.pricePerHour.toStringAsFixed(0)}DH'
                          : '',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLevelSelector() {
    return Column(
      children: [
        Row(
          children: [
            _levelChip(0, _locale.tr('allLevels'), Icons.people_outline),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(8, (i) {
            final lvl = i + 1;
            return _levelChip(lvl, 'Niv. $lvl — ${levelLabels[lvl]}', null);
          }),
        ),
      ],
    );
  }

  Widget _levelChip(int lvl, String label, IconData? icon) {
    final sel = _level == lvl;
    return GestureDetector(
      onTap: () => setState(() => _level = lvl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: sel ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}
