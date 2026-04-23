import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
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
  LatLng? _myLocation;
  bool _locating = false;
  bool _proximityMode = false;
  final _mapCtrl = MapController();
  final _distance = const Distance();

  double _distanceTo(Court c) {
    if (_myLocation == null) return double.infinity;
    return _distance.as(
      LengthUnit.Kilometer,
      _myLocation!,
      LatLng(c.latitude, c.longitude),
    );
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Permission de localisation refusée')));
        }
        setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = loc;
        _locating = false;
        _proximityMode = true;
      });
      _mapCtrl.move(loc, 13);
    } catch (e) {
      setState(() => _locating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Localisation échouée: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCourts = context.watch<CourtProvider>().courts;
    final courts = _proximityMode && _myLocation != null
        ? (List<Court>.from(allCourts)
          ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b))))
        : allCourts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des terrains'),
        actions: [
          if (_proximityMode)
            TextButton.icon(
              icon: const Icon(Icons.list, color: Colors.white),
              label: const Text('Proximité', style: TextStyle(color: Colors.white)),
              onPressed: () => _showProximityList(courts),
            ),
        ],
      ),
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
              // Ma position
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Icon(Icons.my_location,
                            color: Colors.blue, size: 22),
                      ),
                    ),
                  ],
                ),
              // Terrains
              MarkerLayer(
                markers: courts.map((c) {
                  final isSelected = _selected?.id == c.id;
                  final dist = _distanceTo(c);
                  return Marker(
                    point: LatLng(c.latitude, c.longitude),
                    width: 80,
                    height: 72,
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
                              color: isSelected
                                  ? AppTheme.accent
                                  : AppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isSelected
                                          ? AppTheme.accent
                                          : AppTheme.primary)
                                      .withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(Icons.sports_tennis,
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.white,
                                size: 16),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12, blurRadius: 3)
                              ],
                            ),
                            child: Text(
                              _proximityMode && dist.isFinite
                                  ? '${dist.toStringAsFixed(1)} km'
                                  : c.name,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Copyright
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
          // Bouton localisation
          Positioned(
            bottom: _selected != null ? 210 : 22,
            left: 12,
            child: Column(
              children: [
                _mapBtn(
                  _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          _myLocation != null
                              ? Icons.my_location
                              : Icons.location_searching,
                          color: _myLocation != null
                              ? Colors.blue
                              : Colors.white,
                        ),
                  _locating ? null : _locate,
                  _myLocation != null ? Colors.white : AppTheme.primary,
                  tooltip: 'Me localiser',
                ),
                if (_proximityMode) ...[
                  const SizedBox(height: 8),
                  _mapBtn(
                    const Icon(Icons.close, color: Colors.white),
                    () => setState(() {
                      _proximityMode = false;
                      _myLocation = null;
                    }),
                    Colors.red.shade400,
                    tooltip: 'Quitter proximité',
                  ),
                ],
              ],
            ),
          ),
          // Carte terrain sélectionné
          if (_selected != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildCourtCard(_selected!),
            ),
        ],
      ),
    );
  }

  Widget _mapBtn(Widget icon, VoidCallback? onTap, Color bg,
      {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: icon,
          ),
        ),
      ),
    );
  }

  Widget _buildCourtCard(Court c) {
    final dist = _distanceTo(c);
    return Card(
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
                    color: c.isIndoor
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    c.isIndoor ? Icons.home_outlined : Icons.wb_sunny_outlined,
                    color: c.isIndoor
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
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(c.description,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${c.pricePerHour.toStringAsFixed(0)}DH/h',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (dist.isFinite)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${dist.toStringAsFixed(1)} km',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.isIndoor
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c.isIndoor ? 'Couvert' : 'Extérieur',
                          style: TextStyle(
                              fontSize: 10,
                              color: c.isIndoor
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
                Icon(Icons.location_on,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(c.address,
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
                    builder: (_) => BookingScreen(preselectedCourt: c)),
              ),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46)),
            ),
          ],
        ),
      ),
    );
  }

  void _showProximityList(List<Court> courts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.near_me, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Terrains à proximité',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: courts.length,
                itemBuilder: (_, i) {
                  final c = courts[i];
                  final dist = _distanceTo(c);
                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.isIndoor
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: c.isIndoor
                                    ? Colors.blue
                                    : Colors.orange)),
                      ),
                    ),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.address,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dist.isFinite)
                          Text('${dist.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        Text('${c.pricePerHour.toStringAsFixed(0)} DH/h',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selected = c);
                      _mapCtrl.move(LatLng(c.latitude, c.longitude), 14);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
