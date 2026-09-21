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
