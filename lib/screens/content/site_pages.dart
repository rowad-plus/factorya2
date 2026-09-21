import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../../widgets/site_widgets.dart';
import '../auth/login_modal.dart';

/// Light hero card used by the content pages (breadcrumb, title, subtitle).
class _Hero extends StatelessWidget {
  final String breadcrumb;
  final String title;
  final String? highlight;
  final String? subtitle;
  final List<Widget> extra;
  const _Hero({required this.breadcrumb, required this.title, this.highlight, this.subtitle, this.extra = const []});

  @override
  Widget build(BuildContext context) {
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
        Text.rich(TextSpan(children: [
          TextSpan(text: title),
          if (highlight != null) TextSpan(text: highlight, style: const TextStyle(color: AppColors.gold)),
        ]), style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.4)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.7)),
        ],
        ...extra,
      ]),
    );
  }
}

Widget _statChip(IconData icon, String title, String sub) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(sub, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.muted)),
        ]),
      ),
    );

// ═══════════════════════════════ About ═══════════════════════════════

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  List<Map<String, dynamic>> _faqs = [];
  int _open = -1;

  @override
  void initState() {
    super.initState();
    ApiClient.i.get('/faqs').then((r) {
      final d = r['data'];
      if (mounted && d is Map) setState(() => _faqs = ApiClient.list(d['faqs']));
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final about = AppData.landing['about_us'] is Map ? Map<String, dynamic>.from(AppData.landing['about_us'] as Map) : <String, dynamic>{};
        final stats = AppData.stats;
        final faqs = _faqs.isNotEmpty
            ? _faqs.map((f) => (AppData.tr(f, 'question'), AppData.tr(f, 'answer'))).toList()
            : [for (var i = 1; i <= 5; i++) (t('about_page.faq_q$i'), t('about_page.faq_a$i'))];
        final cards = [
          (Icons.flag_outlined, t('about_page.card_goal_title'), t('about_page.card_goal_desc')),
          (Icons.mail_outline, t('about_page.card_message_title'), t('about_page.card_message_desc')),
          (Icons.visibility_outlined, t('about_page.card_vision_title'), t('about_page.card_vision_desc')),
        ];
        final feats = [
          (Icons.trending_up, t('about_page.feat_exposure_title'), t('about_page.feat_exposure_desc')),
          (Icons.support_agent, t('about_page.feat_comm_title'), t('about_page.feat_comm_desc')),
          (Icons.badge_outlined, t('about_page.feat_profile_title'), t('about_page.feat_profile_desc')),
          (Icons.star_outline, t('about_page.feat_vis_title'), t('about_page.feat_vis_desc')),
        ];
        final numbers = [
          ('${stats['total_factories_count'] ?? '—'}', t('about_page.stats_registered_factories')),
          ('${stats['total_gates_count'] ?? '—'}', t('about_page.stats_industrial_sectors')),
          ('${stats['subscribed_factories_count'] ?? '—'}', t('about_page.stats_featured_companies')),
          ('${stats['views_count'] ?? '—'}', t('about_page.stats_website_visits')),
        ];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
                const HeaderBanner(),
            _Hero(
              breadcrumb: t('about_hero.breadcrumb', 'من نحن'),
              title: t('about_hero.title_more'),
              highlight: t('footer.brand_name', 'فاكتوريا'),
              subtitle: t('about_hero.subtitle'),
              extra: [
                const SizedBox(height: 12),
                Row(children: [
                  _statChip(Icons.visibility_outlined, t('about_hero.stat_vision_title'), t('about_hero.stat_vision_subtitle')),
                  const SizedBox(width: 8),
                  _statChip(Icons.handshake_outlined, t('about_hero.stat_partnership_title'), t('about_hero.stat_partnership_subtitle')),
                  const SizedBox(width: 8),
                  _statChip(Icons.support_agent, t('about_hero.stat_support_title'), t('about_hero.stat_support_subtitle')),
                ]),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/prices'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: Text(t('about_hero.packages', 'باقات الاشتراك'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
                ),
              ],
            ),
            const SiteSlider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('about_page.about_info_title', '${about['title'] ?? 'من نحن'}'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(t('about_page.about_info_description', '${about['description'] ?? ''}'), style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.muted, height: 1.8)),
              ]),
            ),
            for (final c in cards)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(c.$1, color: AppColors.gold)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.$2, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(c.$3, style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF4A5568), height: 1.7)),
                  ])),
                ]),
              ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(16),
              color: AppColors.dark,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                children: [
                  for (final n in numbers)
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(n.$1, style: GoogleFonts.tajawal(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.gold)),
                      Text(n.$2, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white70)),
                    ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('about_page.features_title'), style: GoogleFonts.tajawal(fontSize: 19, fontWeight: FontWeight.w800, height: 1.5)),
                const SizedBox(height: 6),
                Text(t('about_page.features_subtitle'), style: GoogleFonts.tajawal(fontSize: 13.5, color: AppColors.muted, height: 1.7)),
              ]),
            ),
            for (final f in feats)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(f.$1, color: AppColors.gold, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.$2, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(f.$3, style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF4A5568), height: 1.7)),
                  ])),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('about_page.faq_section_title'), style: GoogleFonts.tajawal(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(t('about_page.faq_section_subtitle'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
            for (var i = 0; i < faqs.length; i++)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: ValueKey('faq$i${_open == i}'),
                    initiallyExpanded: _open == i,
                    onExpansionChanged: (o) => _open = o ? i : -1,
                    title: Text(faqs[i].$1, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
                    iconColor: AppColors.gold,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(faqs[i].$2, style: GoogleFonts.tajawal(fontSize: 13.5, color: AppColors.muted, height: 1.8))],
                  ),
                ),
              ),
            const SiteFooter(),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════ Contact ═══════════════════════════════

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _name = TextEditingController(text: AuthService.i.name);
  final _email = TextEditingController();
  final _phone = TextEditingController(text: AuthService.i.phone);
  final _message = TextEditingController();
  String? _subject;
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subjects = [t('contact_page.subject_general'), t('contact_page.subject_support'), t('contact_page.subject_partnership')];
    final subject = _subject ?? subjects.first;
    if (_name.text.trim().isEmpty) return showAppToast(context, '⚠️ ${t('contact_page.error_fullName_required')}');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) return showAppToast(context, '⚠️ ${t('contact_page.error_email_invalid')}');
    if (_phone.text.trim().length < 7) return showAppToast(context, '⚠️ ${t('contact_page.error_phone_invalid')}');
    if (_message.text.trim().isEmpty) return showAppToast(context, '⚠️ ${t('contact_page.error_message_required')}');
    setState(() => _sending = true);
    try {
      await ApiClient.i.post('/contact', body: {
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone_number': _phone.text.trim(),
        'subject': subject,
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      _message.clear();
      showAppToast(context, '✅ ${t('contact_page.toast_success_title')}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(s, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final subjects = [t('contact_page.subject_general'), t('contact_page.subject_support'), t('contact_page.subject_partnership')];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
                const HeaderBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${t('contact_page.title_part1')} '),
                TextSpan(text: t('contact_page.title_part2'), style: const TextStyle(color: AppColors.gold)),
              ]), style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, height: 1.5)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(t('contact_page.full_name_label')),
                TextField(controller: _name, decoration: _dec(t('contact_page.full_name_placeholder'))),
                _label(t('contact_page.email_label')),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _dec(t('contact_page.email_placeholder'))),
                _label(t('contact_page.phone_label')),
                TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: _dec('+966...')),
                _label(t('contact_page.subject_label')),
                DropdownButtonFormField<String>(
                  initialValue: _subject ?? subjects.first,
                  decoration: _dec(t('contact_page.subject_placeholder')),
                  items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.tajawal(fontSize: 13)))],
                  onChanged: (v) => setState(() => _subject = v),
                ),
                _label(t('contact_page.message_label')),
                TextField(controller: _message, maxLines: 6, decoration: _dec(t('contact_page.message_placeholder'))),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(t('contact_page.submit_button'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)),
                  ),
                ),
              ]),
            ),
            const SiteFooter(),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════ Terms ═══════════════════════════════

