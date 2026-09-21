import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../models/factory_model.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/net_image.dart';
import '../../widgets/site_widgets.dart';
import '../factory_profile/factory_profile_screen.dart';

/// `/factories` on the website: hero, banner, search, filters, featured factories and an
/// infinite-scroll grid of factories (30 per page).
class CompaniesScreen extends StatefulWidget {
  final int? gateId;
  final int? categoryId;
  final String? title;
  final int? opportunityId;
  final String? initialSearch;
  const CompaniesScreen({super.key, this.gateId, this.categoryId, this.title, this.opportunityId, this.initialSearch});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final _scroll = ScrollController();
  final List<FactoryModel> _items = [];
  int _page = 0;
  int _last = 1;
  bool _loading = false;
  String? _error;
  String _search = '';
  int? _gateId;
  int? _categoryId;
  int? _opportunityId;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _search = widget.initialSearch ?? '';
    _gateId = widget.gateId;
    _categoryId = widget.categoryId;
    _opportunityId = widget.opportunityId;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
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
      _items.clear();
      _page = 0;
      _last = 1;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    try {
      // A category uses its own endpoint (covers factories linked through the pivot table).
      final res = await ApiClient.i.get(_categoryId != null ? '/categories/$_categoryId/factories' : '/factories', query: {
        'page': _page + 1,
        'per_page': 30,
        'search': _search,
        if (_categoryId == null) 'gate_id': _gateId,
        if (_categoryId == null) 'opportunity_id': _opportunityId,
        'country_id': AppData.countryId,
      });
      final meta = res['meta'];
      if (!mounted) return;
      setState(() {
        _items.addAll(ApiClient.list(res['data']).map(AppData.factoryFromJson));
        _page++;
        if (meta is Map) {
          _last = (meta['last_page'] as num?)?.toInt() ?? 1;
          _total = (meta['total'] as num?)?.toInt() ?? _items.length;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasFilters => _gateId != null || _categoryId != null || _opportunityId != null;

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        gateId: _gateId,
        categoryId: _categoryId,
        opportunityId: _opportunityId,
        onApply: (g, c, o) {
          setState(() {
            _gateId = g;
            _categoryId = c;
            _opportunityId = o;
          });
          _reset();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final rtl = L10n.i.isRtl;
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _reset,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                SliverToBoxAdapter(child: const HeaderBanner()),
                  SliverToBoxAdapter(child: _hero(rtl)),
                  const SliverToBoxAdapter(child: BannerStrip(location: 'factories')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: Row(children: [
                        Expanded(
                          child: SiteSearchBar(
                            hint: t('gates.search_placeholder', 'ابحث عن مصنع...'),
                            initial: _search,
                            onSubmit: (q) {
                              _search = q.trim();
                              _reset();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openFilters,
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: _hasFilters ? AppColors.gold : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDBDBDB))),
                            child: const Icon(Icons.tune, color: AppColors.dark, size: 22),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (AppData.featured.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
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
                                      netAvatarBox(f.logoUrl, f.emoji),
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
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(widget.title ?? t('nav.factories', 'المصانع'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ),
                  ),
                  if (_items.isEmpty && !_loading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text(_error ?? (_search.isNotEmpty ? t('gates.no_search_results', 'لا توجد نتائج') : t('gates.no_factories', 'لا توجد مصانع')), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.muted))),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.9),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final f = _items[i];
                            return SiteCard(
                              imageUrl: f.logoUrl,
                              brandFallback: true,
                              title: f.name,
                              subTitle: [f.category, f.city].where((e) => e.isNotEmpty).join(' · '),
                              fallback: f.emoji,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: f))),
                            );
                          },
                          childCount: _items.length,
                        ),
                      ),
                    ),
                  if (_loading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.gold)))),
                  const SliverToBoxAdapter(child: SiteFooter()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget netAvatarBox(String url, String emoji) => Container(
        width: 90, height: 90,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFEF8E8)),
        child: NetImage(url: url, brandFallback: true, fallback: emoji, fallbackSize: 20, width: 90, height: 90),
      );

  Widget _hero(bool rtl) => Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withAlpha(10))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              GestureDetector(onTap: () => Navigator.of(context).maybePop(), child: Text(t('nav.home', 'الرئيسية'), style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(rtl ? Icons.chevron_left : Icons.chevron_right, size: 14, color: AppColors.muted)),
              Text(t('factories_hero.breadcrumb', 'المصانع'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ]),
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              TextSpan(text: t('factories_hero.title_highlight', 'المصانع '), style: const TextStyle(color: AppColors.gold)),
              TextSpan(text: t('factories_hero.title_and', 'والشركات')),
            ]), style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 6),
            Text(t('factories_hero.subtitle'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.7)),
            const SizedBox(height: 12),
            Row(children: [
              _stat(Icons.business_center_outlined, '${AppData.stats['total_factories_count'] ?? '—'}', t('factories_hero.stat_factories', 'مصنع مسجل')),
              const SizedBox(width: 10),
              _stat(Icons.grid_view, '${AppData.stats['total_gates_count'] ?? AppData.doors.length}', t('factories_hero.stat_sectors', 'قطاع صناعي')),
            ]),
          ],
        ),
      );

  Widget _stat(IconData icon, String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
              Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted)),
            ]),
          ]),
        ),
      );
}

/// Gate → category, and opportunity filters (the website's `FilterSidebar`).
class _FilterSheet extends StatefulWidget {
  final int? gateId;
  final int? categoryId;
  final int? opportunityId;
  final void Function(int? gate, int? category, int? opportunity) onApply;
  const _FilterSheet({required this.gateId, required this.categoryId, required this.opportunityId, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _gate;
  int? _category;
  int? _opp;
  List<Map<String, dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _gate = widget.gateId;
    _category = widget.categoryId;
    _opp = widget.opportunityId;
    _loadSubs();
  }

  Future<void> _loadSubs() async {
    if (_gate == null) return;
    final subs = await AppData.fetchSubcategories(_gate!);
    if (mounted) setState(() => _subs = subs);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: active ? AppColors.gold : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? AppColors.gold : AppColors.border)),
          child: Text(label, style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: AppColors.dark)),
        ),
      );

  Widget _title(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Text(s, style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                Text(t('filters.title', 'الفلاتر'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: () => setState(() { _gate = null; _category = null; _opp = null; _subs = []; }), child: Text(t('filters.reset', 'إعادة ضبط'), style: GoogleFonts.tajawal(color: AppColors.red, fontWeight: FontWeight.w700))),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _title(t('nav.gates', 'الأبواب')),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final d in AppData.doors)
                      _chip(d['name'] as String, _gate == d['id'], () {
                        setState(() {
                          _gate = _gate == d['id'] ? null : d['id'] as int;
                          _category = null;
                          _subs = [];
                        });
                        _loadSubs();
                      }),
                  ]),
                  if (_subs.isNotEmpty) ...[
                    _title(t('nav.categories', 'الأقسام')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in _subs) _chip(s['name'] as String, _category == s['id'], () => setState(() => _category = _category == s['id'] ? null : s['id'] as int)),
                    ]),
                  ],
                  if (AppData.opportunities.isNotEmpty) ...[
                    _title(t('gates.opportunities', 'الفرص')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final o in AppData.opportunities) _chip(o.title, _opp == int.tryParse(o.id), () => setState(() => _opp = _opp == int.tryParse(o.id) ? null : int.tryParse(o.id))),
                    ]),
                  ],
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_gate, _category, _opp);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(t('filters.apply', 'تطبيق'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
