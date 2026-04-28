import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/market_service.dart';
import '../state/auth_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen>
    with SingleTickerProviderStateMixin {
  final _svc = MarketService();
  late TabController _tabs;
  List<Product> _all = [];
  List<Product> _mine = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUser?.id;
    _all = await _svc.getAll(category: _selectedCategory);
    if (uid != null) _mine = await _svc.getByUser(uid);
    setState(() => _loading = false);
  }

  Future<void> _addProduct() async {
    final user = context.read<AuthProvider>().currentUser!;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = productCategories.first;
    bool isNew = true;
    File? pickedImage;
    bool uploading = false;
    final formKey = GlobalKey<FormState>();
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Vendre un article',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),

                  // ── Image picker ──────────────────────────────────────
                  GestureDetector(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: ctx,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Prendre une photo'),
                                onTap: () => Navigator.pop(_, ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Choisir depuis la galerie'),
                                onTap: () => Navigator.pop(_, ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (source == null) return;
                      final xfile = await picker.pickImage(
                        source: source,
                        imageQuality: 75,
                        maxWidth: 1080,
                      );
                      if (xfile != null) {
                        setS(() => pickedImage = File(xfile.path));
                      }
                    },
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(pickedImage!,
                                  fit: BoxFit.cover, width: double.infinity),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('Ajouter une photo',
                                    style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Titre'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix (DH)'),
                    validator: (v) =>
                        (v == null || double.tryParse(v) == null)
                            ? 'Prix invalide'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: productCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setS(() => category = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('État : '),
                      ChoiceChip(
                        label: const Text('Neuf'),
                        selected: isNew,
                        onSelected: (_) => setS(() => isNew = true),
                        selectedColor: AppTheme.primary.withOpacity(0.2),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Occasion'),
                        selected: !isNew,
                        onSelected: (_) => setS(() => isNew = false),
                        selectedColor: Colors.orange.withOpacity(0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: uploading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setS(() => uploading = true);
                            await _svc.addProduct(
                              sellerId: user.id,
                              sellerName: user.fullName,
                              sellerEmoji: user.avatarEmoji,
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              price: double.parse(priceCtrl.text),
                              isNew: isNew,
                              category: category,
                              imageFile: pickedImage,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48)),
                    child: uploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Publier l\'annonce'),
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
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _buildList(_all),
                      _buildList(_mine, isMine: true),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.black87),
        label: const Text('Vendre',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        onPressed: _addProduct,
      ),
    );
  }

  Widget _buildHeader() {
    final locale = context.watch<LocaleProvider>();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🛒', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Text(locale.tr('market'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_all.length} article${_all.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.accent,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: locale.locale == 'ar' ? 'الإعلانات' : locale.locale == 'en' ? 'Listings' : 'Annonces'),
              Tab(text: locale.locale == 'ar' ? 'مبيعاتي' : locale.locale == 'en' ? 'My Sales' : 'Mes ventes'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Product> products, {bool isMine = false}) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              isMine ? 'Vous n\'avez aucune annonce' : 'Aucun article disponible',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _ProductCard(
        product: products[i],
        isMine: isMine,
        onSold: isMine
            ? () async {
                await _svc.markSold(products[i].id);
                _load();
              }
            : null,
        onDelete: isMine
            ? () async {
                await _svc.delete(products[i].id, imageUrl: products[i].imageUrl);
                _load();
              }
            : null,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isMine;
  final VoidCallback? onSold;
  final VoidCallback? onDelete;

  const _ProductCard({
    required this.product,
    required this.isMine,
    this.onSold,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ──────────────────────────────────────────────────
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: product.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.grey.shade400),
                ),
              ),
            ),

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
                        Text(product.sellerEmoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(product.sellerName,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.isNew
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.isNew ? 'Neuf' : 'Occasion',
                        style: TextStyle(
                          fontSize: 11,
                          color: product.isNew ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(product.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (product.description.isNotEmpty)
                  Text(product.description,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${product.price.toStringAsFixed(2)} DH',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                    if (isMine)
                      Row(
                        children: [
                          TextButton(
                            onPressed: onSold,
                            child: const Text('Marquer vendu'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: onDelete,
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(product.category,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
