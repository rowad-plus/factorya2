import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import 'dash_kit.dart';

/// Owner analytics (GET /factory-dashboard/analytics). Depth follows the package:
/// none → upgrade notice; basic → 7/30-day visits + quotes; detailed → daily chart + top posts;
/// full → 90-day chart + visitor countries. Same data as the site's dashboard panel.
class DashAnalytics extends StatefulWidget {
  const DashAnalytics({super.key});

  @override
  State<DashAnalytics> createState() => _DashAnalyticsState();
}

class _DashAnalyticsState extends State<DashAnalytics> {
  Map<String, dynamic>? _a;

  static const _L = {
    'ar': {'title': 'إحصائيات صفحتك', 'views7': 'زيارات آخر 7 أيام', 'views30': 'زيارات آخر 30 يوم', 'quotes30': 'طلبات أسعار آخر 30 يوم',
      'impressions': 'مشاهدات البوستات', 'daily': 'الزيارات اليومية', 'countries': 'من أين يأتي الزوار', 'unknown': 'غير معروف',
      'top_posts': 'أفضل البوستات', 'views': 'مشاهدة', 'locked': 'الإحصائيات التفصيلية متاحة في الباقات المدفوعة', 'upgrade': 'ترقية الباقة',
      'more': 'رقّ باقتك لترى الزيارات اليومية ودول الزوار وأداء كل بوست'},
    'en': {'title': 'Your page analytics', 'views7': 'Visits, last 7 days', 'views30': 'Visits, last 30 days', 'quotes30': 'Quote requests, 30 days',
      'impressions': 'Post impressions', 'daily': 'Daily visits', 'countries': 'Where visitors come from', 'unknown': 'Unknown',
      'top_posts': 'Top posts', 'views': 'views', 'locked': 'Detailed analytics are available on paid packages', 'upgrade': 'Upgrade package',
      'more': 'Upgrade to see daily visits, visitor countries and per-post performance'},
    'tr': {'title': 'Sayfa istatistikleri', 'views7': 'Son 7 gün ziyaret', 'views30': 'Son 30 gün ziyaret', 'quotes30': 'Son 30 gün teklif',
      'impressions': 'Gönderi gösterimleri', 'daily': 'Günlük ziyaretler', 'countries': 'Ziyaretçi ülkeleri', 'unknown': 'Bilinmiyor',
      'top_posts': 'En iyi gönderiler', 'views': 'görüntüleme', 'locked': 'Ayrıntılı istatistikler ücretli paketlerde', 'upgrade': 'Paketi yükselt',
      'more': 'Günlük ziyaretleri, ülkeleri ve gönderi performansını görmek için yükseltin'},
  };

  String _t(String k) => (_L[L10n.i.lang] ?? _L['ar']!)[k] ?? k;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/analytics'));
      if (r['data'] is Map && mounted) setState(() => _a = Map<String, dynamic>.from(r['data'] as Map));
    } catch (_) {}
  }

  Widget _box(Widget child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: child,
      );

  Widget _title(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) return const SizedBox.shrink();
    final level = '${a['views_level'] ?? 'none'}';
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Text(_t('title'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
    );

    if (level == 'none') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        _box(Row(children: [
          const Icon(Icons.lock_outline, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_t('locked'), style: GoogleFonts.tajawal(fontSize: 13))),
          TextButton(onPressed: () => context.push('/prices'), child: Text(_t('upgrade'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.gold))),
        ])),
      ]);
    }

    final stats = <(IconData, String, Object?)>[
      (Icons.visibility_outlined, _t('views7'), a['views_7d']),
      (Icons.show_chart, _t('views30'), a['views_30d']),
      (Icons.request_quote_outlined, _t('quotes30'), a['quote_requests_30d']),
      if (a['post_impressions_total'] != null) (Icons.campaign_outlined, _t('impressions'), a['post_impressions_total']),
    ];
    final daily = a['daily_views'] is List ? ApiClient.list(a['daily_views']) : <Map<String, dynamic>>[];
    final maxDaily = daily.fold<int>(1, (m, d) => ((d['views'] as num?)?.toInt() ?? 0) > m ? (d['views'] as num).toInt() : m);
    final countries = a['viewer_countries'] is List ? ApiClient.list(a['viewer_countries']) : <Map<String, dynamic>>[];
    final posts = a['top_posts'] is List ? ApiClient.list(a['top_posts']) : <Map<String, dynamic>>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final s in stats)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [Icon(s.$1, size: 16, color: AppColors.gold), const SizedBox(width: 6), Expanded(child: Text(s.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.muted)))]),
                Text('${s.$3 ?? 0}', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
        ],
      ),
      if (daily.isNotEmpty)
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(_t('daily')),
          SizedBox(
            height: 110,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in daily)
                  Expanded(
                    child: Tooltip(
                      message: '${d['date']}: ${d['views']}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        height: 4 + 104 * (((d['views'] as num?)?.toDouble() ?? 0) / maxDaily),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withAlpha(((d['views'] as num?) ?? 0) > 0 ? 255 : 70),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${daily.first['date']}', style: GoogleFonts.tajawal(fontSize: 10, color: AppColors.muted)),
              Text('${daily.last['date']}', style: GoogleFonts.tajawal(fontSize: 10, color: AppColors.muted)),
            ]),
          ),
        ])),
      if (countries.isNotEmpty)
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(_t('countries')),
          for (final c in countries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${c['name'] ?? _t('unknown')}', style: GoogleFonts.tajawal(fontSize: 13))),
                Text('${c['views'] ?? 0}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
        ])),
      if (posts.isNotEmpty)
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(_t('top_posts')),
          for (final p in posts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${p['excerpt'] ?? ''}'.isEmpty ? '—' : '${p['excerpt']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12.5))),
                const SizedBox(width: 8),
                Text('${p['impressions'] ?? 0} ${_t('views')}', style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
        ])),
      if (level == 'basic')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GestureDetector(
            onTap: () => context.push('/prices'),
            child: Text('${_t('more')} — ${_t('upgrade')}', style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.muted)),
          ),
        ),
    ]);
  }
}
