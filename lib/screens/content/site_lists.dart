import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_data.dart';
import '../../models/factory_model.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/apply_sheet.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/net_image.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../../widgets/site_widgets.dart';
import '../factory_profile/factory_profile_screen.dart';

Future<void> _launch(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _plain(String s) => s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('&nbsp;', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _first(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = AppData.tr(m, k);
    if (v.isNotEmpty) return v;
  }
  return '';
}

Widget _heroCard(BuildContext context, String breadcrumb, String title, String subtitle, {String? highlight, List<Widget> stats = const []}) {
  final rtl = L10n.i.isRtl;
  return Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withAlpha(10))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(onTap: () => context.go('/'), child: Text(t('nav.home', 'الرئيسية'), style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(rtl ? Icons.chevron_left : Icons.chevron_right, size: 14, color: AppColors.muted)),
        Text(breadcrumb, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
      ]),
      const SizedBox(height: 10),
      Text.rich(TextSpan(children: [if (highlight != null) TextSpan(text: highlight, style: const TextStyle(color: AppColors.gold)), TextSpan(text: title)]), style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.4)),
      const SizedBox(height: 6),
      Text(subtitle, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.7)),
      if (stats.isNotEmpty) ...[const SizedBox(height: 12), Row(children: stats)],
    ]),
  );
}

Widget _statBox(IconData icon, String n, String label) => Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: 8),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted)),
          ])),
        ]),
      ),
    );

// ═══════════════════════════════ Sponsors ═══════════════════════════════

class SponsorsScreen extends StatefulWidget {
  const SponsorsScreen({super.key});

  @override
  State<SponsorsScreen> createState() => _SponsorsScreenState();
}

class _SponsorsScreenState extends State<SponsorsScreen> {
  Map<String, List<FactoryModel>> _groups = {};
  int _packages = 0;
  int _factories = 0;
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AppData.fetchBanners('sponsors').then((b) {
      if (mounted) setState(() => _banners = List.of(b)..shuffle());
    });
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.i.get('/sponsers');
      final d = res['data'];
      final groups = <String, List<FactoryModel>>{};
      if (d is Map && d['factories'] is Map) {
        (d['factories'] as Map).forEach((k, v) => groups['$k'] = ApiClient.list(v).map(AppData.factoryFromJson).toList());
      }
      if (mounted) {
        setState(() {
          _groups = groups;
          _packages = (d is Map ? d['packages_count'] as num? : null)?.toInt() ?? 0;
          _factories = (d is Map ? d['factories_count'] as num? : null)?.toInt() ?? groups.values.fold(0, (a, b) => a + b.length);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _grid(List<FactoryModel> list) => Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: [
            for (final f in list)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: f))),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Expanded(child: Container(width: double.infinity, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)), child: NetImage(url: f.logoUrl, brandFallback: true, fallbackSize: 24, fit: BoxFit.contain, width: double.infinity, height: double.infinity))),
                    const SizedBox(height: 6),
                    Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text([f.city, f.country].where((e) => e.isNotEmpty).join('، '), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.muted)),
                  ]),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final order = ['sponsors-banners', 'global-premium', 'local-premium'];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
                const HeaderBanner(),
            _heroCard(context, t('sponsors_page.breadcrumb', 'الرعاة والشركاء'), t('sponsors_page.title_and', 'والشركاء'), t('sponsors_page.subtitle'), highlight: t('sponsors_page.title_highlight', 'الرعاة '), stats: [
              _statBox(Icons.description_outlined, _loading ? '…' : '$_packages', t('sponsors_page.sponsorship_packages', 'باقات رعاية')),
              _statBox(Icons.business_center_outlined, _loading ? '…' : '$_factories', t('sponsors_page.registered_factories', 'مصنع مسجل')),
            ]),
            if (_loading)
              emptyState('', loading: true)
            else ...[
              for (var i = 0; i < order.length; i++) ...[
                if (_banners.length > i) PromoBanner(banner: _banners[i]),
                if ((_groups[order[i]] ?? []).isNotEmpty) _grid(_groups[order[i]]!),
              ],
              if (_groups.values.every((g) => g.isEmpty)) emptyState(t('gates.no_data', 'لا توجد بيانات حالياً')),
            ],
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.dark, Color(0xFF3D3A35)]), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text(t('sponsors_page.join_title'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(t('sponsors_page.join_subtitle'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white70, height: 1.6)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => context.push('/contact'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text(t('sponsors_page.contact_now', 'تواصل معنا الآن'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
              ]),
            ),
            const SiteFooter(),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════ Generic API list page ═══════════════════════════════

/// Paginated list of cards from a public endpoint (exhibitions, blog posts, jobs, CVs).
class _ApiListPage extends StatefulWidget {
  final String path;
  final String breadcrumb;
  final String title;
  final String subtitle;
  final String emptyText;
  final String? searchHint;
  final Widget Function(BuildContext, Map<String, dynamic>) card;
  final String? bannerLocation;
  final Widget Function(BuildContext)? topAction;
  const _ApiListPage({required this.path, required this.breadcrumb, required this.title, required this.subtitle, required this.emptyText, required this.card, this.searchHint, this.bannerLocation, this.topAction});

  @override
  State<_ApiListPage> createState() => _ApiListPageState();
}

class _ApiListPageState extends State<_ApiListPage> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _last = 1;
  int _total = 0;
  bool _loading = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _more();
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
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    try {
      final res = await ApiClient.i.get(widget.path, query: {'page': _page + 1, 'per_page': 20, 'search': _search});
      final meta = res['meta'];
      if (!mounted) return;
      setState(() {
        _items.addAll(ApiClient.list(res['data']));
        _page++;
        if (meta is Map) {
          _last = (meta['last_page'] as num?)?.toInt() ?? 1;
          _total = (meta['total'] as num?)?.toInt() ?? _items.length;
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.gold,
        onRefresh: _reset,
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
                const HeaderBanner(),
            _heroCard(context, widget.breadcrumb, widget.title, widget.subtitle, stats: [_statBox(Icons.list_alt, '$_total', widget.breadcrumb)]),
            if (widget.bannerLocation != null) BannerStrip(location: widget.bannerLocation!),
            if (widget.searchHint != null)
              Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), child: SiteSearchBar(hint: widget.searchHint!, onSubmit: (q) { _search = q.trim(); _reset(); })),
            if (widget.topAction != null) widget.topAction!(context),
            if (_items.isEmpty && !_loading)
              emptyState(widget.emptyText)
            else
              for (final it in _items) widget.card(context, it),
            if (_loading) emptyState('', loading: true),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

Widget _infoCard({required BuildContext context, String? image, required String title, String? subtitle, String? body, List<(IconData, String)> meta = const [], String? actionLabel, VoidCallback? onTap, VoidCallback? onAction}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image != null && image.isNotEmpty) SizedBox(height: 170, width: double.infinity, child: NetImage(url: image, fallback: '', width: double.infinity, height: 170)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.4)),
            if (subtitle != null && subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle, style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.gold, fontWeight: FontWeight.w700))),
            if (body != null && body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF4A5568), height: 1.7))),
            if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 12, runSpacing: 4, children: [for (final m in meta) Row(mainAxisSize: MainAxisSize.min, children: [Icon(m.$1, size: 14, color: AppColors.gold), const SizedBox(width: 4), Text(m.$2, style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))])])),
            if (actionLabel != null) Padding(padding: const EdgeInsets.only(top: 10), child: ElevatedButton(onPressed: onAction, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(actionLabel, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)))),
          ]),
        ),
      ]),
    ),
  );
}

