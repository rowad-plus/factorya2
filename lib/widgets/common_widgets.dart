import 'package:flutter/material.dart';
import 'net_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('11:30', style: GoogleFonts.tajawal(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          const Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Icon(Icons.wifi, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Icon(Icons.battery_full, color: Colors.white, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double? width;

  const GoldButton({super.key, required this.label, this.onTap, this.icon, this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
            Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, this.icon, this.seeAllLabel, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 7),
        ],
        Text(title, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
        const Spacer(),
        if (seeAllLabel != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(seeAllLabel!, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ),
      ],
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) return Icon(Icons.star, color: AppColors.gold, size: size);
        if (i < rating) return Icon(Icons.star_half, color: AppColors.gold, size: size);
        return Icon(Icons.star_border, color: AppColors.gold, size: size);
      }),
    );
  }
}

class GoldBadge extends StatelessWidget {
  final String label;
  final Color? bgColor;
  final Color? textColor;
  final IconData? icon;

  const GoldBadge({super.key, required this.label, this.bgColor, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.gold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: textColor ?? Colors.white, size: 9), const SizedBox(width: 3)],
          Text(label, style: GoogleFonts.tajawal(fontSize: 9.5, fontWeight: FontWeight.w800, color: textColor ?? Colors.white)),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EE),
        border: Border.all(color: AppColors.green),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: AppColors.green, size: 9),
          const SizedBox(width: 3),
          Text('موثق', style: GoogleFonts.tajawal(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.green)),
        ],
      ),
    );
  }
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.gold, size: 9),
          const SizedBox(width: 3),
          Text('مميز', style: GoogleFonts.tajawal(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ],
      ),
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 5, color: AppColors.bg);
  }
}

class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? marginBottom;

  const WhiteCard({super.key, required this.child, this.padding, this.marginBottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: padding ?? const EdgeInsets.all(14),
      margin: EdgeInsets.only(bottom: marginBottom ?? 5),
      child: child,
    );
  }
}

class AvatarCircle extends StatelessWidget {
  final String label;
  final String color;
  final double size;
  final double fontSize;

  const AvatarCircle({
    super.key,
    required this.label,
    required this.color,
    this.size = 38,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse(color.replaceFirst('#', 'FF'), radix: 16));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.tajawal(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w800)),
    );
  }
}

class EmojiBox extends StatelessWidget {
  final String emoji;
  final String gradStart;
  final String gradEnd;
  final double size;
  final double emojiSize;
  final double borderRadius;
  final String? imageUrl;

  const EmojiBox({
    super.key,
    required this.emoji,
    required this.gradStart,
    required this.gradEnd,
    this.size = 56,
    this.emojiSize = 26,
    this.borderRadius = 12,
    this.imageUrl,
  });

  static Color _fromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_fromHex(gradStart), _fromHex(gradEnd)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.black.withAlpha(15)),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? NetImage(url: imageUrl, fallback: emoji, fallbackSize: emojiSize, width: size, height: size, fit: BoxFit.cover)
          : Text(emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }
}

void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: _ToastWidget(message: message),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () => entry.remove());
}

class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 12)],
          ),
          child: Text(widget.message, style: GoogleFonts.tajawal(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
