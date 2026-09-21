import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/site_widgets.dart';
import '../factory_profile/factory_profile_screen.dart';
import '../gate/gate_screen.dart';

/// `/gates` on the website: sliders + search, gates grid, banner, featured factories strip,
/// a second banner and the opportunities grid.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    AppData.fetchBanners('gates').then((b) {
      if (!mounted) return;
      setState(() => _banners = List.of(b)..shuffle(Random()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppData.revision, L10n.i]),
      builder: (context, _) {
        final doors = AppData.doors;
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: AppData.refresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
                const HeaderBanner(location: 'gates'),
              const SiteSlider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SiteSearchBar(
                  hint: t('gates.search_placeholder', 'ابحث عن مصنع...'),
                  onSubmit: (q) => context.push('/companies?search=${Uri.encodeQueryComponent(q.trim())}'),
                ),
              ),
              SmallHeader(title: t('gates.gates_title', 'الأبواب'), subTitle: t('gates.gates_subtitle'), bgColor: AppColors.gold3),
              if (doors.isEmpty)
                Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(AppData.loaded ? t('gates.no_data') : '...', style: GoogleFonts.tajawal(color: AppColors.muted))))
              else
                CardsGrid(
                  children: [
                    for (var i = 0; i < doors.length; i++)
                      SiteCard(
                        imageUrl: doors[i]['image'] as String?,
                        title: doors[i]['name'] as String,
                        subTitle: '${doors[i]['count']} ${t('gates.categories_count', 'اقسام')}',
                        fallback: doors[i]['emoji'] as String,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GateScreen(door: doors[i]))),
                      ),
                  ],
                ),
              if (_banners.isNotEmpty) PromoBanner(banner: _banners[0]),
              if (AppData.featured.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  color: AppColors.dark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmallHeader(title: t('gates.featured_factories', 'أهم المصانع'), color: Colors.white),
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: AppData.featured.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (_, i) {
                            final f = AppData.featured[i];
                            return FactoryLogoCard(factory: f, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: f))));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (_banners.length > 1) PromoBanner(banner: _banners[1]),
              if (AppData.opportunities.isNotEmpty) ...[
                SmallHeader(title: t('gates.opportunities', 'الفرص'), subTitle: t('gates.opportunities_subtitle'), bgColor: AppColors.gold3),
                CardsGrid(
                  children: [
                    for (final o in AppData.opportunities)
                      SiteCard(
                        imageUrl: o.imageUrl,
                        title: o.title,
                        fallback: o.emoji,
                        onTap: () => context.push('/companies?opportunity_id=${o.id}&title=${Uri.encodeQueryComponent(o.title)}'),
                      ),
                  ],
                ),
              ],
              const SiteFooter(),
            ],
          ),
        );
      },
    );
  }
}
