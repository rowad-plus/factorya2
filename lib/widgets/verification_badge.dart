import 'package:flutter/material.dart';
import '../services/l10n.dart';

/// Package verification badge next to a factory name (same as the site):
/// standard = local premium (blue), premium = global premium (purple), gold = sponsors.
class VerificationBadge extends StatelessWidget {
  final Object? level;
  final double size;
  const VerificationBadge({super.key, required this.level, this.size = 18});

  static const _levels = {
    'standard': (Color(0xFF3B82F6), 'badge.verified', 'موثّق'),
    'premium': (Color(0xFF8B5CF6), 'badge.verified_premium', 'موثّق مميز'),
    'gold': (Color(0xFFD4A017), 'badge.verified_gold', 'موثّق ذهبي'),
  };

  static bool shows(Object? level) => _levels.containsKey('${level ?? ''}');

  @override
  Widget build(BuildContext context) {
    final def = _levels['${level ?? ''}'];
    if (def == null) return const SizedBox.shrink();
    return Tooltip(
      message: t(def.$2, def.$3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Icon(Icons.verified, size: size, color: def.$1),
      ),
    );
  }
}

/// A name followed by its badge, wrapping like text.
class NameWithBadge extends StatelessWidget {
  final String name;
  final Object? level;
  final TextStyle style;
  final int? maxLines;
  final TextAlign? textAlign;
  final double badgeSize;
  const NameWithBadge({
    super.key,
    required this.name,
    required this.level,
    required this.style,
    this.maxLines,
    this.textAlign,
    this.badgeSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: name),
        if (VerificationBadge.shows(level))
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: VerificationBadge(level: level, size: badgeSize),
          ),
      ]),
      style: style,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: textAlign,
    );
  }
}
