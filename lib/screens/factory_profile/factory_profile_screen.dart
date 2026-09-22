import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_data.dart';
import '../../models/factory_model.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/net_image.dart';
import '../../widgets/simple_html.dart';
import '../../widgets/post_card.dart';
import '../../models/post_model.dart';
import '../auth/login_modal.dart';
import '../chat/chat_screen.dart';

/// Factory profile — the website's "classic" design: header card, top tabs
/// (About / Posts for featured factories / Contact) and, for featured factories,
/// the stacked catalogs, branches, partners, products, videos and team sections.
class FactoryProfileScreen extends StatefulWidget {
  final FactoryModel factory;
  const FactoryProfileScreen({super.key, required this.factory});

  @override
  State<FactoryProfileScreen> createState() => _FactoryProfileScreenState();
}

class _FactoryProfileScreenState extends State<FactoryProfileScreen> {
  Map<String, dynamic>? _f;
  String? _error;
  int _tab = 0;
  Color _primary = const Color(0xFFC8861A);
  Color _light = const Color(0xFFFEF8E8);
  Color _title = const Color(0xFF1A1208);

  /// 1 = classic, 2..6 = the site's premium designs (all share the 9-tab layout).
  int _version = 1;
  String _cover = '';
  String _premiumTab = 'about';

