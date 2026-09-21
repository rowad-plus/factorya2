import 'package:flutter/material.dart';
import 'net_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/factory_model.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class FactoryCardSm extends StatelessWidget {
  final FactoryModel factory;
  final VoidCallback? onTap;

  const FactoryCardSm({super.key, required this.factory, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            EmojiBox(
              emoji: factory.emoji,
              gradStart: factory.gradientStart,
              gradEnd: factory.gradientEnd,
              size: 94,
              emojiSize: 36,
              imageUrl: factory.logoUrl,
            ),
            const SizedBox(height: 6),
            Text(factory.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class FactoryCardGrid extends StatelessWidget {
  final FactoryModel factory;
  final VoidCallback? onTap;

  const FactoryCardGrid({super.key, required this.factory, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 5, offset: const Offset(0, 1))],
        ),
        child: Column(
          children: [
            Container(
              height: 96,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              clipBehavior: Clip.antiAlias,
              child: NetImage(url: factory.logoUrl, brandFallback: true, fallback: factory.emoji, fallbackSize: 28, width: double.infinity, height: 96),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(factory.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Text(factory.category, style: GoogleFonts.tajawal(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.gold)),
                  StarRating(rating: factory.rating, size: 9.5),
                  if (factory.isPremium) ...[
                    const SizedBox(height: 3),
                    const PremiumBadge(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FactoryCardList extends StatelessWidget {
  final FactoryModel factory;
  final VoidCallback? onTap;

  const FactoryCardList({super.key, required this.factory, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              child: NetImage(url: factory.logoUrl, brandFallback: true, fallback: factory.emoji, fallbackSize: 28, width: 80, height: 80),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 11, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(factory.name, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
                    Text(factory.category, style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.gold)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.gold, size: 10),
                        const SizedBox(width: 3),
                        Text(factory.city, style: GoogleFonts.tajawal(fontSize: 10, color: AppColors.muted)),
                        const SizedBox(width: 8),
                        const Icon(Icons.star, color: AppColors.gold, size: 10),
                        const SizedBox(width: 2),
                        Text(factory.rating.toString(), style: GoogleFonts.tajawal(fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (factory.isPremium) const PremiumBadge(),
                        if (factory.isPremium) const SizedBox(width: 5),
                        if (factory.isVerified) const VerifiedBadge(),
                      ],
                    ),
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

class DoorCard extends StatelessWidget {
  final Map<String, dynamic> door;
  final VoidCallback? onTap;

  const DoorCard({super.key, required this.door, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.dark3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          child: Column(
            children: [
              Container(
                height: 90,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: NetImage(url: door['image'] as String?, fallback: door['emoji'] as String, fallbackSize: 34, width: double.infinity, height: 90),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(door['name'] as String, maxLines: 2,
                      style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${door['count']} مصنع', style: GoogleFonts.tajawal(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.gold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoorChip extends StatelessWidget {
  final Map<String, dynamic> door;
  final VoidCallback? onTap;

  const DoorChip({super.key, required this.door, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withAlpha(15)),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: NetImage(url: door['image'] as String?, fallback: door['emoji'] as String, width: 56, height: 56),
            ),
            const SizedBox(height: 5),
            Text(door['short'] as String, textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
