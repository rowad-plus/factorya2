import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_data.dart';
import '../screens/auth/login_modal.dart';
import '../services/auth_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';
import 'country_picker.dart';
import 'net_image.dart';

/// The website's `navLinks` (sheared/navigation.ts) mapped to app routes.
class NavLink {
  final String key;
  final String route;
  final IconData icon;
  const NavLink(this.key, this.route, this.icon);
}

const navLinks = [
  NavLink('nav.home', '/', Icons.home_outlined),
  NavLink('nav.gates', '/categories', Icons.grid_view),
  NavLink(
      'nav.opportunity_requests', '/opportunities', Icons.campaign_outlined),
  NavLink('nav.factories', '/companies', Icons.factory_outlined),
  NavLink('nav.sponsors', '/sponsors', Icons.workspace_premium_outlined),
  NavLink('nav.products_services', '/products', Icons.inventory_2_outlined),
  NavLink('nav.exhibitions', '/exhibitions', Icons.event_outlined),
  NavLink('nav.jobs', '/jobs', Icons.work_outline),
  NavLink('nav.cvs', '/cvs', Icons.description_outlined),
];

/// Dark 70px header: logo, country, language, login / user menu.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.dark,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: topInset + 6, color: AppColors.gold),
        SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: SvgPicture.asset('assets/images/logo_white.svg', width: 38, height: 38),
                ),
                const Spacer(),
                const _CountryButton(),
                _divider(),
                const _LanguageButton(),
                _divider(),
                const _UserButton(),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  static Widget _divider() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF464646));
}

class _CountryButton extends StatelessWidget {
  const _CountryButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.revision,
      builder: (context, _) => GestureDetector(
        onTap: () => CountryPicker.show(context),
        child: _Flag('${AppData.country?['code'] ?? ''}'),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    const names = {'ar': 'العربية', 'en': 'English', 'tr': 'Türkçe'};
    const flags = {'ar': '🇸🇦', 'en': '🇺🇸', 'tr': '🇹🇷'};
    return PopupMenuButton<String>(
      color: AppColors.dark,
      offset: const Offset(0, 40),
      onSelected: (l) async {
        await L10n.i.setLang(l);
        AppData.refresh();
      },
      itemBuilder: (_) => [
        for (final l in L10n.supported)
          PopupMenuItem(
            value: l,
            child: Row(children: [
              Text(flags[l]!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 10),
              Text(names[l]!,
                  style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight:
                          l == L10n.i.lang ? FontWeight.w800 : FontWeight.w500,
                      color: l == L10n.i.lang ? AppColors.gold : Colors.white)),
            ]),
          ),
      ],
      child: const Icon(Icons.translate, color: AppColors.gold, size: 22),
    );
  }
}

