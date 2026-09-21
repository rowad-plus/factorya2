import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_data.dart';
import '../../models/factory_model.dart';
import '../../models/product_model.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/net_image.dart';
import '../../widgets/site_footer.dart';
import '../factory_profile/factory_profile_screen.dart';

/// `/product/{id}`: image gallery with thumbnails, category badge, name, price, description,
/// the factory mini card (visit factory) and the "order via WhatsApp" action.
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _p;
  String? _error;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    ApiClient.i.get('/products/${widget.product.id}').then((r) {
      if (mounted) setState(() => _p = Map<String, dynamic>.from(r['data'] as Map));
    }).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final p = _p;
        return Scaffold(
          backgroundColor: Colors.white,
          body: p == null
              ? Stack(children: [
                  Center(child: _error != null ? Text(t('product_details.product_not_found', 'المنتج غير موجود'), style: GoogleFonts.tajawal(color: AppColors.muted)) : const CircularProgressIndicator(color: AppColors.gold)),
                  _back(),
                ])
              : _content(p),
        );
      },
    );
  }

  Widget _back() => Positioned(
        top: 8,
        left: L10n.i.isRtl ? null : 8,
        right: L10n.i.isRtl ? 8 : null,
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 6)]),
            child: Icon(L10n.i.isRtl ? Icons.arrow_forward : Icons.arrow_back, size: 18, color: AppColors.dark),
          ),
        ),
      );

  Widget _content(Map<String, dynamic> p) {
    final images = p['images'] is List ? (p['images'] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList() : <String>[];
    final factory = p['factory'] is Map ? Map<String, dynamic>.from(p['factory'] as Map) : <String, dynamic>{};
    final cats = p['categories'] is List ? ApiClient.list(p['categories']) : <Map<String, dynamic>>[];
    final name = AppData.tr(p, 'name').isNotEmpty ? AppData.tr(p, 'name') : t('product_details.default_name', 'اسم المنتج');
    final desc = AppData.tr(p, 'description').isNotEmpty ? AppData.tr(p, 'description') : t('product_details.default_description', 'لا يوجد وصف لهذا المنتج حالياً.');
    final category = cats.isNotEmpty ? AppData.tr(cats.first, 'name') : t('product_details.uncategorized', 'غير مصنف');
    final price = p['price'] != null ? t('product_details.price_sar', '{price} ر.س').replaceAll('{price}', '${p['price']}') : t('product_details.price_on_request', 'السعر عند التواصل');
    final factoryName = AppData.tr(factory, 'name');
    final phone = '${factory['phone'] ?? factory['phone_number'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    final specs = [
      (t('product_details.status_label', 'الحالة'), t('product_details.new_status', 'جديد')),
      (t('product_details.industry_label', 'الصناعة'), t('product_details.national_industry', 'وطني')),
      if ('${p['color'] ?? ''}'.isNotEmpty) (t('product.color', 'اللون'), '${p['color']}'),
      if ('${p['material'] ?? ''}'.isNotEmpty) (t('product.material', 'الخامة'), '${p['material']}'),
      if ('${p['warranty'] ?? ''}'.isNotEmpty) (t('product.warranty', 'الضمان'), '${p['warranty']}'),
      if ('${p['manufacturing'] ?? ''}'.isNotEmpty) (t('product.manufacturing', 'بلد الصنع'), '${p['manufacturing']}'),
    ];
    return Stack(children: [
      ListView(
        padding: EdgeInsets.zero,
        children: [
                const HeaderBanner(),
          Container(
            height: 320,
            color: AppColors.bg,
            child: NetImage(url: images.isNotEmpty ? images[_selected.clamp(0, images.length - 1)] : '', fallback: name.isEmpty ? '?' : String.fromCharCode(name.runes.first), fallbackSize: 60, fit: BoxFit.contain, width: double.infinity, height: 320),
          ),
          if (images.length > 1)
            SizedBox(
              height: 78,
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    width: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _selected == i ? AppColors.gold : Colors.transparent, width: 2)),
                    child: NetImage(url: images[i], fallback: '', width: 58, height: 58),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(20)),
                        child: Text(category, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ),
                      const SizedBox(height: 8),
                      Text(name, style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.4)),
                    ]),
                  ),
                  IconButton(onPressed: () => Share.share('$name\nhttps://factorya.net/product/${p['id']}'), icon: const Icon(Icons.share_outlined, color: AppColors.muted)),
                ]),
                const SizedBox(height: 12),
                Text(price, style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold)),
                const SizedBox(height: 12),
                Text(desc, style: GoogleFonts.tajawal(fontSize: 14, color: const Color(0xFF4A5568), height: 1.8)),
                const SizedBox(height: 16),
                for (final s in specs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Expanded(child: Text(s.$1, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted))),
                      Text(s.$2, style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ]),
                  ),
                if (factoryName.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(
                        width: 52, height: 52,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white),
                        child: NetImage(url: AppData.logoUrl(factory), brandFallback: true, fallbackSize: 14, width: 52, height: 52, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(factoryName, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text))),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: FactoryModel(id: '${p['factory_id'] ?? factory['id']}', name: factoryName, category: '', emoji: '🏭')))),
                        child: Text(t('product_details.visit_factory', 'زيارة المصنع'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ),
                    ]),
                  ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _open('https://wa.me/$phone?text=${Uri.encodeComponent(t('product_details.whatsapp_msg_template', 'أهلاً بك، أريد الاستفسار عن منتج: {productName}').replaceAll('{productName}', name))}'),
                      icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                      label: Text(t('product_details.order_via_whatsapp', 'طلب المنتج عبر واتساب'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SiteFooter(),
        ],
      ),
      _back(),
    ]);
  }
}