  String get _id => widget.factory.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Color? _hex(dynamic v) {
    if (v is! String) return null;
    var h = v.replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length != 6) return null;
    final n = int.tryParse(h, radix: 16);
    return n == null ? null : Color(0xFF000000 | n);
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.i.get('/factories/$_id');
      if (mounted)
        setState(() => _f = Map<String, dynamic>.from(res['data'] as Map));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      return;
    }
    try {
      final res = await ApiClient.i.get('/factories/$_id/website-theme');
      final d = res['data'];
      if (d is Map && mounted) {
        setState(() {
          _primary = _hex(d['button_color']) ?? _primary;
          _light = _hex(d['background_color']) ?? _light;
          _title = _hex(d['title_color']) ?? _title;
          final th = d['theme'];
          if (th is Map) {
            final id = (th['id'] as num?)?.toInt();
            if (id != null && id >= 1 && id <= 6) _version = id;
          }
        });
      }
    } catch (_) {}
    try {
      final b = await ApiClient.i.get('/factories/$_id/banners');
      final d = b['data'];
      final rows = d is Map ? ApiClient.list(d['banners']) : ApiClient.list(d);
      for (final r in rows) {
        final u = '${r['mobile_image_url'] ?? r['website_image_url'] ?? ''}';
        if (u.isNotEmpty && r['is_active'] != false) {
          if (mounted) setState(() => _cover = u);
          break;
        }
      }
    } catch (_) {}
  }

  bool get _featured => _f?['is_featured'] == true;
  String get _name => AppData.tr(_f ?? {}, 'name').isNotEmpty
      ? AppData.tr(_f!, 'name')
      : widget.factory.name;

  static String _strip(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final f = _f;
        return Scaffold(
          backgroundColor: _light,
          body: SafeArea(
            bottom: false,
            child: f == null
                ? Stack(children: [
                    Center(
                        child: _error != null
                            ? Text(_error!,
                                style:
                                    GoogleFonts.tajawal(color: AppColors.muted))
                            : CircularProgressIndicator(color: _primary)),
                    _back(),
                  ])
                : Stack(children: [
                    _version >= 2
                        ? _premium(f)
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              if (!_featured) const HeaderBanner(),
                              _header(f),
                              _tabs(),
                              if (_tab == 0) _aboutTab(f),
                              if (_tab == 1 && _featured) _postsTab(f),
                              if (_tab == (_featured ? 2 : 1)) _contactTab(f),
                              const SiteFooter(),
                            ],
                          ),
                    _back(),
                  ]),
          ),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6)
                ]),
            child: Icon(L10n.i.isRtl ? Icons.arrow_forward : Icons.arrow_back,
                size: 18, color: AppColors.dark),
          ),
        ),
      );

  // ───────────────────────── header card ─────────────────────────

  /// Opportunity tag text: the factory payload only carries ids/images, so look the name up.
  String _oppLabel(Map<String, dynamic> o) {
    for (final k in ['title', 'name']) {
      final v = AppData.tr(o, k);
      if (v.isNotEmpty) return v;
    }
    for (final x in AppData.opportunities) {
      if (x.id == '${o['id']}') return x.title;
    }
    return '';
  }

  String _flag(String? code) => code == null || code.length != 2
      ? ''
      : code
          .toUpperCase()
          .runes
          .map((c) => String.fromCharCode(127397 + c))
          .join();

  Widget _header(Map<String, dynamic> f) {
    final country = f['country'] is Map
        ? Map<String, dynamic>.from(f['country'] as Map)
        : <String, dynamic>{};
    final desc = _strip(AppData.tr(f, 'short_description').isNotEmpty
        ? AppData.tr(f, 'short_description')
        : AppData.tr(f, 'about'));
    final opps = f['opportunities'] is List
        ? ApiClient.list(f['opportunities'])
        : <Map<String, dynamic>>[];
    final nick = '${f['nickname'] ?? f['id']}';
    final ownFactory = AuthService.i.factoryId != null &&
        '${AuthService.i.factoryId}' == '${f['id']}';
    final showChat = f['chat_enabled'] == true && !ownFactory;

    Widget btn(IconData icon, String label, VoidCallback onTap,
            {bool primary = false, bool iconOnly = false}) =>
        Expanded(
          flex: iconOnly ? 1 : 3,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: primary ? _light : Colors.white,
                  border: Border.all(
                      color: primary ? _primary : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: iconOnly
                    ? Icon(icon,
                        size: 22,
                        color: primary ? _primary : const Color(0xFF718096),
                        semanticLabel: label)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icon, size: 18, color: const Color(0xFFA0AEC0)),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.tajawal(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4A5568)))),
                      ]),
              ),
            ),
          ),
        );

    return Container(
      color: _light,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withAlpha(13)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(8),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEFE0),
                      borderRadius: BorderRadius.circular(14)),
                  child: NetImage(
                      url: AppData.logoUrl(f),
                      brandFallback: true,
                      fallback: widget.factory.emoji,
                      fallbackSize: 30,
                      fit: BoxFit.contain,
                      width: 56,
                      height: 56),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20)),
                          child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text('@$nick',
                                  style: GoogleFonts.tajawal(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD97706)))),
                        ),
                        const SizedBox(width: 6),
                        Text(_flag(country['code'] as String?),
                            style: const TextStyle(fontSize: 20)),
                      ]),
                      const SizedBox(height: 6),
                      Text(_name,
                          style: GoogleFonts.tajawal(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A202C),
                              height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                      fontSize: 13.5,
                      color: const Color(0xFF718096),
                      height: 1.6)),
            ],
            if (opps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in opps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(_oppLabel(o),
                          style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4B5563))),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              if (showChat) ...[
                btn(Icons.chat_bubble_outline, t('chat.title', 'الرسائل'), () {
                  if (!AuthService.i.isLoggedIn) {
                    LoginModal.show(context);
                    return;
                  }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              factoryId: '${f['id']}',
                              name: _name,
                              avatar: _name,
                              color: _primary)));
                }, primary: true, iconOnly: true),
                const SizedBox(width: 8),
              ],
              btn(
                  Icons.description_outlined,
                  t('factory_profile.request_quote', 'طلب عرض سعر'),
                  () => _QuoteSheet.show(context, f, _primary)),
              const SizedBox(width: 8),
              btn(
                  Icons.share_outlined,
                  t('factory_profile.share_factory', 'مشاركة'),
                  () => Share.share('$_name\nhttps://factorya.net/$nick'), iconOnly: true),
            ]),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── premium designs (themes 2–6) ─────────────────────────

  /// Per-version visual identity for the premium designs (2–6): the site gives each package
  /// tier its own hero/nav treatment (`ProfileV2`..`ProfileV6`); this mirrors that distinction
  /// rather than reusing one shared look, while all six share the same tab content below.
  bool get _darkTheme => _version == 3 || _version == 5;
  Color get _pageBg => switch (_version) {
        2 => const Color(0xFFFAF2E4),
        4 => Colors.white,
        6 => const Color(0xFFF7F4F0),
        _ => const Color(0xFF1A1208),
      };

  Widget _premium(Map<String, dynamic> f) {
    const ids = [
      'about',
      'posts',
      'catalogs',
      'branches',
      'partners',
      'products',
      'videos',
      'team',
      'contact'
    ];
    final labels = {
      'about': t('factory_tabs.about', 'نبذة'),
      'posts': t('factory_tabs.posts', 'المنشورات'),
      'catalogs': t('factory_tabs.catalogs', 'الكتالوجات'),
      'branches': t('factory_tabs.branches', 'الفروع'),
      'partners': t('factory_tabs.partners', 'الشركاء'),
      'products': t('factory_tabs.products', 'المنتجات'),
      'videos': t('factory_tabs.videos', 'الفيديوهات'),
      'team': t('factory_tabs.team', 'فريق العمل'),
      'contact': t('factory_tabs.contact', 'اتصل بنا'),
    };
    Widget body;
    switch (_premiumTab) {
      case 'posts':
        body = _postsTab(f);
      case 'catalogs':
        body = _section('factory_tabs.catalogs', 'الكتالوجات',
            _Catalogs(f: f, primary: _primary));
      case 'branches':
        body = _section(
            'factory_tabs.branches',
            'الفروع',
            _ListLoader(
                path: '/factories/$_id/branches',
                builder: _branches,
                emptyKey: 'factory_profile.no_branches'));
      case 'partners':
        body = _section(
            'factory_tabs.partners',
            'الشركاء',
            _ListLoader(
                path: '/factories/$_id/clients',
                builder: _partners,
                emptyKey: 'factory_profile.no_clients'));
      case 'products':
        body = _section(
            'factory_tabs.products',
            'المنتجات',
            _ListLoader(
                path: '/factories/$_id/products',
                builder: _products,
                emptyKey: 'factory_profile.no_products'));
      case 'videos':
        body = _section(
            'factory_tabs.videos',
            'الفيديوهات',
            _ListLoader(
                path: '/factories/$_id/videos',
                builder: _videos,
                emptyKey: 'factory_profile.no_videos'));
      case 'team':
        body = _section('factory_tabs.team', 'الفريق', _team(f));
      case 'contact':
        body = _contactTab(f);
      default:
        body = _aboutTab(f, stacked: false);
    }

    Widget tabBar() {
      if (_version == 4) {
        // V4: crisp white, underline tabs (no pill background).
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (_, i) {
              final on = _premiumTab == ids[i];
              return GestureDetector(
                onTap: () => setState(() => _premiumTab = ids[i]),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? _primary : Colors.transparent, width: 3))),
                  child: Text(labels[ids[i]]!, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? const Color(0xFF1A1208) : const Color(0xFF999999))),
                ),
              );
            },
          ),
        );
      }
      if (_version == 6) {
        // V6: dark bar (site's TopNavV6), a home icon then the tabs, always dark regardless of theme colors.
        return Container(
          height: 50,
          color: const Color(0xFF1A1208),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.go('/'),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: _primary.withAlpha(46), borderRadius: BorderRadius.circular(8), border: Border.all(color: _primary.withAlpha(90))),
                child: const Icon(Icons.home_outlined, color: Colors.white, size: 17),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ids.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, i) {
                  final on = _premiumTab == ids[i];
                  return GestureDetector(
                    onTap: () => setState(() => _premiumTab = ids[i]),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: on ? _primary.withAlpha(46) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Text(labels[ids[i]]!, style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? _primary : Colors.white70)),
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      }
      // V2/V3/V5: pill tabs (light for V2, dark-toned for V3/V5).
      return SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: ids.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final on = _premiumTab == ids[i];
            final unselectedBg = _darkTheme ? Colors.white.withAlpha(15) : Colors.white;
            final unselectedFg = _darkTheme ? Colors.white70 : const Color(0xFF4A5568);
            final unselectedBorder = _darkTheme ? Colors.white24 : AppColors.border;
            return GestureDetector(
              onTap: () => setState(() => _premiumTab = ids[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? _primary : unselectedBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: on ? _primary : unselectedBorder)),
                child: Text(labels[ids[i]]!, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : unselectedFg)),
              ),
            );
          },
        ),
      );
    }

    Widget hero() {
      final content = _premiumHero(f, _darkTheme || _version == 4);
      switch (_version) {
        case 2:
          // Warm cream gradient page, plain white rounded card.
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primary.withAlpha(46)),
              boxShadow: [BoxShadow(color: _primary.withAlpha(20), blurRadius: 24, offset: const Offset(0, 6))],
            ),
            child: content,
          );
        case 3:
          // Dark glass card: translucent fill + blur, over the brown gradient page.
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _primary.withAlpha(80))),
                  child: content,
                ),
              ),
            ),
          );
        case 4:
          // White page, thin gold accent line above the hero, no card chrome.
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 3, 14, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(height: 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [_primary.withAlpha(0), _primary, _primary.withAlpha(0)]))),
              const SizedBox(height: 18),
              content,
            ]),
          );
        case 5:
          // Deep, near-black gradient page; hero content sits directly on it (no card), just an accent line.
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 3, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [_primary.withAlpha(0), _primary, _primary.withAlpha(0)]))),
              const SizedBox(height: 18),
              content,
            ]),
          );
        default: // 6
          // White "profile strip": the logo overlaps the cover's bottom edge like the site's ProfileStripV6.
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
            child: content,
          );
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: _version == 3
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3D2008), Color(0xFF7A4018), Color(0xFF5A3010), Color(0xFF2A1408)])
            : _version == 5
                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A0D04), Color(0xFF3D2008), Color(0xFF7A4018), Color(0xFF1A0D04)])
                : null,
        color: _version == 3 || _version == 5 ? null : _pageBg,
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (!_featured) const HeaderBanner(),
          if (_version == 6) tabBar(),
          if (_cover.isNotEmpty)
            SizedBox(height: 180, width: double.infinity, child: NetImage(url: _cover, fallback: '', width: double.infinity, height: 180)),
          Transform.translate(offset: Offset(0, _version != 6 && _cover.isNotEmpty ? -30 : 0), child: hero()),
          if (_version != 6) tabBar(),
          Container(color: _version == 6 ? const Color(0xFFF7F4F0) : null, child: body),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _premiumHero(Map<String, dynamic> f, bool dark) {
    final country = f['country'] is Map
        ? Map<String, dynamic>.from(f['country'] as Map)
        : <String, dynamic>{};
    final desc = _strip(AppData.tr(f, 'short_description').isNotEmpty
        ? AppData.tr(f, 'short_description')
        : AppData.tr(f, 'about'));
    final nick = '${f['nickname'] ?? f['id']}';
    final fg = dark ? Colors.white : const Color(0xFF1A202C);
    final ownFactory = AuthService.i.factoryId != null &&
        '${AuthService.i.factoryId}' == '${f['id']}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: _version == 4 ? null : (_darkTheme ? Colors.black.withAlpha(110) : Colors.white),
              gradient: _version == 4 ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1208), Color(0xFF3D2810)]) : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _primary.withAlpha(90), width: 2)),
          child: NetImage(
              url: AppData.logoUrl(f),
              brandFallback: true,
              fallbackSize: 30,
              fit: BoxFit.contain,
              width: 60,
              height: 60),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('@$nick',
                      style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _primary))),
              const SizedBox(width: 6),
              Text(_flag(country['code'] as String?),
                  style: const TextStyle(fontSize: 18)),
            ]),
            const SizedBox(height: 4),
            Text(_name,
                style: GoogleFonts.tajawal(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.3)),
          ]),
        ),
      ]),
      if (desc.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(desc,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.tajawal(
                fontSize: 13.5,
                color: dark ? Colors.white70 : const Color(0xFF718096),
                height: 1.6)),
      ],
      const SizedBox(height: 14),
      Row(children: [
        if (f['chat_enabled'] == true && !ownFactory)
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ElevatedButton(
                onPressed: () {
                  if (!AuthService.i.isLoggedIn) {
                    LoginModal.show(context);
                    return;
                  }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              factoryId: '${f['id']}',
                              name: _name,
                              avatar: _name,
                              color: _primary)));
                },
                child: const Icon(Icons.chat_bubble_outline,
                    size: 22, color: Colors.white),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _QuoteSheet.show(context, f, _primary),
            icon: Icon(Icons.description_outlined,
                size: 16,
                color: dark ? Colors.white : const Color(0xFF4A5568)),
            label: Text(t('factory_profile.request_quote', 'طلب عرض سعر'),
                style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : const Color(0xFF4A5568))),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(
                    color: dark ? Colors.white38 : const Color(0xFFE2E8F0))),
          ),
        ),
        IconButton(
            onPressed: () => Share.share('$_name\nhttps://factorya.net/$nick'),
            icon: Icon(Icons.share_outlined,
                color: dark ? Colors.white70 : const Color(0xFFA0AEC0))),
      ]),
    ]);
  }

  // ───────────────────────── tabs ─────────────────────────

  Widget _tabs() {
    final labels = [
      t('factory_tabs.about', 'نبذة'),
      if (_featured) t('factory_tabs.posts', 'المنشورات'),
      t('factory_tabs.contact', 'اتصل بنا'),
    ];
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: _tab == i ? _primary : Colors.transparent,
                              width: 3))),
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight:
                              _tab == i ? FontWeight.w700 : FontWeight.w500,
                          color: _tab == i ? _primary : AppColors.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── about ─────────────────────────

  Widget _card({required Widget child, EdgeInsets? margin}) => Container(
        width: double.infinity,
        margin: margin ?? const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withAlpha(10))),
        child: child,
      );

  Widget _aboutTab(Map<String, dynamic> f, {bool stacked = true}) {
    final aboutHtml = AppData.tr(f, 'about');
    final short = _strip(AppData.tr(f, 'short_description'));
    final founded = f['founded_year'];
    final employees = f['employees_count'];
    final n = _name;
    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FactoryCover(factoryId: _id, fallback: f['image'] as String?),
              const SizedBox(height: 12),
              Text(L10n.i.lang == 'ar' ? 'نبذة عن $n' : 'About $n',
                  style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _title)),
              const SizedBox(height: 8),
              aboutHtml.isNotEmpty
                  ? SimpleHtml(data: aboutHtml, style: GoogleFonts.tajawal(fontSize: 14, color: const Color(0xFF4A5568), height: 1.8), linkColor: _primary)
                  : Text(short, style: GoogleFonts.tajawal(fontSize: 14, color: const Color(0xFF4A5568), height: 1.8)),
              if (founded != null || employees != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (founded != null)
                      '${t('factory_profile.founded_in', 'تأسست عام')} $founded.',
                    if (employees != null)
                      '${t('factory_profile.employees_more_than', 'يعمل بها أكثر من')} $employees ${t('factory_profile.employees', 'موظف')}',
                  ].join(' '),
                  style: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: const Color(0xFF4A5568),
                      height: 1.8),
                ),
              ],
            ],
          ),
        ),
        if (_featured && stacked) ...[
          _section('factory_tabs.catalogs', 'الكتالوجات',
              _Catalogs(f: f, primary: _primary)),
          _section(
              'factory_tabs.branches',
              'الفروع',
              _ListLoader(
                  path: '/factories/$_id/branches',
                  builder: (rows) => _branches(rows),
                  emptyKey: 'factory_profile.no_branches')),
          _section(
              'factory_tabs.partners',
              'الشركاء',
              _ListLoader(
                  path: '/factories/$_id/clients',
                  builder: (rows) => _partners(rows),
                  emptyKey: 'factory_profile.no_partners')),
          _section(
              'factory_tabs.products',
              'المنتجات',
              _ListLoader(
                  path: '/factories/$_id/products',
                  builder: (rows) => _products(rows),
                  emptyKey: 'factory_profile.no_products')),
          _section(
              'factory_tabs.videos',
              'الفيديوهات',
              _ListLoader(
                  path: '/factories/$_id/videos',
                  builder: (rows) => _videos(rows),
                  emptyKey: 'factory_profile.no_videos')),
          _section('factory_tabs.team', 'الفريق', _team(f)),
        ],
      ],
    );
  }

  Widget _section(String key, String fallback, Widget child) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                      color: _primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(t(key, fallback),
                  style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _title)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _detail(IconData icon, String label, String value) =>
      value.trim().isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 16, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$label: ',
                      style: GoogleFonts.tajawal(
                          fontSize: 12.5, color: AppColors.muted)),
                  TextSpan(
                      text: value,
                      style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text))
                ]))),
              ]),
            );

  Widget _branches(List<Map<String, dynamic>> rows) => Column(
        children: [
          for (final b in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detail(
                        Icons.location_on_outlined,
                        t('factory_profile.location', 'الموقع'),
                        AppData.tr(b, 'address').isNotEmpty
                            ? AppData.tr(b, 'address')
                            : AppData.tr(b, 'city')),
                    _detail(
                        Icons.email_outlined,
                        t('factory_profile.email', 'البريد'),
                        '${b['email'] ?? ''}'),
                    _detail(
                        Icons.access_time,
                        t('factory_profile.working_hours', 'ساعات العمل'),
                        '${b['working_hours'] ?? ''}'),
                    _detail(
                        Icons.phone_outlined,
                        t('factory_profile.contact_number', 'رقم التواصل'),
                        '${b['phone'] ?? ''}'),
                    if ('${b['map_url'] ?? ''}'.isNotEmpty)
                      TextButton.icon(
                          onPressed: () => _open('${b['map_url']}'),
                          icon: Icon(Icons.map_outlined,
                              size: 16, color: _primary),
                          label: Text(t('post.view_map', 'عرض الخريطة'),
                              style: GoogleFonts.tajawal(
                                  color: _primary,
                                  fontWeight: FontWeight.w700))),
                  ]),
            ),
        ],
      );

  Widget _partners(List<Map<String, dynamic>> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OutlinedButton.icon(
              onPressed: () => _JoinClientSheet.show(context, _id, _primary),
              icon: Icon(Icons.person_add_alt_1_outlined, size: 16, color: _primary),
              label: Text(t('factory_profile.join_as_client', 'انضم كعميل'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: _primary)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: _primary)),
            ),
          ),
          GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
        children: [
          for (final c in rows)
            Column(children: [
              Expanded(
                  child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(10)),
                      child: NetImage(
                          url: (c['image_url'] as String?) ?? '',
                          fallback: '🤝',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity))),
              const SizedBox(height: 4),
              Text(AppData.tr(c, 'name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                      fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
        ],
          ),
        ],
      );

  Widget _products(List<Map<String, dynamic>> rows) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
        children: [
          for (final r in rows)
            () {
              final p = AppData.productFromJson(r);
              return GestureDetector(
                onTap: () => context.push('/product/${p.id}'),
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Expanded(
                        child: NetImage(
                            url: p.imageUrl,
                            fallback: p.emoji,
                            fallbackSize: 30,
                            width: double.infinity,
                            height: double.infinity)),
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                                fontSize: 12.5, fontWeight: FontWeight.w600))),
                  ]),
                ),
              );
            }(),
        ],
      );

  Widget _videos(List<Map<String, dynamic>> rows) => Column(
        children: [
          for (final v in rows)
            GestureDetector(
              onTap: () => _open('${v['video_url'] ?? ''}'),
              child: Container(
                height: 190,
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(12)),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(
                      url: (v['thumbnail_url'] as String?) ?? '',
                      fallback: '',
                      width: double.infinity,
                      height: 190),
                  Container(color: Colors.black.withAlpha(60)),
                  const Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 54, color: Colors.white)),
                ]),
              ),
            ),
        ],
      );

  Widget _team(Map<String, dynamic> f) {
    final members = f['team_members'] is List
        ? ApiClient.list(f['team_members'])
        : <Map<String, dynamic>>[];
    if (members.isEmpty)
      return Text(t('factory_profile.no_team', 'لا يوجد أعضاء فريق'),
          style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted));
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.9,
      children: [
        for (final m in members)
          Column(children: [
            Container(
                width: 74,
                height: 74,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFFEF8E8)),
                child: NetImage(
                    url: m['image_url'] as String?,
                    fallback: AppData.tr(m, 'name').isEmpty
                        ? '👤'
                        : String.fromCharCode(
                            AppData.tr(m, 'name').runes.first),
                    width: 74,
                    height: 74)),
            const SizedBox(height: 6),
            Text(AppData.tr(m, 'name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            Text(AppData.tr(m, 'role'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                    fontSize: 11.5, color: AppColors.muted)),
          ]),
      ],
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ───────────────────────── posts ─────────────────────────

  Widget _postsTab(Map<String, dynamic> f) => _ListLoader(
        path: '/users/${f['user_id']}/posts',
        query: const {'per_page': 20},
        emptyKey: 'home.no_posts',
        builder: (rows) => Column(children: [
          for (final r in rows) PostCard(post: AppData.postFromJson(r))
        ]),
      );

  // ───────────────────────── contact ─────────────────────────

  Widget _contactTab(Map<String, dynamic> f) {
    final loggedIn = AuthService.i.isLoggedIn;
    final phones = f['phones'] is List && (f['phones'] as List).isNotEmpty
        ? (f['phones'] as List).map((e) => '$e').toList()
        : [if ('${f['phone'] ?? ''}'.isNotEmpty) '${f['phone']}'];
    final country = f['country'] is Map
        ? AppData.tr(Map<String, dynamic>.from(f['country'] as Map), 'name')
        : '';
    final city = f['city'] is Map
        ? AppData.tr(Map<String, dynamic>.from(f['city'] as Map), 'name')
        : '';
    final address = AppData.tr(f, 'full_address');
    final location = [address, city, country]
        .where((e) => e.isNotEmpty)
        .join(L10n.i.isRtl ? '، ' : ', ');
    final na = t('factory_profile.not_specified', 'غير محدد');

    Widget item(IconData icon, String label, String value,
            {String? action, VoidCallback? onTap}) =>
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withAlpha(10))),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: _light, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: _primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: GoogleFonts.tajawal(
                          fontSize: 12, color: AppColors.muted)),
                  Text(value,
                      style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                ])),
            if (action != null)
              TextButton(
                  onPressed: onTap,
                  child: Text(action,
                      style: GoogleFonts.tajawal(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _primary))),
          ]),
        );

    void gate(VoidCallback ok) {
      if (loggedIn) {
        ok();
      } else {
        showAppToast(context, t('post.login_required', 'سجّل الدخول أولاً'));
        LoginModal.show(context);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        if ('${f['email'] ?? ''}'.isNotEmpty)
          item(
              Icons.email_outlined,
              t('factory_profile.email', 'البريد الإلكتروني'),
              loggedIn ? '${f['email']}' : '••••••••',
              action: loggedIn
                  ? t('factory_profile.send_email', 'إرسال بريد')
                  : t('factory_profile.login_to_email', 'سجّل الدخول'),
              onTap: () => gate(() => _open('mailto:${f['email']}'))),
        for (final p in phones)
          item(
              Icons.phone_outlined,
              t('factory_profile.contact_number', 'رقم التواصل'),
              loggedIn ? p : '${p.substring(0, min(4, p.length))} ****',
              action: loggedIn
                  ? t('factory_profile.call_now', 'اتصل الآن')
                  : t('factory_profile.login_to_call', 'سجّل الدخول'),
              onTap: () => gate(() => _open('tel:$p'))),
        if (f['founded_year'] != null)
          item(
              Icons.calendar_today_outlined,
              t('factory_profile.founded_year', 'سنة التأسيس'),
              '${f['founded_year']}'),
        item(
            Icons.access_time,
            t('factory_profile.working_hours', 'ساعات العمل'),
            '${f['working_hours'] ?? na}'),
        item(
            Icons.location_on_outlined,
            t('factory_profile.location', 'الموقع'),
            location.isEmpty ? na : location),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _QuoteSheet.show(context, f, _primary),
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text(t('factory_profile.request_quote', 'طلب عرض سعر'),
                style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

/// Random gallery image (like the website's About section), falling back to the factory image.
class _FactoryCover extends StatefulWidget {
  final String factoryId;
  final String? fallback;
  const _FactoryCover({required this.factoryId, this.fallback});

  @override
  State<_FactoryCover> createState() => _FactoryCoverState();
}

class _FactoryCoverState extends State<_FactoryCover> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.fallback;
    AppData.fetchFactoryImages(widget.factoryId).then((imgs) {
      final urls = imgs
          .map((e) => '${e['file_url'] ?? ''}')
          .where((u) => u.isNotEmpty)
          .toList();
      if (mounted && urls.isNotEmpty)
        setState(() => _url = urls[Random().nextInt(urls.length)]);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null || _url!.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            height: 200,
            width: double.infinity,
            child: NetImage(
                url: _url, fallback: '', width: double.infinity, height: 200)));
  }
}

/// Loads a list endpoint once and renders it (or the site's empty-state string).
class _ListLoader extends StatefulWidget {
  final String path;
  final Map<String, dynamic>? query;
  final Widget Function(List<Map<String, dynamic>>) builder;
  final String emptyKey;
  const _ListLoader(
      {required this.path,
      required this.builder,
      required this.emptyKey,
      this.query});

  @override
  State<_ListLoader> createState() => _ListLoaderState();
}

class _ListLoaderState extends State<_ListLoader> {
  late final Future<List<Map<String, dynamic>>> _future = ApiClient.i
      .get(widget.path, query: widget.query ?? {'per_page': 50})
      .then((r) => ApiClient.list(r['data']));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))));
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: Text(t(widget.emptyKey, '—'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                          fontSize: 13, color: AppColors.muted))));
        }
        return widget.builder(rows);
      },
    );
  }
}

