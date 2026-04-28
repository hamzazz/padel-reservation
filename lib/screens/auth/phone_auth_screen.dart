import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'profile_setup_screen.dart';

// Popular country codes (Morocco first)
const _countries = [
  (flag: '🇲🇦', name: 'Maroc', code: '+212'),
  (flag: '🇩🇿', name: 'Algérie', code: '+213'),
  (flag: '🇹🇳', name: 'Tunisie', code: '+216'),
  (flag: '🇫🇷', name: 'France', code: '+33'),
  (flag: '🇪🇸', name: 'Espagne', code: '+34'),
  (flag: '🇧🇪', name: 'Belgique', code: '+32'),
  (flag: '🇨🇭', name: 'Suisse', code: '+41'),
  (flag: '🇬🇧', name: 'UK', code: '+44'),
  (flag: '🇩🇪', name: 'Allemagne', code: '+49'),
];

const _whatsappGreen = Color(0xFF25D366);
const _whatsappDark = Color(0xFF075E54);

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  var _country = _countries[0]; // Morocco default
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (phone.isEmpty || phone.length < 8) {
      setState(() => _error = 'Entrez un numéro valide');
      return;
    }

    // Remove leading 0 for Morocco
    final cleaned = phone.startsWith('0') ? phone.substring(1) : phone;
    final fullNumber = '${_country.code}$cleaned';

    setState(() { _loading = true; _error = null; });

    final error = await context.read<AuthProvider>().sendPhoneOtp(fullNumber);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OtpScreen(phoneNumber: fullNumber),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Choisir le pays',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _countries.map((c) {
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(c.name),
                  trailing: Text(c.code,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    setState(() => _country = c);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _whatsappDark,
        foregroundColor: Colors.white,
        title: const Text('Vérification du téléphone'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // WhatsApp-style icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _whatsappGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _whatsappGreen.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ],
              ),
              child: const Center(
                  child: Text('📱', style: TextStyle(fontSize: 38))),
            ),
            const SizedBox(height: 24),
            const Text('Votre numéro de téléphone',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Vous recevrez un code à 6 chiffres par WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Error
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),

            // Phone input
            Row(
              children: [
                // Country selector
                GestureDetector(
                  onTap: _showCountryPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_country.flag,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(_country.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const Icon(Icons.arrow_drop_down,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                // Number input
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9 \-]'))],
                    decoration: InputDecoration(
                      hintText: '6 12 34 56 78',
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide:
                            BorderSide(color: _whatsappGreen, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _sendCode(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _sendCode,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('📲',
                        style: TextStyle(fontSize: 20)),
                label: Text(
                    _loading ? 'Envoi en cours...' : 'Recevoir le code',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _whatsappGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Le code sera envoyé sur votre WhatsApp.',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP Verification Screen ───────────────────────────────────────────────────

class _OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const _OtpScreen({required this.phoneNumber});
  @override
  State<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<_OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;
  int _seconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _seconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _seconds--);
      if (_seconds <= 0) t.cancel();
    });
  }

  String get _code =>
      _ctrls.map((c) => c.text).join();

  void _onDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _foci[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _foci[index - 1].requestFocus();
    }
    // auto-verify when all 6 digits entered
    if (_code.length == 6) _verify();
  }

  void _onPaste(String pasted) {
    final digits = pasted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _ctrls[i].text = digits[i];
      }
      _foci[5].requestFocus();
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_code.length != 6 || _loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      final result = await context.read<AuthProvider>().verifyPhoneOtp(
        phoneNumber: widget.phoneNumber,
        code: _code,
      );

      if (!mounted) return;

      if (result.error != null) {
        setState(() { _loading = false; _error = result.error; });
        for (final c in _ctrls) c.clear();
        _foci[0].requestFocus();
        return;
      }

      setState(() => _loading = false);

      if (result.isNew) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileSetupScreen(phoneNumber: widget.phoneNumber)),
        );
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Erreur inattendue: $e'; });
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    // Pop back to phone entry to resend
    Navigator.pop(context);
  }

  String _masked() {
    final p = widget.phoneNumber;
    if (p.length > 6) {
      return '${p.substring(0, p.length - 4)}****';
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _whatsappDark,
        foregroundColor: Colors.white,
        title: const Text('Entrez le code'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _whatsappGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Text('🔐', style: TextStyle(fontSize: 38))),
            ),
            const SizedBox(height: 24),
            const Text('Vérification',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(
                      text: 'Nous avons envoyé un code de vérification à '),
                  TextSpan(
                    text: _masked(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // WhatsApp message bubble style
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6), // WhatsApp received message bg
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('📲 ', style: TextStyle(fontSize: 16)),
                      Text('WhatsApp',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Votre code de vérification Padel Club :',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final c = _ctrls[i].text;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 36,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: c.isNotEmpty
                                  ? _whatsappGreen
                                  : Colors.grey.shade300,
                              width: c.isNotEmpty ? 2 : 1),
                        ),
                        child: Center(
                          child: Text(
                            c,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '✓✓',
                      style: TextStyle(
                          color: _whatsappGreen.withOpacity(0.7),
                          fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Error
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),

            // 6-digit input
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                return Container(
                  width: 46,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _ctrls[i],
                    focusNode: _foci[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _whatsappGreen, width: 2),
                      ),
                    ),
                    onChanged: (v) {
                      if (v.length > 1) {
                        _onPaste(v);
                      } else {
                        _onDigitChanged(v, i);
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _code.length != 6) ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _whatsappGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Vérifier le code',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),

            // Resend timer
            _seconds > 0
                ? Text(
                    'Renvoyer le code dans ${_seconds}s',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  )
                : TextButton(
                    onPressed: _resend,
                    child: const Text(
                      'Renvoyer le code',
                      style: TextStyle(color: _whatsappGreen),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
