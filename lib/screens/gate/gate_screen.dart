import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/net_image.dart';
import '../../widgets/site_footer.dart';
import '../../widgets/site_widgets.dart';
import '../companies/companies_screen.dart';
import '../factory_profile/factory_profile_screen.dart';

/// `/gates/{id}` on the website: banner, category search, featured factories, a gate switcher
/// and the paginated grid of the gate's categories (tap opens the category's factories).
class GateScreen extends StatefulWidget {
  final Map<String, dynamic> door;
  const GateScreen({super.key, required this.door});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _cats = [];
  late int _gateId = widget.door['id'] as int;
  late String _gateName = widget.door['name'] as String;
  Map<String, dynamic>? _banner;
  int _page = 0;
  int _last = 1;
  bool _loading = false;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    AppData.fetchBanners('gates').then((b) {
      if (mounted && b.isNotEmpty) setState(() => _banner = b[Random().nextInt(b.length)]);
    });
    _reset();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() {
      _cats.clear();
      _page = 0;
      _last = 1;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    final gate = _gateId;
    try {
      final res = await ApiClient.i.get('/gates/$gate/categories', query: {'page': _page + 1, 'per_page': 30, 'search': _search});
      if (!mounted || gate != _gateId) return;
      final meta = res['meta'];
      setState(() {
        _cats.addAll(ApiClient.list(res['data']));
        _page++;
        if (meta is Map) _last = (meta['last_page'] as num?)?.toInt() ?? 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickGate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            children: [
              for (final d in AppData.doors)
                ListTile(
                  selected: d['id'] == _gateId,
                  selectedTileColor: AppColors.gold3,
                  title: Text(d['name'] as String, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: d['id'] == _gateId ? FontWeight.w700 : FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      _gateId = d['id'] as int;
                      _gateName = d['name'] as String;
                      _search = '';
                    });
                    _reset();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _reset,
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const HeaderBanner(),
                if (_banner != null) Padding(padding: const EdgeInsets.only(top: 8), child: PromoBanner(banner: _banner!, fullWidth: true)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: SiteSearchBar(
                    hint: t('gates.search_placeholder_category', 'ابحث عن قسم أو تصنيف...'),
                    onSubmit: (q) {
                      _search = q.trim();
                      _reset();
                    },
                  ),
                ),
                if (AppData.featured.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('home.featured_factories', 'أهم المصانع'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: AppData.featured.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final f = AppData.featured[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: f))),
                              child: SizedBox(
                                width: 100,
                                child: Column(children: [
                                  Container(
                                    width: 90, height: 90,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: const BoxDecoration(shape: BoxShape.circle),
                                    child: NetImage(url: f.logoUrl, brandFallback: true, fallback: f.emoji, fallbackSize: 20, width: 90, height: 90),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 11.5, height: 1.3)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: GestureDetector(
                    onTap: _pickGate,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(children: [
                        const Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_gateName.isEmpty ? t('home.gates', 'الأبواب') : _gateName, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text))),
                        const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF999999)),
                      ]),
                    ),
                  ),
                ),
                if (_cats.isEmpty && !_loading)
                  Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(_error ?? (_search.isNotEmpty ? t('gates.no_search_results', 'لا توجد نتائج') : t('gates.no_categories', 'لا توجد تصنيفات')), style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.muted))))
                else
                  CardsGrid(
                    children: [
                      for (final c in _cats)
                        () {
                          final count = (c['factories_count'] as num?)?.toInt() ?? 0;
                          final name = AppData.tr(c, 'name');
                          return SiteCard(
                            imageUrl: c['image_url'] as String?,
                            title: name,
                            subTitle: '$count ${count == 1 ? t('gates.factory_single', 'مصنع') : t('gates.factories_plural', 'مصانع')}',
                            fallback: AppData.gateEmoji(name),
                            onTap: count <= 0 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompaniesScreen(categoryId: c['id'] as int, title: name))),
                          );
                        }(),
                    ],
                  ),
                if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.gold))),
                const SiteFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}
