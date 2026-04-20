import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/court.dart';
import '../state/court_provider.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';

class CourtsMapScreen extends StatefulWidget {
  const CourtsMapScreen({super.key});
  @override
  State<CourtsMapScreen> createState() => _CourtsMapScreenState();
}

class _CourtsMapScreenState extends State<CourtsMapScreen> {
  Court? _selected;
  final _mapCtrl = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte des terrains')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: const LatLng(33.0, -7.0),
              initialZoom: 5.5,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.padel.padel_reservation',
              ),
              MarkerLayer(
                markers: context.watch<CourtProvider>().courts.map((c) {
                  final isSelected = _selected?.id == c.id;
                  return Marker(
                    point: LatLng(c.latitude, c.longitude),
                    width: 72,
                    height: 68,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = c);
                        _mapCtrl.move(LatLng(c.latitude, c.longitude), 13);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.accent : AppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isSelected ? AppTheme.accent : AppTheme.primary)
                                      .withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(Icons.sports_tennis,
                                color: isSelected ? Colors.black87 : Colors.white, size: 16),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 3)
                              ],
                            ),
                            child: Text(c.name,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primary : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: _selected != null ? 196 : 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.black54)),
            ),
          ),
          if (_selected != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 10,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _selected!.isIndoor
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _selected!.isIndoor ? Icons.home_outlined : Icons.wb_sunny_outlined,
                              color: _selected!.isIndoor
                                  ? Colors.blue.shade600
                                  : Colors.orange.shade600,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selected!.name,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(_selected!.description,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${_selected!.pricePerHour.toStringAsFixed(0)}DH/h',
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _selected!.isIndoor
                                      ? Colors.blue.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _selected!.isIndoor ? 'Couvert' : 'Extérieur',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _selected!.isIndoor
                                          ? Colors.blue.shade700
                                          : Colors.orange.shade700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(_selected!.address,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('Réserver ce terrain'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BookingScreen(preselectedCourt: _selected)),
                        ),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 46)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
