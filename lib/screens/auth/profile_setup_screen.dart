import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phoneNumber;
  const ProfileSetupScreen({super.key, required this.phoneNumber});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  String _avatar = '🎾';
  int _level = 1;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre prénom');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final auth = context.read<AuthProvider>();
    await auth.updateProfile(
      auth.currentUser!.copyWith(
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        avatarEmoji: _avatar,
        level: _level,
      ),
    );

    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compléter votre profil'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 2),
                    ),
                    child: Center(
                        child: Text(_avatar,
                            style: const TextStyle(fontSize: 40))),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.phoneNumber,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Avatar
            const Text('Choisissez votre avatar :',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: avatarEmojis.map((e) => GestureDetector(
                onTap: () => setState(() => _avatar = e),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _avatar == e
                        ? AppTheme.primary.withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _avatar == e
                            ? AppTheme.primary
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: Center(
                      child: Text(e,
                          style: const TextStyle(fontSize: 26))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),

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
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),

            // Name fields
            TextField(
              controller: _firstCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Prénom *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _lastCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),

            // Level
            const Text('Votre niveau de jeu :',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _levelSelector(),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Commencer à jouer !',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(8, (i) {
        final lvl = i + 1;
        final isSelected = _level == lvl;
        return GestureDetector(
          onTap: () => setState(() => _level = lvl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.grey.shade300),
            ),
            child: Text(
              'N$lvl',
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w600),
            ),
          ),
        );
      }),
    );
  }
}
