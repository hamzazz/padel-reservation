import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../models/wallet_transaction.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletSvc = WalletService();
  List<WalletTransaction> _txs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid != null) {
      _txs = await _walletSvc.getTransactions(uid);
    }
    setState(() => _loading = false);
  }

  Future<void> _showRecharge() async {
    final amounts = [20.0, 50.0, 100.0, 200.0];
    double chosen = 50;
    final cardCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recharger le wallet',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  // Amount chips
                  Wrap(
                    spacing: 10,
                    children: amounts.map((a) {
                      return ChoiceChip(
                        label: Text('${a.toStringAsFixed(0)} DH'),
                        selected: chosen == a,
                        onSelected: (_) => setS(() => chosen = a),
                        selectedColor:
                            AppTheme.primary.withOpacity(0.15),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: holderCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      labelText: 'Titulaire',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: cardCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.credit_card),
                      labelText: 'Numéro de carte',
                    ),
                    validator: (v) =>
                        (v == null || v.length < 16) ? '16 chiffres' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: expiryCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                              labelText: 'MM/AA'),
                          validator: (v) =>
                              (v == null || v.length < 4) ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: cvvCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration:
                              const InputDecoration(labelText: 'CVV'),
                          validator: (v) =>
                              (v == null || v.length < 3) ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_card),
                    label: Text(
                        'Recharger ${chosen.toStringAsFixed(0)} DH'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await Future.delayed(const Duration(seconds: 1));
                      if (!mounted) return;
                      await context
                          .read<AuthProvider>()
                          .rechargeWallet(chosen);
                      Navigator.pop(ctx);
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${chosen.toStringAsFixed(0)} DH ajoutés !'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, 50)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Solde disponible',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        '${user?.walletBalance.toStringAsFixed(2) ?? '0.00'} DH',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add,
                            color: AppTheme.primary),
                        label: const Text('Recharger',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold)),
                        onPressed: _showRecharge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Historique',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_txs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Aucune transaction',
                          style: TextStyle(
                              color: Colors.grey.shade500)),
                    ),
                  )
                else
                  ..._txs.map((tx) => _TxTile(tx: tx)),
              ],
            ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCredit
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          child: Icon(
            isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
        title: Text(tx.description,
            style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} ${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} DH',
          style: TextStyle(
            color: isCredit ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
