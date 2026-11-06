import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../models/post_model.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'timeline_meta.dart';

String _tri(String ar, String tr, String en) => L10n.i.lang == 'ar' ? ar : (L10n.i.lang == 'tr' ? tr : en);

bool _isRtlText(String s) {
  final m = RegExp(r'[A-Za-z؀-ۿ]').firstMatch(s);
  return m == null ? L10n.i.isRtl : RegExp(r'[؀-ۿ]').hasMatch(m.group(0)!);
}

/// Same cut as the site's previewText: first 6 lines and at most 300 characters (ends on a word).
String? postPreview(String text, {int maxChars = 300, int maxLines = 6}) {
  var cut = text.split('\n').take(maxLines).join('\n');
  if (cut.length > maxChars) {
    cut = cut.substring(0, maxChars);
    final space = cut.lastIndexOf(' ');
    if (space > maxChars * 0.6) cut = cut.substring(0, space);
  }
  return cut.length < text.length ? '${cut.trimRight()}…' : null;
}

/// Tidy user text like the site's tidyPostText: trims, at most one blank line between paragraphs.
String tidyPostText(String text) => text
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((l) => l.trimRight())
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Post text with "عرض المزيد / عرض أقل" — same size, colour, line height and direction as the site.
class ExpandablePostText extends StatefulWidget {
  final String text;
  final Color color;
  final Color linkColor;
  final double fontSize;
  const ExpandablePostText({super.key, required this.text, this.color = const Color(0xFF374151), this.linkColor = const Color(0xFF7A5600), this.fontSize = 14});

  @override
  State<ExpandablePostText> createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<ExpandablePostText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final clean = tidyPostText(widget.text);
    final preview = postPreview(clean);
    final rtl = _isRtlText(clean);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          preview != null && !_expanded ? preview : clean,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.tajawal(fontSize: widget.fontSize, color: widget.color, height: 1.8),
        ),
        if (preview != null)
          Align(
            alignment: L10n.i.isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _expanded ? _tri('عرض أقل', 'Daha az göster', 'Show less') : _tri('عرض المزيد', 'Devamını göster', 'Show more'),
                  style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: widget.linkColor),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaItem {
  final String url;
  final PostModel post;
  const _MediaItem(this.url, this.post);
}

List<String> postImages(PostModel p) {
  final meta = [p.metadata?['image_url'], p.metadata?['image_path'], p.metadata?['image']]
      .whereType<String>()
      .firstWhere((u) => u.startsWith('http'), orElse: () => '');
  return [...p.imageUrls, if (meta.isNotEmpty && !p.imageUrls.contains(meta)) meta];
}

List<_MediaItem> _feedItems(PostModel tapped) {
  final out = <_MediaItem>[];
  final feed = AppData.posts.any((p) => p.id == tapped.id) ? AppData.posts : [tapped];
  for (final p in feed) {
    if (AppData.hiddenPostIds.contains(p.id) || AppData.hiddenAuthorIds.contains(p.authorId)) continue;
    for (final u in postImages(p)) {
      out.add(_MediaItem(u, p));
    }
  }
  return out;
}

/// Full-screen viewer like the site's MediaViewer: every image of the timeline, swiped up and down.
void openPostMediaViewer(BuildContext context, PostModel post, String url) {
  final items = _feedItems(post);
  var start = items.indexWhere((m) => m.post.id == post.id && m.url == url);
  if (start < 0) {
    items.insert(0, _MediaItem(url, post));
    start = 0;
  }
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: true,
    pageBuilder: (_, __, ___) => _PostMediaViewer(items: items, initial: start, tapped: post),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _PostMediaViewer extends StatefulWidget {
  final List<_MediaItem> items;
  final int initial;
  final PostModel tapped;
  const _PostMediaViewer({required this.items, required this.initial, required this.tapped});

  @override
  State<_PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends State<_PostMediaViewer> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late List<_MediaItem> _items = widget.items;
  late int _index = widget.initial;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _page.dispose();
    super.dispose();
  }

  Future<void> _maybeLoadMore(int i) async {
    if (i < _items.length - 3 || !AppData.hasMorePosts || AppData.postsLoadingMore) return;
    if (!AppData.posts.any((p) => p.id == widget.tapped.id)) return;
    await AppData.loadMorePosts();
    if (!mounted) return;
    final fresh = _feedItems(widget.tapped);
    if (fresh.length > _items.length) setState(() => _items = fresh);
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _items.length) return;
    _page.animateToPage(next, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    final p = item.post;
    final name = cleanName(p.authorName).isEmpty ? _tri('مستخدم', 'Kullanıcı', 'User') : cleanName(p.authorName);
    final text = p.isAutogenerated ? '' : p.text.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            itemCount: _items.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _zoomed = false;
              });
              _maybeLoadMore(i);
            },
            itemBuilder: (_, i) => _ZoomImage(
              url: _items[i].url,
              onZoom: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
          // top bar: close + position
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _roundBtn(Icons.close, () => Navigator.of(context).pop()),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_index + 1} / ${_items.length}', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          // up / down like the site's chevrons
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_index > 0) _roundBtn(Icons.keyboard_arrow_up_rounded, () => _go(-1)),
                const SizedBox(height: 10),
                if (_index < _items.length - 1) _roundBtn(Icons.keyboard_arrow_down_rounded, () => _go(1)),
              ]),
            ),
          ),
          // publisher + text, over a dark gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: _zoomed,
              child: AnimatedOpacity(
                opacity: _zoomed ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  padding: const EdgeInsets.fromLTRB(16, 40, 56, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold, border: Border.all(color: Colors.white24)),
                              alignment: Alignment.center,
                              child: p.authorImage.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: p.authorImage, fit: BoxFit.cover, width: 36, height: 36,
                                      errorWidget: (_, __, ___) => Text(p.authorAvatar, style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w800)))
                                  : Text(p.authorAvatar.isEmpty ? '؟' : p.authorAvatar, style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.tajawal(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          if (text.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ExpandablePostText(key: ValueKey('vt-${p.id}'), text: text, color: Colors.white, linkColor: AppColors.gold, fontSize: 13.5),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 24)),
        ),
      );
}

/// One image, whole (contain), pinch / double-tap to zoom; tells the pager when it is zoomed
/// so up/down swipes pan the picture instead of changing it.
class _ZoomImage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoom;
  const _ZoomImage({required this.url, required this.onZoom});

  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final _ctrl = TransformationController();
  TapDownDetails? _tap;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => widget.onZoom(_ctrl.value.getMaxScaleOnAxis() > 1.01));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (_ctrl.value.getMaxScaleOnAxis() > 1.01) {
      _ctrl.value = Matrix4.identity();
    } else {
      final pos = _tap?.localPosition ?? Offset.zero;
      _ctrl.value = Matrix4.identity()
        ..translate(-pos.dx * 1.5, -pos.dy * 1.5)
        ..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onDoubleTapDown: (d) => _tap = d,
        onDoubleTap: _doubleTap,
        child: InteractiveViewer(
          transformationController: _ctrl,
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
            ),
          ),
        ),
      );
}
