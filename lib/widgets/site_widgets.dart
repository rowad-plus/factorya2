import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../models/factory_model.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'net_image.dart';

/// Mirrors the website's `SmallHeader`: a yellow tab with an icon and a section title.
class SmallHeader extends StatelessWidget {
  final String title;
  final String? subTitle;
  final IconData icon;
  final Color? bgColor;
  final Color color;

  const SmallHeader({
    super.key,
    required this.title,
    this.subTitle,
    this.icon = Icons.factory,
    this.bgColor,
    this.color = AppColors.dark,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = L10n.i.isRtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            color: bgColor,
            constraints: const BoxConstraints(minWidth: 90),
            child: IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 38,
                    padding: EdgeInsetsDirectional.only(start: 70, end: 15, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8D983),
                      borderRadius: BorderRadiusDirectional.horizontal(end: Radius.zero, start: const Radius.circular(0)).resolve(rtl ? TextDirection.rtl : TextDirection.ltr),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 20, color: AppColors.dark),
                  ),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Text(title, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w500, color: color)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (subTitle != null && subTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(subTitle!, style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.muted, height: 1.6)),
          ),
      ],
    );
  }
}

/// Mirrors the website's `Card`: image on top, title, yellow subtitle.
class SiteCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subTitle;
  final String fallback;
  final bool brandFallback;
  final VoidCallback? onTap;

  const SiteCard({super.key, required this.imageUrl, required this.title, this.subTitle = '', this.fallback = '🏭', this.brandFallback = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Container(
              height: 131,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFFEF8E8)),
              child: NetImage(url: imageUrl, brandFallback: brandFallback, fallback: fallback, fallbackSize: 40, width: double.infinity, height: 131),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                    ),
                    if (subTitle.isNotEmpty) Text(subTitle, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of [SiteCard]s (the website's `Parts`).
class CardsGrid extends StatelessWidget {
  final List<Widget> children;
  const CardsGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.95,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: children,
    );
  }
}

/// Factory logo card used in the dark "factories" strip (the website's `CardFactory`).
class FactoryLogoCard extends StatelessWidget {
  final FactoryModel factory;
  final VoidCallback onTap;
  const FactoryLogoCard({super.key, required this.factory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 192,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Container(
              height: 131,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFFEF8E8)),
              child: NetImage(url: factory.logoUrl, brandFallback: true, fallback: factory.emoji, fallbackSize: 38, fit: BoxFit.contain, width: double.infinity, height: 131),
            ),
            Expanded(
              child: Center(child: Text(factory.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site's search box (`SearchBar`): rounded field with a search action.
class SiteSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSubmit;
  final String initial;
  const SiteSearchBar({super.key, required this.hint, required this.onSubmit, this.initial = ''});

  @override
  State<SiteSearchBar> createState() => _SiteSearchBarState();
}

class _SiteSearchBarState extends State<SiteSearchBar> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDBDBDB))),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmit,
              style: GoogleFonts.tajawal(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFFBCC1C9)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => widget.onSubmit(_ctrl.text),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.search, color: AppColors.dark, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// The site's `SwiperComponent`: `/sliders` with a dark overlay, header and description, autoplay 5s.
class SiteSlider extends StatefulWidget {
  const SiteSlider({super.key});

  @override
  State<SiteSlider> createState() => _SiteSliderState();
}

class _SiteSliderState extends State<SiteSlider> {
  List<Map<String, dynamic>> _items = [];
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    AppData.fetchSliders().then((s) {
      if (!mounted || s.isEmpty) return;
      setState(() => _items = s);
      if (s.length > 1) {
        _timer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (_controller.hasClients) _controller.animateToPage((_page + 1) % _items.length, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: PageView.builder(
        controller: _controller,
        itemCount: _items.length,
        onPageChanged: (i) => _page = i,
        itemBuilder: (_, i) {
          final s = _items[i];
          final img = ((s['mobile_image_url'] as String?)?.isNotEmpty ?? false) ? s['mobile_image_url'] as String : (s['website_image_url'] as String?);
          final header = AppData.tr(s, 'header');
          final desc = AppData.tr(s, 'description');
          return Stack(
            fit: StackFit.expand,
            children: [
              NetImage(url: img, fallback: '', width: double.infinity, height: double.infinity),
              Container(color: Colors.black.withAlpha(128)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (header.trim().length > 1) Text(header, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 25, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1, shadows: const [Shadow(blurRadius: 10, color: Colors.black54)])),
                      if (desc.trim().length > 1) ...[
                        const SizedBox(height: 10),
                        Text(desc, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Round page-number pagination (dark or light background).
class SitePagination extends StatelessWidget {
  final int current;
  final int last;
  final ValueChanged<int> onPage;
  final bool dark;
  const SitePagination({super.key, required this.current, required this.last, required this.onPage, this.dark = false});

  List<Object> _pages() {
    final out = <Object>[1];
    final left = (current - 2).clamp(2, last);
    final right = (current + 2).clamp(1, last - 1);
    if (left > 2) out.add('…');
    for (var i = left; i <= right; i++) {
      out.add(i);
    }
    if (right < last - 1) out.add('…');
    if (last > 1) out.add(last);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (last <= 1) return const SizedBox.shrink();
    final fg = dark ? Colors.white : AppColors.dark;
    final line = dark ? Colors.white.withAlpha(64) : AppColors.border;
    Widget btn(Widget child, VoidCallback? onTap, {bool active = false}) => GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.35 : 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 36),
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: active ? AppColors.gold : line, width: 1.5),
              ),
              child: DefaultTextStyle(style: GoogleFonts.tajawal(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.dark : fg), child: child),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          btn(Icon(L10n.i.isRtl ? Icons.chevron_right : Icons.chevron_left, size: 18, color: fg), current > 1 ? () => onPage(current - 1) : null),
          for (final p in _pages())
            p is int ? btn(Text('$p'), () => onPage(p), active: p == current) : Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: TextStyle(color: fg.withAlpha(115)))),
          btn(Icon(L10n.i.isRtl ? Icons.chevron_left : Icons.chevron_right, size: 18, color: fg), current < last ? () => onPage(current + 1) : null),
        ],
      ),
    );
  }
}
