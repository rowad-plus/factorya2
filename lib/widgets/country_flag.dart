import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Country flag (flagcdn image — emoji flags render as tofu on some platforms) drawn as a small
/// raised card: soft shadow and a light gloss, with no coloured background behind it.
class CountryFlag extends StatelessWidget {
  final String code;
  final double width;
  const CountryFlag(this.code, {super.key, this.width = 36});

  @override
  Widget build(BuildContext context) {
    final c = code.toLowerCase();
    final height = width * 2 / 3;
    if (c.length != 2) {
      return Text(code.isEmpty ? '--' : code, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey));
    }
    final radius = BorderRadius.circular(width * 0.12);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 5, offset: const Offset(0, 2)),
          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 1, offset: const Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(
            imageUrl: 'https://flagcdn.com/w160/$c.png',
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 120),
            errorWidget: (_, __, ___) => Center(child: Text(code, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w800))),
          ),
          // gloss: light from the top-left, slight shade at the bottom-right
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withAlpha(90), Colors.white.withAlpha(0), Colors.black.withAlpha(45)],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The country's short code (SA, EG, TR…) in a small square frame, shown beside its name.
class CountryCodeBox extends StatelessWidget {
  final String code;
  const CountryCodeBox(this.code, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9CA3AF), width: 1), borderRadius: BorderRadius.circular(4)),
        child: Text(code.toUpperCase(), style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280), height: 1.2)),
      );
}