class _Catalogs extends StatelessWidget {
  final Map<String, dynamic> f;
  final Color primary;
  const _Catalogs({required this.f, required this.primary});

  @override
  Widget build(BuildContext context) {
    final list = f['catalogs'] is List
        ? ApiClient.list(f['catalogs'])
        : <Map<String, dynamic>>[];
    if (list.isEmpty)
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
              child: Text(t('factory_profile.no_catalogs', 'لا توجد كتالوجات'),
                  style: GoogleFonts.tajawal(
                      fontSize: 13, color: AppColors.muted))));
    return Column(
      children: [
        for (final c in list)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Icon(Icons.picture_as_pdf_outlined, color: primary, size: 30),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(AppData.tr(c, 'name'),
                        style: GoogleFonts.tajawal(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(t('factory_profile.catalog_description', ''),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                            fontSize: 11.5, color: AppColors.muted)),
                  ])),
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(
                      '${ApiClient.host}/api/factories/${f['id']}/catalogs/${c['id']}/file');
                  if (await canLaunchUrl(uri))
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Text(t('factory_profile.download_catalog', 'تحميل'),
                    style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w700, color: primary)),
              ),
            ]),
          ),
      ],
    );
  }
}

/// "Request a quote" form → `POST /factories/{id}/quote-requests`.
class _QuoteSheet extends StatefulWidget {
  final Map<String, dynamic> f;
  final Color primary;
  const _QuoteSheet({required this.f, required this.primary});

