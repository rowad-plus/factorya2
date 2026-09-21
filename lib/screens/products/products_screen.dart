import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../models/product_model.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/net_image.dart';
import '../../widgets/site_footer.dart';
import '../../widgets/site_widgets.dart';
import '../product_detail/product_detail_screen.dart';

/// `/products-services` on the website: hero with stats, products banner, search and the
/// paginated grid of products (20 per page).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _scroll = ScrollController();
  List<ProductModel> _items = [];
  int _page = 1;
  int _last = 1;
  int _total = 0;
  bool _loading = true;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.i.get('/products', query: {'page': page, 'per_page': 20, 'search': _search, 'country_id': AppData.countryId});
      final meta = res['meta'];
      if (!mounted) return;
      setState(() {
        _items = ApiClient.list(res['data']).map(AppData.productFromJson).toList();
        _page = page;
        if (meta is Map) {
          _last = (meta['last_page'] as num?)?.toInt() ?? 1;
          _total = (meta['total'] as num?)?.toInt() ?? _items.length;
        }
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stat(IconData icon, String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final rtl = L10n.i.isRtl;
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => _load(1),
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
                const HeaderBanner(),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withAlpha(10))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(t('nav.home', 'الرئيسية'), style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(rtl ? Icons.chevron_left : Icons.chevron_right, size: 14, color: AppColors.muted)),
                      Text(t('products_hero.breadcrumb', 'المنتجات'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                    ]),
                    const SizedBox(height: 10),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: t('products_hero.title_highlight', 'المنتجات'), style: const TextStyle(color: AppColors.gold)),
                      TextSpan(text: ' ${t('products_hero.title_and', '')}'),
                    ]), style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text(t('products_hero.subtitle'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.7)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _stat(Icons.inventory_2_outlined, '$_total', t('products_hero.stat_products', 'منتج')),
                      const SizedBox(width: 10),
                      _stat(Icons.factory_outlined, '${AppData.stats['total_factories_count'] ?? '—'}', t('products_hero.stat_factories', 'مصنع مسجل')),
                    ]),
                  ],
                ),
              ),
              const BannerStrip(location: 'products'),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: SiteSearchBar(
                  hint: t('gates.search_placeholder_product', 'ابحث عن منتج...'),
                  onSubmit: (q) {
                    _search = q.trim();
                    _load(1);
                  },
                ),
              ),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
              else if (_items.isEmpty)
                Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(_error ?? t('gates.no_data', 'لا توجد بيانات حالياً'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.muted))))
              else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  children: [
                    for (final p in _items)
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(16)),
                          child: Column(children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: NetImage(url: p.imageUrl, fallback: p.name.isEmpty ? '?' : String.fromCharCode(p.name.runes.first), fallbackSize: 30, width: double.infinity, height: 150),
                            ),
                            Expanded(child: Center(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)))),
                          ]),
                        ),
                      ),
                  ],
                ),
              SitePagination(current: _page, last: _last, onPage: _load),
              const SiteFooter(),
            ],
          ),
        );
      },
    );
  }
}
