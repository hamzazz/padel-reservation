import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/court.dart';
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

  List<Court> _filtered(List<Court> all) {
    if (_filter == 'indoor') return all.where((c) => c.isIndoor).toList();
    if (_filter == 'outdoor') return all.where((c) => !c.isIndoor).toList();
    return all;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Text(
              '${courts.length} terrain${courts.length > 1 ? 's' : ''} disponible${courts.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: courts.length,
              itemBuilder: (ctx, i) => _CourtCard(court: courts[i]),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  Text('${court.pricePerHour.toStringAsFixed(0)}DH/h',
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
  const _CourtCard({required this.court});

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
                      Text(
                        '${court.pricePerHour.toStringAsFixed(0)}DH/h',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
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