class _UserButton extends StatelessWidget {
  const _UserButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.i, L10n.i]),
      builder: (context, _) {
        final auth = AuthService.i;
        if (!auth.isLoggedIn) {
          Widget iconBtn(IconData icon, String tip, VoidCallback onTap) =>
              Tooltip(
                message: tip,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gold),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 20, color: AppColors.gold),
                  ),
                ),
              );
          return Row(mainAxisSize: MainAxisSize.min, children: [
            iconBtn(
                Icons.add_business_outlined,
                t('nav.add_factory', 'إضافة مصنع'),
                () => context.push('/factory/create')),
            const SizedBox(width: 8),
            iconBtn(Icons.person_outline, t('nav.login', 'تسجيل الدخول'),
                () => LoginModal.show(context)),
          ]);
        }
        final initial = auth.name.isEmpty
            ? '?'
            : String.fromCharCode(auth.name.runes.first).toUpperCase();
        PopupMenuEntry<String> item(String value, IconData icon, String label,
                {Color color = Colors.white}) =>
            PopupMenuItem<String>(
              value: value,
              height: 44,
              child: Row(children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: GoogleFonts.tajawal(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: color))),
              ]),
            );
        PopupMenuEntry<String> rule() => PopupMenuItem<String>(
            enabled: false,
            height: 1,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Divider(height: 1, color: Colors.white.withAlpha(30)));
        return PopupMenuButton<String>(
          color: AppColors.dark,
          offset: const Offset(0, 46),
          constraints: const BoxConstraints(minWidth: 210, maxWidth: 240),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withAlpha(50))),
          onSelected: (v) async {
            if (v == 'logout') {
              await AuthService.i.logout();
              if (context.mounted)
                showAppToast(context, t('nav.logout', 'تسجيل الخروج'));
              return;
            }
            context.push(v);
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${t('nav.welcome', 'مرحباً')} ',
                    style: GoogleFonts.tajawal(
                        fontSize: 12, color: Colors.white70)),
                TextSpan(
                    text: auth.name,
                    style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ])),
            ),
            rule(),
            if (auth.hasFactory) ...[
              item('/dashboard', Icons.apartment,
                  t('nav.dashboard', 'لوحة التحكم')),
              rule()
            ],
            item(
                '/chat', Icons.chat_bubble_outline, t('chat.title', 'الرسائل')),
            rule(),
            item('/profile/my-requests', Icons.campaign_outlined,
                t('nav.my_requests', 'طلباتي (الفرص)')),
            rule(),
            item('/profile/orders', Icons.shopping_bag_outlined,
                t('nav.my_orders', 'طلباتي (العروض)')),
            rule(),
            item('/jobs', Icons.work_outline, t('nav.jobs', 'الوظائف')),
            rule(),
            item('/profile', Icons.person_outline,
                t('nav.profile', 'البروفايل')),
            rule(),
            item('logout', Icons.logout, t('nav.logout', 'تسجيل الخروج'),
                color: const Color(0xFFFF6B6B)),
          ],
          child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.gold,
              child: Text(initial,
                  style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w800, color: AppColors.dark))),
        );
      },
    );
  }
}

/// Country flag from flagcdn (emoji flags render as tofu on some platforms); falls back to the code.
class _Flag extends StatelessWidget {
  final String code;
  const _Flag(this.code);

  @override
  Widget build(BuildContext context) {
    final c = code.toLowerCase();
    final fallback = Text(code.isEmpty ? '--' : code,
        style: GoogleFonts.tajawal(
            fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white));
    if (c.length != 2) return fallback;
    return Container(
      width: 30,
      height: 30,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 1.5)),
      child: Image.network('https://flagcdn.com/w80/$c.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: fallback)),
    );
  }
}

/// The website's `Paner`: `header` banners, shuffled, rotating every 6 seconds (mobile image).
class HeaderBanner extends StatefulWidget {
  final String location;
  const HeaderBanner({super.key, this.location = 'header'});

  @override
  State<HeaderBanner> createState() => _HeaderBannerState();
}