  static void show(
      BuildContext context, Map<String, dynamic> f, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuoteSheet(f: f, primary: primary),
    );
  }

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _name = TextEditingController(text: AuthService.i.name);
  final _email = TextEditingController(text: AuthService.i.email);
  final _phone = TextEditingController(text: AuthService.i.phone);
  final _details = TextEditingController();
  final Set<int> _products = {};
  List<Map<String, dynamic>> _all = [];
  bool _sending = false;

  bool get _featured => widget.f['is_featured'] == true;

  @override
  void initState() {
    super.initState();
    if (_featured) {
      ApiClient.i.get('/factories/${widget.f['id']}/products',
          query: {'per_page': 100}).then((r) {
        if (mounted) setState(() => _all = ApiClient.list(r['data']));
      }).catchError((_) {});
    }
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _details.text.trim().isEmpty) {
      showAppToast(
          context, '⚠️ ${t('quote.fill_required', 'يرجى ملء جميع الحقول')}');
      return;
    }
    if (_featured && _products.isEmpty && _all.isNotEmpty) {
      showAppToast(context,
          '⚠️ ${t('quote.select_product', 'اختر منتجاً واحداً على الأقل')}');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.i
          .post('/factories/${widget.f['id']}/quote-requests', body: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'details': _details.text.trim(),
        if (_featured) 'product_ids': _products.toList(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(context, '✅ ${t('quote.sent', 'تم إرسال طلبك بنجاح')}');
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
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: widget.primary)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('factory_profile.request_quote', 'طلب عرض سعر'),
                  style: GoogleFonts.tajawal(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                  controller: _name,
                  decoration: _dec(t('quote.name', 'الاسم'))),
              const SizedBox(height: 10),
              TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: _dec(t('quote.email', 'البريد الإلكتروني'))),
              const SizedBox(height: 10),
              TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: _dec(t('quote.phone', 'رقم الهاتف'))),
              if (_all.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(t('factory_tabs.products', 'المنتجات'),
                    style: GoogleFonts.tajawal(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final p in _all)
                      FilterChip(
                        label: Text(AppData.tr(p, 'name'),
                            style: GoogleFonts.tajawal(fontSize: 12)),
                        selected: _products.contains(p['id']),
                        selectedColor: widget.primary.withAlpha(60),
                        onSelected: (v) => setState(() => v
                            ? _products.add(p['id'] as int)
                            : _products.remove(p['id'])),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                  controller: _details,
                  maxLines: 4,
                  decoration: _dec(t('quote.details', 'تفاصيل الطلب'))),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(t('quote.send', 'إرسال'),
                        style: GoogleFonts.tajawal(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Join as client" (`customer-join-requests`): same fields as the quote sheet, pre-filled from
/// the signed-in user's own profile — name, email and phone all remain editable.
class _JoinClientSheet extends StatefulWidget {
  final String factoryId;
  final Color primary;
  const _JoinClientSheet({required this.factoryId, required this.primary});

  static void show(BuildContext context, String factoryId, Color primary) {
    if (!AuthService.i.isLoggedIn) {
      LoginModal.show(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _JoinClientSheet(factoryId: factoryId, primary: primary),
    );
  }

  @override
  State<_JoinClientSheet> createState() => _JoinClientSheetState();
}

class _JoinClientSheetState extends State<_JoinClientSheet> {
  final _name = TextEditingController(text: AuthService.i.name);
  final _email = TextEditingController(text: AuthService.i.email);
  late final _phone = TextEditingController(text: _localPhone());
  final _message = TextEditingController();
  bool _sending = false;

  /// The user's saved phone is `+<dial><number>`; the form shows just the local number,
  /// next to the (editable) country dial code, matching how the site splits the two.
  String _localPhone() {
    final full = AuthService.i.phone;
    final dial = '${AppData.country?['phone_code'] ?? ''}';
    return full.startsWith(dial) ? full.substring(dial.length) : full.replaceFirst('+', '');
  }

  String get _dial => '${AppData.country?['phone_code'] ?? '+966'}';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _phone.text.trim().isEmpty || _message.text.trim().isEmpty) {
      showAppToast(context, '⚠️ ${t('quote.fill_required', 'يرجى ملء جميع الحقول')}');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.i.post('/factories/${widget.factoryId}/customer-join-requests', body: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone_country_code': _dial,
        'phone': _phone.text.trim(),
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(context, '✅ ${t('factory_profile.join_request_sent', 'تم إرسال طلبك بنجاح')}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted),
        prefixText: prefix,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('factory_profile.join_as_client', 'انضم كعميل'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                t('factory_profile.join_as_client_hint', 'بياناتك معبّأة من حسابك، ويمكنك تعديلها قبل الإرسال.'),
                style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              TextField(controller: _name, style: GoogleFonts.tajawal(fontSize: 13), decoration: _dec(t('quote.name', 'الاسم'))),
              const SizedBox(height: 10),
              TextField(controller: _email, textDirection: TextDirection.ltr, style: GoogleFonts.tajawal(fontSize: 13), decoration: _dec(t('quote.email', 'البريد الإلكتروني'))),
              const SizedBox(height: 10),
              TextField(controller: _phone, textDirection: TextDirection.ltr, keyboardType: TextInputType.phone, style: GoogleFonts.tajawal(fontSize: 13), decoration: _dec(t('quote.phone', 'رقم الهاتف'), prefix: '$_dial ')),
              const SizedBox(height: 10),
              TextField(controller: _message, maxLines: 4, style: GoogleFonts.tajawal(fontSize: 13), decoration: _dec(t('factory_profile.join_message_hint', 'أخبرنا عن نشاطك ولماذا تريد الانضمام كعميل...'))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(backgroundColor: widget.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(t('quote.send', 'إرسال الطلب'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