String _date(dynamic iso) {
  final t = iso == null ? null : DateTime.tryParse('$iso')?.toLocal();
  if (t == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}

// ═══════════════════════════════ Exhibitions / Blog / Jobs / CVs ═══════════════════════════════

class ExhibitionsScreen extends StatelessWidget {
  const ExhibitionsScreen({super.key});

  @override
  Widget build(BuildContext context) => _ApiListPage(
        path: '/exhibitions',
        breadcrumb: t('nav.exhibitions', 'المعارض'),
        title: t('nav.exhibitions', 'المعارض'),
        subtitle: t('exhibitionsSubtitle', '').replaceAll('{count}', ''),
        emptyText: t('gates.no_data', 'لا توجد بيانات حالياً'),
        bannerLocation: 'exhibitions',
        card: (context, e) => _infoCard(
          context: context,
          image: e['image_url'] as String?,
          title: _first(e, ['title', 'name']),
          subtitle: _first(e, ['location', 'venue', 'city']),
          body: _plain(_first(e, ['description', 'summary', 'content'])),
          meta: [
            if (e['start_date'] != null) (Icons.event, '${_date(e['start_date'])}${e['end_date'] != null ? ' - ${_date(e['end_date'])}' : ''}'),
            if (e['factories_count'] != null) (Icons.factory_outlined, '${e['factories_count']}'),
          ],
          actionLabel: '${e['link'] ?? ''}'.isNotEmpty ? t('exhibitions.register_now', 'سجل الآن') : null,
          onAction: () => _launch('${e['link']}'),
        ),
      );
}

class BlogScreen extends StatelessWidget {
  const BlogScreen({super.key});

  @override
  Widget build(BuildContext context) => _ApiListPage(
        path: '/blog-posts',
        breadcrumb: t('nav.blog', 'المدونة'),
        title: t('blog_page.title_part2', 'المصانع'),
        subtitle: t('blog_page.description'),
        emptyText: t('blog_page.no_data', 'لا توجد مقالات حالياً.'),
        bannerLocation: 'blog_posts',
        card: (context, p) => _infoCard(
          context: context,
          image: p['image_url'] as String?,
          title: _first(p, ['title', 'name']),
          body: _plain(_first(p, ['excerpt', 'summary', 'content', 'description'])),
          meta: [if (p['created_at'] != null) (Icons.calendar_today_outlined, _date(p['created_at']))],
          onTap: () => context.push('/blog/${p['id']}'),
        ),
      );
}

class BlogDetailScreen extends StatelessWidget {
  final String id;
  const BlogDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiClient.i.get('/blog-posts/$id').then((r) => Map<String, dynamic>.from(r['data'] as Map)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        final p = snap.data;
        if (p == null) return emptyState(t('blog_page.no_data', 'لا توجد مقالات حالياً.'));
        return ListView(padding: EdgeInsets.zero, children: [
                const HeaderBanner(),
          if ('${p['image_url'] ?? ''}'.isNotEmpty) SizedBox(height: 220, width: double.infinity, child: NetImage(url: '${p['image_url']}', fallback: '', width: double.infinity, height: 220)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_first(p, ['title', 'name']), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, height: 1.4)),
              const SizedBox(height: 4),
              Text(_date(p['created_at']), style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              Text(_plain(_first(p, ['content', 'body', 'description'])), style: GoogleFonts.tajawal(fontSize: 15, color: const Color(0xFF4A5568), height: 1.9)),
            ]),
          ),
          const SiteFooter(),
        ]);
      },
    );
  }
}

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) => _ApiListPage(
        path: '/jobs',
        breadcrumb: t('nav.jobs', 'الوظائف'),
        title: t('jobs.hero_title', 'فرص التأهيل والوظائف'),
        subtitle: t('jobs.hero_sub'),
        emptyText: t('jobs.no_jobs', 'لا توجد وظائف'),
        searchHint: t('jobs.search_ph', 'البحث عن وظيفة...'),
        card: (context, j) {
          final f = j['factory'] is Map ? Map<String, dynamic>.from(j['factory'] as Map) : <String, dynamic>{};
          final salary = j['salary'] ?? ((j['salary_min'] != null) ? '${j['salary_min']} - ${j['salary_max'] ?? ''} ${j['salary_currency'] ?? ''}' : null);
          return _infoCard(
            context: context,
            title: _first(j, ['title', 'name']),
            subtitle: AppData.tr(f, 'name').isNotEmpty ? AppData.tr(f, 'name') : t('jobs.unknown_factory', 'مصنع غير معروف'),
            body: _plain(_first(j, ['description', 'requirements'])),
            meta: [
              if ('${j['type'] ?? ''}'.isNotEmpty) (Icons.work_outline, '${j['type']}'),
              if (salary != null) (Icons.payments_outlined, '$salary'),
              if (j['deadline'] != null) (Icons.event_busy, _date(j['deadline'])),
            ],
            actionLabel: t('jobs.apply_now', 'قدم الآن'),
            onAction: () => ApplySheet.job(context, jobId: (j['id'] as num).toInt(), title: _first(j, ['title', 'name'])),
          );
        },
      );
}

