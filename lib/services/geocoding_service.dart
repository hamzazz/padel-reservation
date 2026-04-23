import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;

  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<GeocodingResult?> geocode(String address) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
        'addressdetails': '1',
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'PadelClubApp/1.0 (padel.reservation@gmail.com)',
        'Accept-Language': 'fr',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as List;
      if (data.isEmpty) return null;

      final item = data.first as Map<String, dynamic>;
      return GeocodingResult(
        latitude: double.parse(item['lat'] as String),
        longitude: double.parse(item['lon'] as String),
        displayName: item['display_name'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
