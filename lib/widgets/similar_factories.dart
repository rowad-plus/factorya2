import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'home_swiper.dart';
import 'verification_badge.dart';

/// "Similar factories" strip under a factory profile, like the site.
/// The server decides who appears: paid factories get no competitors on their
/// page (empty list); free pages show paid competitors flagged as sponsored first.
class SimilarFactories extends StatefulWidget {
  final String factoryId;
  const SimilarFactories({super.key, required this.factoryId});

  @override
  State<SimilarFactories> createState() => _SimilarFactoriesState();
}

class _SimilarFactoriesState extends State<SimilarFactories> {
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.i.get('/factories/${widget.factoryId}/similar');
      final data = res['data'];
      final list = data is Map ? ApiClient.list(data['factories']) : <Map<String, dynamic>>[];
      if (mounted) setState(() => _items = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(t('factory_profile.similar_factories', 'مصانع مشابهة'),
              style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _card(context, _items[i]),
          ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> f) {
    final name = '${f['name'] ?? ''}';
    final country = f['country'] is Map ? '${(f['country'] as Map)['name'] ?? ''}' : '';
    final place = [if ('${f['city'] ?? ''}'.isNotEmpty) '${f['city']}', if (country.isNotEmpty) country].join('، ');
    return GestureDetector(
      onTap: () => context.push('/factory/${f['id']}'),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: f['is_sponsored'] == true
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFFDF4E0), borderRadius: BorderRadius.circular(20)),
                    child: Text(t('factory_profile.sponsored', 'إعلان'),
                        style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFB7791F))),
                  )
                : const SizedBox(height: 16),
          ),
          const SizedBox(height: 4),
          SiteAvatar(url: f['logo'] as String?, name: name, size: 64, isFactory: true),
          const SizedBox(height: 8),
          NameWithBadge(
            name: name,
            level: f['verification_badge'],
            maxLines: 2,
            textAlign: TextAlign.center,
            badgeSize: 14,
            style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.3),
          ),
          const Spacer(),
          Text(place, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }
}
