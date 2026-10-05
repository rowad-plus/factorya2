import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../models/factory_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/home_swiper.dart';
import 'package:go_router/go_router.dart';
import '../opportunities/create_opportunity_screen.dart';
import '../../widgets/post_card.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../auth/login_modal.dart';
import '../gate/gate_screen.dart';
import '../factory_profile/factory_profile_screen.dart';
import '../timeline/create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoCompanies;
  final VoidCallback? onGoCategories;
  final VoidCallback? onGoProducts;
  final Function(Map<String, dynamic>)? onOpenFactory;

  const HomeScreen({
    super.key,
    this.onGoCompanies,
    this.onGoCategories,
    this.onGoProducts,
    this.onOpenFactory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 1200) AppData.loadMorePosts();
    });
    // Same banners the website shows between timeline posts.
    AppData.fetchBanners('timeline').then((b) {
      if (mounted) setState(() => _banners = b);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Feed like the website home: a promo banner after every 3rd post, the opportunities
  /// strip after the 3rd, and a featured-factories grid after the 5th.
  List<Widget> _feed() {
    final posts = AppData.posts;
    final out = <Widget>[];
    for (var i = 0; i < posts.length; i++) {
      out.add(PostCard(key: ValueKey(posts[i].id), post: posts[i]));
      if (i > 0 && (i + 1) % 3 == 0 && _banners.isNotEmpty) {
        out.add(PromoBanner(banner: _banners[(i ~/ 3) % _banners.length]));
      }
      if (i == 2 && AppData.opportunities.isNotEmpty) out.add(_buildOpportunitiesStrip());
      if (i == 4 && AppData.featured.isNotEmpty) out.add(_buildFeaturedGrid());
    }
    return out;
  }

  void _openGate(Map<String, dynamic> door) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GateScreen(door: door)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppData.revision, AuthService.i]),
      builder: (context, _) => _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    final feed = _feed();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.gold,
            onRefresh: AppData.refresh,
            child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
                SliverToBoxAdapter(child: const HeaderBanner()),
              SliverToBoxAdapter(child: _buildComposer()),
              SliverToBoxAdapter(child: _buildAgentBanner()),
              SliverToBoxAdapter(child: _buildDoorsSection()),
              SliverToBoxAdapter(child: _buildFactoriesSlider()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                  child: Text(t('home.latest_posts', 'أحدث المنشورات'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => feed[i],
                  childCount: feed.length,
                ),
              ),
              if (AppData.postsLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.gold))),
                ),
              if (AppData.posts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(!AppData.loaded ? 'جارٍ التحميل...' : (AppData.error != null ? AppData.error! : 'لا توجد منشورات بعد'),
                          textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
          ),
        ],
      ),
    );
  }

  // ── Website mobile layout (app/(main)/client-page.tsx) ──

  Widget _buildDoorsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: SiteSidePost(
        title: t('home.gates', 'الأبواب'),
        loading: !AppData.loaded,
        items: AppData.doors
            .map((d) => SwiperItem(title: (d['name'] ?? d['short'] ?? '') as String, imageUrl: d['image'] as String?, onTap: () => _openGate(d)))
            .toList(),
      ),
    );
  }

  Widget _buildFactoriesSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SiteSidePost(
        title: t('home.featured_factories', 'أهم المصانع'),
        isFactory: true,
        phonePerView: 3.5,
        loading: !AppData.loaded,
        items: AppData.featured
            .map((f) => SwiperItem(title: f.name, imageUrl: f.logoUrl, onTap: () => _openFactory(f)))
            .toList(),
      ),
    );
  }

  void _openFactory(FactoryModel f) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: f)));
  }

  /// AddPost: white card, avatar + read-only "إنشاء منشور" pill.
  Widget _buildComposer() {
    final img = AuthService.i.user?['image'] as String?;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: const Color(0xFF101828).withAlpha(10), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          SiteAvatar(url: img, name: AuthService.i.isLoggedIn ? AuthService.i.name : 'User', size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _showPostModal,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(t('home.create_post_placeholder', 'إنشاء منشور'), style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF98A2B3))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPostModal() {
    if (!AuthService.i.isLoggedIn) {
      LoginModal.show(context);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  /// AgentBanner: dark gradient card, decorative gold circles, gold start bar,
  /// outlined chips and a full-width "اطلب فرصتك" button.
  Widget _buildAgentBanner() {
    final items = [
      [Icons.apartment, t('home.agent_banner_item_agent', 'تريد أن تكون وكيلًا لمصنع')],
      [Icons.search, t('home.agent_banner_item_product', 'تبحث عن منتج معين')],
      [Icons.handshake, t('home.agent_banner_item_partner', 'تبحث عن فرص للتعاون مع مصنع')],
    ];
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOpportunityScreen()));
    return GestureDetector(
      onTap: open,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.dark, Color(0xFF3D3A35)], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            PositionedDirectional(top: -40, end: -40, child: _circle(140, 31)),
            PositionedDirectional(bottom: -55, start: 60, child: _circle(110, 18)),
            PositionedDirectional(top: 0, bottom: 0, start: 0, child: Container(width: 4, color: AppColors.gold)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('home.agent_banner_title', 'هل تبحث عن فرصة؟ دعنا نوفرها لك نيابةً عنك.'),
                      style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, height: 1.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: items.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withAlpha(41)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(e[0] as IconData, color: AppColors.gold, size: 14),
                        const SizedBox(width: 6),
                        Text(e[1] as String, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(235))),
                      ]),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: open,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(100)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.phone_in_talk_outlined, size: 16, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(t('home.agent_banner_cta', 'اطلب فرصتك'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, int alpha) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withAlpha(alpha)),
      );

  /// Opportunities card shown after the 3rd post (mobile only on the site);
  /// each one opens the factories list filtered by that opportunity.
  Widget _buildOpportunitiesStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiteBlockTitle(t('gates.opportunities', 'الفرص')),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppData.opportunities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final o = AppData.opportunities[i];
                return GestureDetector(
                  onTap: () => context.push('/companies?opportunity_id=${o.id}&title=${Uri.encodeQueryComponent(o.title)}'),
                  child: SizedBox(
                    width: 72,
                    child: Column(children: [
                      SiteAvatar(url: o.imageUrl, name: o.title, size: 60),
                      const SizedBox(height: 4),
                      Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.text, height: 1.3)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// PromoSlider after the 5th post: 2 featured factories (mobile), outlined cards.
  Widget _buildFeaturedGrid() {
    final list = AppData.featured.take(2).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      child: Row(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _openFactory(list[i]),
                child: Container(
                  height: 180,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFF555555))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SiteAvatar(url: list[i].logoUrl, name: list[i].name, size: 100, isFactory: true),
                      const SizedBox(height: 12),
                      Text(list[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black, height: 1.2)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (list.length == 1) const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
