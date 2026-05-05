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
  final _mapCtrl = MapController();
  final _listCtrl = ScrollController();
  final _distance = const Distance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

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
      if (!mounted) return;
      setState(() {
        _myLocation = loc;
        _locating = false;
      });
      _mapCtrl.move(loc, 12);
    } catch (e) {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<Court> _sortedCourts(List<Court> all) {
    if (_myLocation == null) return all;
    return List<Court>.from(all)
      ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
  }

  void _selectCourt(Court c, List<Court> sorted) {
    setState(() => _selected = c);
    _mapCtrl.move(LatLng(c.latitude, c.longitude), 14);
    final idx = sorted.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_listCtrl.hasClients) {
          _listCtrl.animateTo(
            (idx * 72.0).clamp(0, _listCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCourts = context.watch<CourtProvider>().activeCourts;
    final courts = _sortedCourts(allCourts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terrains à proximité'),
        actions: [
          if (_locating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _myLocation != null ? Icons.my_location : Icons.location_searching,
                color: _myLocation != null ? Colors.lightBlueAccent : Colors.white,
              ),
              tooltip: 'Me localiser',
              onPressed: _locate,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 70 % : Carte ──────────────────────────────────────────
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _myLocation ?? const LatLng(33.0, -7.0),
                    initialZoom: _myLocation != null ? 12 : 5.5,
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.padel.padel_reservation',
                    ),
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
                    MarkerLayer(
                      markers: courts.map((c) {
                        final dist = _distanceTo(c);
                        final shortName = c.name.length > 14
                            ? '${c.name.substring(0, 13)}…'
                            : c.name;
                        return Marker(
                          point: LatLng(c.latitude, c.longitude),
                          width: 96,
                          height: 78,
                          child: GestureDetector(
                            onTap: () {
                              _mapCtrl.move(LatLng(c.latitude, c.longitude), 14);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        BookingScreen(preselectedCourt: c)),
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.sports_tennis,
                                      color: Colors.white, size: 16),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black12, blurRadius: 3)
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        shortName,
                                        style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87),
                                      ),
                                      if (_myLocation != null && dist.isFinite)
                                        Text(
                                          '${dist.toStringAsFixed(1)} km',
                                          style: const TextStyle(
                                              fontSize: 8,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w600),
                                        ),
                                    ],
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
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('© OpenStreetMap contributors',
                        style:
                            TextStyle(fontSize: 9, color: Colors.black54)),
                  ),
                ),
              ],
            ),
          ),

          // ── 30 % : Liste proximité ────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                        top: BorderSide(color: Colors.grey.shade200, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me,
                          color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _locating
                              ? 'Localisation en cours…'
                              : _myLocation != null
                                  ? 'Terrains à proximité (${courts.length})'
                                  : 'Tous les terrains (${courts.length})',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _locating
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _listCtrl,
                          itemCount: courts.length,
                          itemBuilder: (_, i) {
                            final c = courts[i];
                            final isSelected = _selected?.id == c.id;
                            final dist = _distanceTo(c);
                            return InkWell(
                              onTap: () {
                                _selectCourt(c, courts);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          BookingScreen(preselectedCourt: c)),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                color: isSelected
                                    ? AppTheme.primary.withOpacity(0.06)
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primary.withOpacity(0.15)
                                            : c.isIndoor
                                                ? Colors.blue
                                                    .withOpacity(0.1)
                                                : Colors.orange
                                                    .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isSelected
                                                    ? AppTheme.primary
                                                    : c.isIndoor
                                                        ? Colors.blue
                                                        : Colors.orange)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.name,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isSelected
                                                      ? AppTheme.primary
                                                      : null),
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          Text(c.address,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      Colors.grey.shade600),
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (dist.isFinite)
                                          Text(
                                            '${dist.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        Text(
                                          '${c.pricePerHour.toStringAsFixed(0)} DH',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