class CvsScreen extends StatelessWidget {
  const CvsScreen({super.key});

  @override
  Widget build(BuildContext context) => _ApiListPage(
        path: '/cvs',
        breadcrumb: t('nav.cvs', 'طلبات التوظيف'),
        title: t('cvs.title', 'السير الذاتية وطلبات التوظيف'),
        subtitle: t('cvs.subtitle', 'تصفح أحدث السير الذاتية.'),
        emptyText: t('cvs.no_cvs_available', 'لا توجد سير ذاتية متاحة حالياً.'),
        searchHint: t('cvs.search_placeholder', 'ابحث عن مسمى وظيفي...'),
        topAction: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ElevatedButton.icon(
            onPressed: () => ApplySheet.cv(context),
            icon: const Icon(Icons.upload_file, color: AppColors.dark),
            label: Text(t('jobs.upload_cv', 'رفع السيرة الذاتية'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        card: (context, c) => _infoCard(
          context: context,
          title: '${c['full_name'] ?? ''}',
          subtitle: '${c['job_title'] ?? ''}'.isEmpty ? t('cvs.no_job_title', 'بدون مسمى وظيفي') : '${c['job_title']}',
          body: '${c['description'] ?? ''}',
          meta: [if (c['created_at'] != null) (Icons.calendar_today_outlined, _date(c['created_at']))],
          actionLabel: '${c['cv_url'] ?? ''}'.isNotEmpty ? t('cvs.view_cv', 'عرض السيرة الذاتية') : null,
          onAction: () => _launch('${c['cv_url']}'),
        ),
      );
}
