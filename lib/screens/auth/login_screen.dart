import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../../state/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await context
        .read<AuthProvider>()
        .login(_emailCtrl.text.trim(), _passCtrl.text);
    if (mounted) setState(() => _loading = false);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  Future<void> _socialLogin(String provider) async {
    setState(() => _loading = true);
    String? err;
    if (provider == 'Google') {
      err = await context.read<AuthProvider>().loginWithGoogle();
    } else if (provider == 'Facebook') {
      err = await context.read<AuthProvider>().loginWithFacebook();
    }
    if (mounted) setState(() => _loading = false);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Language picker at top
              Align(
                alignment: locale.isRtl
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: _LanguagePicker(),
              ),
              const SizedBox(height: 24),
              // Logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                    child: Text('🎾', style: TextStyle(fontSize: 42))),
              ),
              const SizedBox(height: 20),
              Text(locale.tr('appName'),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(locale.tr('connectContinue'),
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection:
                          locale.isRtl ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        labelText: locale.tr('email'),
                        hintText: 'votre@email.com',
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Email invalide'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textDirection:
                          locale.isRtl ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: locale.tr('password'),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 4)
                          ? 'Minimum 4 caractères'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52)),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(locale.tr('login')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(locale.tr('or'),
                        style: TextStyle(color: Colors.grey.shade500)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _socialBtn(
                      label: locale.tr('loginWithGoogle'),
                      emoji: '🔴',
                      onTap: _loading ? null : () => _socialLogin('Google'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _socialBtn(
                      label: locale.tr('loginWithFacebook'),
                      emoji: '🔵',
                      onTap: _loading ? null : () => _socialLogin('Facebook'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${locale.tr('noAccount')} ',
                      style: TextStyle(color: Colors.grey.shade600)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(locale.tr('register'),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(locale.tr('demoAccounts'),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _demoRow('Admin', 'admin@padel.com', 'admin123'),
                    _demoRow('Joueur', 'demo@padel.com', 'demo123'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialBtn(
      {required String label,
      required String emoji,
      required VoidCallback? onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _demoRow(String role, String email, String pass) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: GestureDetector(
        onTap: () {
          _emailCtrl.text = email;
          _passCtrl.text = pass;
        },
        child: Text('$role: $email / $pass',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langBtn(context, 'fr', '🇫🇷', locale),
          _langBtn(context, 'en', '🇬🇧', locale),
          _langBtn(context, 'ar', '🇸🇦', locale),
        ],
      ),
    );
  }

  Widget _langBtn(
      BuildContext context, String code, String flag, LocaleProvider locale) {
    final isSelected = locale.locale == code;
    return GestureDetector(
      onTap: () => locale.setLocale(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(flag, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
