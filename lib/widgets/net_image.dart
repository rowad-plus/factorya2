import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Network image from the API with an emoji/text fallback when there is no image or it fails to load.
class NetImage extends StatelessWidget {
  final String? url;
  final String fallback;
  final double fallbackSize;
  final BoxFit fit;
  final double? width;
  final double? height;
  /// Show the branded logo (grey box) when there is no image — used for factories.
  final bool brandFallback;

  const NetImage({
    super.key,
    required this.url,
    this.fallback = '🏭',
    this.fallbackSize = 26,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.brandFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = brandFallback
        ? Container(color: const Color(0xFFE8EAED), alignment: Alignment.center, child: SvgPicture.asset('assets/images/logo.svg', width: fallbackSize * 1.8, height: fallbackSize * 1.8))
        : Center(child: Text(fallback, style: TextStyle(fontSize: fallbackSize)));
    final u = url;
    if (u == null || u.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: u,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// Remembers each network image's aspect ratio (width / height) for the whole session,
/// so widgets that size themselves by their image (header banner, slider) get the
/// right height immediately when rebuilt — no height jump / scroll jitter.
class ImageAspects {
  ImageAspects._();
  static final Map<String, double> _known = {};
  static final Map<String, Future<double?>> _pending = {};

  static double? of(String url) => _known[url];

  static Future<double?> resolve(String url) {
    if (url.isEmpty) return Future.value(null);
    final known = _known[url];
    if (known != null) return Future.value(known);
    return _pending[url] ??= () {
      final done = Completer<double?>();
      final stream = CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        stream.removeListener(listener);
        final w = info.image.width, h = info.image.height;
        if (w > 0 && h > 0) _known[url] = w / h;
        if (!done.isCompleted) done.complete(_known[url]);
      }, onError: (_, __) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.complete(null);
      });
      stream.addListener(listener);
      return done.future.whenComplete(() => _pending.remove(url));
    }();
  }
}
