import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_data.dart';
import '../theme/app_theme.dart';
import 'net_image.dart';

/// Auto-rotating banners from the API. [location] is a `/banners?location=` value
/// (homepage, timeline, products, ...). Use [sliders] for the home hero `/sliders`.
/// Renders nothing when the API returns no banner.
class BannerStrip extends StatefulWidget {
  final String? location;
  final bool sliders;
  final double aspectRatio;
  final EdgeInsets margin;

  const BannerStrip({
    super.key,
    this.location,
    this.sliders = false,
    this.aspectRatio = 16 / 6,
    this.margin = const EdgeInsets.only(bottom: 5),
  });

  @override
  State<BannerStrip> createState() => _BannerStripState();
}

class _BannerStripState extends State<BannerStrip> {
  List<Map<String, dynamic>> _items = [];
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = widget.sliders ? await AppData.fetchSliders() : await AppData.fetchBanners(widget.location!);
    if (!mounted || items.isEmpty) return;
    setState(() => _items = items);
    if (items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % _items.length;
        _controller.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _imageOf(Map<String, dynamic> b) {
    for (final k in const ['mobile_image_url', 'website_image_url', 'mobile_video_thumbnail_url', 'website_video_thumbnail_url']) {
      final v = b[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  Future<void> _open(String? link) async {
    final uri = link == null || link.isEmpty ? null : Uri.tryParse(link);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: widget.margin,
      color: Colors.white,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final b = _items[i];
                return GestureDetector(
                  onTap: () => _open(b['link_url'] as String?),
                  child: NetImage(url: _imageOf(b), fallback: '', width: double.infinity, height: double.infinity),
                );
              },
            ),
            if (_items.length > 1)
              Positioned(
                bottom: 6, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _items.length,
                    (i) => Container(
                      width: i == _page ? 14 : 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: i == _page ? AppColors.gold : Colors.white70, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One banner image (mobile version), full width, tappable through its `link_url`.
class PromoBanner extends StatelessWidget {
  final Map<String, dynamic> banner;
  const PromoBanner({super.key, required this.banner});

  @override
  Widget build(BuildContext context) {
    String url = '';
    for (final k in const ['mobile_image_url', 'website_image_url', 'mobile_video_thumbnail_url', 'website_video_thumbnail_url']) {
      final v = banner[k];
      if (v is String && v.isNotEmpty) {
        url = v;
        break;
      }
    }
    if (url.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        final link = banner['link_url'] as String?;
        final uri = link == null || link.isEmpty ? null : Uri.tryParse(link);
        if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: CachedNetworkImage(imageUrl: url, width: double.infinity, fit: BoxFit.fitWidth, fadeInDuration: const Duration(milliseconds: 150), placeholder: (_, __) => const AspectRatio(aspectRatio: 3, child: ColoredBox(color: Color(0xFFEEEEEE))), errorWidget: (_, __, ___) => const SizedBox.shrink()),
      ),
    );
  }
}