/// The clause list the website shows when the API returns none.
const _siteClauses = <(String, String)>[
  ('تعريف المنصة وطبيعة الخدمة', 'منصة دليل المصانع العربية هي منصة رقمية متخصصة تهدف إلى ربط المصانع والشركات الصناعية في مصر والدول العربية بالموردين والمشترين والمعارض التجارية الدولية.\n\nتقدم المنصة مجموعة من الخدمات تشمل:\n• دليل شامل للمصانع والشركات الصناعية مصنفة حسب القطاع والدولة\n• عرض المعارض الصناعية وفعاليات التجارة في المنطقة العربية\n• تسهيل التواصل بين المصنّعين والموردين والمشترين\n• محتوى تحريري ومدونة متخصصة في الشأن الصناعي\n• خدمات التسجيل والمشاركة في المعارض عبر روابط موثّقة\n\nملاحظة: المنصة تعمل كوسيط معلوماتي فقط. لا تتحمل المنصة مسؤولية العقود أو الصفقات التي تُبرم بين الأطراف بشكل مباشر.'),
  ('شروط التسجيل', 'محتوى شروط التسجيل...'),
  ('حقوق الشركات والتزاماتها', 'محتوى حقوق الشركات والتزاماتها...'),
  ('المعارض والفعاليات', 'محتوى المعارض والفعاليات...'),
  ('الخصوصية وحماية البيانات', 'محتوى الخصوصية وحماية البيانات...'),
  ('الملكية الفكرية', 'محتوى الملكية الفكرية...'),
  ('الإلغاء والاسترداد', 'محتوى الإلغاء والاسترداد...'),
  ('حدود المسؤولية', 'محتوى حدود المسؤولية...'),
  ('الاستخدام المحظور', 'محتوى الاستخدام المحظور...'),
  ('القانون وتسوية النزاعات', 'محتوى القانون وتسوية النزاعات...'),
  ('التعديلات على الشروط', 'محتوى التعديلات على الشروط...'),
];

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  List<(String, String)> _clauses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiClient.i.get('/terms').then((r) {
      final d = r['data'];
      final rows = d is Map ? ApiClient.list(d['terms_clauses']) : <Map<String, dynamic>>[];
      rows.sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
      if (mounted) {
        setState(() {
          _clauses = rows.isNotEmpty ? rows.map((c) => (AppData.tr(c, 'title'), AppData.tr(c, 'content'))).toList() : _siteClauses;
          _loading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final meta = [
          (t('terms.last_update'), t('terms.last_update_date')),
          (t('terms.scope'), t('terms.scope_value')),
          (t('terms.version'), t('terms.version_value')),
          (t('terms.read_time'), t('terms.read_time_value')),
        ];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
                const HeaderBanner(),
            _Hero(breadcrumb: t('terms.title', 'الشروط والأحكام'), title: t('terms.title'), subtitle: t('terms.description')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in meta)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Text.rich(TextSpan(children: [TextSpan(text: '${m.$1}: ', style: const TextStyle(color: AppColors.muted)), TextSpan(text: m.$2, style: const TextStyle(fontWeight: FontWeight.w700))]), style: GoogleFonts.tajawal(fontSize: 12)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
            else if (_clauses.isEmpty)
              emptyState(t('terms.no_clauses', 'لا توجد شروط متاحة حالياً.'))
            else
              for (var i = 0; i < _clauses.length; i++)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: i == 0,
                      title: Text('${i + 1}. ${_clauses[i].$1}', style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      iconColor: AppColors.gold,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(_clauses[i].$2.replaceAll(RegExp(r'<[^>]*>'), ' ').trim(), style: GoogleFonts.tajawal(fontSize: 13.5, color: const Color(0xFF4A4A4A), height: 1.9))],
                    ),
                  ),
                ),
            const SiteFooter(),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════ Prices ═══════════════════════════════

class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.i, AppData.revision]),
      builder: (context, _) {
        final plans = AppData.packages;
        List<String> list(Map<String, dynamic> p, String key) {
          final v = p['${key}_${L10n.i.lang}'] ?? p['${key}_ar'];
          return v is List ? v.map((e) => '$e').toList() : <String>[];
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
                const HeaderBanner(),
            _Hero(breadcrumb: t('prices.title', 'خطط الأسعار'), title: t('prices.title'), subtitle: t('prices.subtitle')),
            if (plans.isEmpty)
              emptyState(AppData.loaded ? t('prices.no_plans', 'لا توجد خطط متاحة حالياً') : '...')
            else
              for (final p in plans)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: p['tier'] == 'sponsors_banners' ? AppColors.gold : AppColors.border, width: p['tier'] == 'sponsors_banners' ? 2 : 1)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(AppData.tr(p, 'name'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800))),
                      if (p['is_admin_only'] == true) _tag(t('prices.admin_only', 'للإدارة فقط')) else _tag(p['geo_scope'] == 'global' ? t('prices.global', 'عالمي') : t('prices.local', 'محلي')),
                    ]),
                    const SizedBox(height: 6),
                    Text(AppData.tr(p, 'description'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.6)),
                    const SizedBox(height: 10),
                    Text(p['is_free'] == true ? t('prices.free', 'مجاني') : '${(p['prices'] is List && (p['prices'] as List).isNotEmpty) ? ((p['prices'] as List).first as Map)['price'] ?? '' : ''} ${t('prices.yearly', 'سنوياً')}', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    const SizedBox(height: 8),
                    Text(t('prices.features_title', 'يشمل'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w800)),
                    for (final f in list(p, 'features'))
                      Padding(padding: const EdgeInsets.only(top: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle, size: 16, color: AppColors.green), const SizedBox(width: 6), Expanded(child: Text(f, style: GoogleFonts.tajawal(fontSize: 13, height: 1.5)))])),
                    if (list(p, 'limitations').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(t('prices.limitations_title', 'لا يشمل'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w800)),
                      for (final f in list(p, 'limitations'))
                        Padding(padding: const EdgeInsets.only(top: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.cancel, size: 16, color: AppColors.red), const SizedBox(width: 6), Expanded(child: Text(f, style: GoogleFonts.tajawal(fontSize: 13, height: 1.5)))])),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: p['is_admin_only'] == true
                            ? () => context.push('/contact')
                            : () {
                                if (!AuthService.i.isLoggedIn) {
                                  showAppToast(context, t('prices.login_first', 'يرجى تسجيل الدخول أولاً'));
                                  LoginModal.show(context);
                                } else if (!AuthService.i.hasFactory) {
                                  showAppToast(context, t('prices.factory_account_required', 'يجب أن تمتلك حساب مصنع للاشتراك في الباقات'));
                                } else {
                                  context.push('/subscription');
                                }
                              },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(p['is_admin_only'] == true ? t('prices.btn_contact_admin', 'تواصل مع الإدارة') : (p['is_free'] == true ? t('prices.btn_start_free', 'ابدأ مجاناً') : t('prices.btn_subscribe', 'اشترك الآن')), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
                      ),
                    ),
                  ]),
                ),
            const SiteFooter(),
          ],
        );
      },
    );
  }

  Widget _tag(String s) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(20)), child: Text(s, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.gold)));
}