class _HeaderBannerState extends State<HeaderBanner> {
  List<Map<String, dynamic>> _items = [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HeaderBanner old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) _load();
  }

  Future<void> _load() async {
    final list = List<Map<String, dynamic>>.from(
        await AppData.fetchBanners(widget.location))
      ..shuffle(Random());
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _items = list;
      _index = 0;
    });
    if (list.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) setState(() => _index = (_index + 1) % _items.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty)
      return const AspectRatio(
          aspectRatio: 3, child: ColoredBox(color: Color(0xFF3D3A35)));
    final b = _items[_index];
    String url = '';
    for (final k in const ['mobile_image_url', 'website_image_url']) {
      final v = b[k];
      if (v is String && v.isNotEmpty) {
        url = v;
        break;
      }
    }
    if (url.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        final link = b['link_url'] as String?;
        final uri = link == null || link.isEmpty ? null : Uri.tryParse(link);
        if (uri != null && await canLaunchUrl(uri))
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      // Fixed 3:1 slot so the header never changes height while banners load or rotate.
      child: AspectRatio(
        aspectRatio: 3,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: ColoredBox(
            key: ValueKey(url),
            color: const Color(0xFF3D3A35),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Website mobile bottom bar: home, gates, products & services, more (drawer).
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const AppBottomNav(
      {super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.i, AppData.revision, AuthService.i]),
      builder: (context, _) {
        final unread = AuthService.i.isLoggedIn ? AppData.messages.fold<int>(0, (sum, m) => sum + ((m['unread'] as int?) ?? 0)) : 0;
        final items = [
          (Icons.home_outlined, t('nav.home', 'الرئيسية')),
          (Icons.grid_view, t('nav.gates', 'الأبواب')),
          (Icons.chat_bubble_outline, t('chat.title', 'الرسائل')),
          (Icons.more_horiz, t('nav.more', 'المزيد')),
        ];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 15,
                  offset: const Offset(0, -5))
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            if (currentIndex == i)
                              Container(
                                  width: 40,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(4)))),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Badge(
                                    isLabelVisible: i == 2 && unread > 0,
                                    label: Text('$unread'),
                                    backgroundColor: AppColors.red,
                                    child: Icon(items[i].$1, size: 24, color: currentIndex == i ? AppColors.gold : const Color(0xFF999999)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(items[i].$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.tajawal(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: currentIndex == i
                                              ? AppColors.gold
                                              : const Color(0xFF999999))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "More" drawer: the site's nav links plus the secondary pages.
class MoreSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        final extra = [
          const NavLink('nav.add_factory', '/factory/create',
              Icons.add_business_outlined),
          NavLink('nav.blog', '/blog', Icons.article_outlined),
          NavLink('nav.about', '/about', Icons.info_outline),
          NavLink('nav.contact', '/contact', Icons.mail_outline),
          const NavLink('prices.title', '/prices', Icons.sell_outlined),
          const NavLink('nav.terms', '/terms', Icons.gavel_outlined),
        ];
        final auth = AuthService.i;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 12),
                Text(t('nav.menu', 'القائمة'),
                    style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 8),
                for (final l in [...navLinks, ...extra])
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(l.icon, color: AppColors.gold, size: 20),
                    title: Text(_label(l),
                        style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    trailing: const Icon(Icons.chevron_left,
                        size: 16, color: AppColors.muted),
                    onTap: () {
                      Navigator.pop(sheet);
                      if (l.route == '/' ||
                          l.route == '/categories' ||
                          l.route == '/products') {
                        context.go(l.route);
                      } else {
                        context.push(l.route);
                      }
                    },
                  ),
                const Divider(),
                if (auth.isLoggedIn) ...[
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dashboard_outlined,
                          color: AppColors.gold, size: 20),
                      title: Text(t('nav.dashboard', 'لوحة التحكم'),
                          style: GoogleFonts.tajawal(fontSize: 14)),
                      onTap: () {
                        Navigator.pop(sheet);
                        context.push('/dashboard');
                      }),
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline,
                          color: AppColors.gold, size: 20),
                      title: Text(t('nav.profile', 'البروفايل'),
                          style: GoogleFonts.tajawal(fontSize: 14)),
                      onTap: () {
                        Navigator.pop(sheet);
                        context.push('/profile');
                      }),
                ] else
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.login,
                          color: AppColors.gold, size: 20),
                      title: Text(t('nav.login', 'تسجيل الدخول'),
                          style: GoogleFonts.tajawal(fontSize: 14)),
                      onTap: () {
                        Navigator.pop(sheet);
                        LoginModal.show(context);
                      }),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _label(NavLink l) {
    final fallbacks = {
      'prices.title': 'الأسعار',
      'nav.terms': 'الشروط والأحكام',
      'nav.contact': 'اتصل بنا'
    };
    return t(l.key, fallbacks[l.key]);
  }
}

/// Spinner-or-empty placeholder used by list pages.
Widget emptyState(String text, {bool loading = false}) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(color: AppColors.gold)
            : Text(text,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
      ),
    );

/// Avatar with the API image and an initial fallback.
Widget netAvatar(String? url, String name, {double size = 40}) => Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFEF8E8)),
      child: NetImage(
          url: url,
          fallback: name.isEmpty
              ? '?'
              : String.fromCharCode(name.runes.first).toUpperCase(),
          fallbackSize: size * 0.4,
          width: size,
          height: size),
    );
