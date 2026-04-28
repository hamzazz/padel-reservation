import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// WhatsApp notifications via UltraMsg API (ultramsg.com)
// Admin must set app_config/whatsapp doc in Firestore:
//   { "instanceId": "...", "token": "..." }
class WhatsAppService {
  static String? _instanceId;
  static String? _token;
  static bool _loaded = false;

  static Future<void> _load() async {
    if (_loaded) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('whatsapp')
          .get();
      if (doc.exists) {
        _instanceId = doc.data()?['instanceId'] as String?;
        _token = doc.data()?['token'] as String?;
      }
      _loaded = true; // only mark loaded after successful read
    } catch (_) {}
  }

  static bool get isConfigured =>
      _instanceId != null &&
      _instanceId!.isNotEmpty &&
      _token != null &&
      _token!.isNotEmpty;

  /// Reload config (call after admin saves new credentials)
  static void reset() {
    _loaded = false;
    _instanceId = null;
    _token = null;
  }

  /// Send a WhatsApp message. Fails silently if not configured or phone empty.
  static Future<void> send(String phone, String message) async {
    await _load();
    if (!isConfigured) return;
    final p = _normalizePhone(phone);
    if (p.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('https://api.ultramsg.com/$_instanceId/messages/chat'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'token=$_token&to=${Uri.encodeComponent(p)}'
                '&body=${Uri.encodeComponent(message)}&priority=10',
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static String _normalizePhone(String raw) {
    var p = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (p.isEmpty) return '';
    if (!p.startsWith('+')) p = '+$p';
    return p;
  }
}
