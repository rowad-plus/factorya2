import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'net_image.dart';

/// One slide of [SiteSidePost] (gate, featured factory or opportunity).
class SwiperItem {
  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  const SwiperItem({required this.title, this.imageUrl, this.onTap});
}

/// Section title used by the website's home blocks: a 3px gold bar + bold 13px text,
/// with a thin bottom divider.
class SiteBlockTitle extends StatelessWidget {
  final String title;
  const SiteBlockTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF2F4F7)))),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
      ]),
    );
  }
}

/// Mobile version of the website's SidePost + PostSwiper: title, then 4 round
/// images per view, autoplay every 3s, gold pagination dots underneath.
class SiteSidePost extends StatefulWidget {
  final String title;
  final List<SwiperItem> items;
  final bool isFactory;
  final bool loading;
  /// Items visible on a phone (e.g. 3.5 to show a half item hinting at scroll).
  /// Null = the site's 4 per view (5–6 on wider screens).
  final double? phonePerView;

  const SiteSidePost({super.key, required this.title, required this.items, this.isFactory = false, this.loading = false, this.phonePerView});

  @override
  State<SiteSidePost> createState() => _SiteSidePostState();
}

class _SiteSidePostState extends State<SiteSidePost> {
  final _ctrl = ScrollController();
  Timer? _timer;
  int _page = 0;
  double _perView = 4;
  double _extent = 90;

  int get _pages => ((widget.items.length - _perView).ceil() + 1).clamp(1, 1 << 30);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_ctrl.hasClients || _pages <= 1) return;
      _goTo(_page + 1 >= _pages ? 0 : _page + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (!_ctrl.hasClients) return;
    final target = (i * _extent).clamp(0.0, _ctrl.position.maxScrollExtent);
    _ctrl.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  // Snap to a whole item after a drag, like Swiper.
  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      final p = (_ctrl.offset / _extent).round().clamp(0, _pages - 1);
      if (p != _page) setState(() => _page = p);
    }
    if (n is ScrollEndNotification && n.dragDetails != null) {
      final exact = _ctrl.offset / _extent;
      if ((exact - exact.round()).abs() > 0.01) {
        Future.microtask(() => _goTo(exact.round()));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SiteBlockTitle(widget.title),
        const SizedBox(height: 16),
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(widget.loading ? '' : 'لا توجد بيانات حالياً', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.muted)),
          )
        else ...[
          LayoutBuilder(builder: (context, c) {
            // 4 per view on phones (as on the site), more on big phones/tablets.
            final phone = widget.phonePerView ?? 4;
            _perView = c.maxWidth < 520 ? phone : (c.maxWidth < 800 ? phone + 1 : phone + 2);
            _extent = c.maxWidth / _perView;
            final avatar = (_extent - 16).clamp(56.0, 90.0);
            return SizedBox(
              height: avatar + 50,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.builder(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _extent,
                  padding: EdgeInsets.zero,
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _slide(widget.items[i], avatar),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          if (_pages > 1)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: List.generate(_pages, (i) => GestureDetector(
                onTap: () => _goTo(i),
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? AppColors.gold : Colors.black.withAlpha(50)),
                ),
              )),
            ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _slide(SwiperItem it, double avatar) {
    return GestureDetector(
      onTap: it.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(children: [
        SiteAvatar(url: it.imageUrl, name: it.title, size: avatar, isFactory: widget.isFactory),
        const SizedBox(height: 8),
        Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3)),
      ]),
    );
  }
}

/// Round avatar like the website's AvatarImg: image, or the Factorya logo for
/// factories without one, or initials on grey.
class SiteAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isFactory;
  const SiteAvatar({super.key, this.url, required this.name, this.size = 40, this.isFactory = false});

  @override
  Widget build(BuildContext context) {
    final hasImg = url != null && url!.isNotEmpty;
    final initials = name.trim().isEmpty
        ? '؟'
        : (() {
            final words = name.trim().split(RegExp(r'\s+'));
            if (words.length == 1) return String.fromCharCodes(words.first.runes.take(2)).toUpperCase();
            return words.take(2).map((w) => String.fromCharCode(w.runes.first)).join().toUpperCase();
          })();
    return Container(
      width: size, height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE4E4E7)),
      alignment: Alignment.center,
      child: hasImg || isFactory
          ? NetImage(url: url, brandFallback: true, fallbackSize: size / 3, width: size, height: size, fit: isFactory ? BoxFit.contain : BoxFit.cover)
          : Text(initials, style: GoogleFonts.tajawal(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: const Color(0xFF3F3F46))),
    );
  }
}
