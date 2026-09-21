import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/app_data.dart';
import '../../models/factory_model.dart';
import '../../models/post_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/banner_strip.dart';
import '../../widgets/net_image.dart';
import '../opportunities/create_opportunity_screen.dart';
import '../opportunities/opportunities_screen.dart';
import '../opportunities/opportunity_detail_screen.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/country_picker.dart';
import '../../widgets/factory_card.dart';
import '../../widgets/post_card.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../auth/login_modal.dart';
import '../gate/gate_screen.dart';
import '../factory_profile/factory_profile_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
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
    // Same banners the website shows between timeline posts.
    AppData.fetchBanners('timeline').then((b) {
      if (mounted) setState(() => _banners = b);
    });
  }

  /// Feed like the website home: a promo banner after every 3rd post, the opportunities
  /// strip after the 3rd, and a featured-factories grid after the 5th.
  List<Widget> _feed() {
    final posts = AppData.posts;
    final out = <Widget>[
      if (posts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(t('home.latest_posts', 'أحدث المنشورات'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
        ),
    ];
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
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => feed[i],
                  childCount: feed.length,
                ),
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
              const SliverToBoxAdapter(child: SiteFooter()),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorsSection() {
    if (AppData.doors.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
      margin: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: SectionHeader(
              title: 'الأبواب',
              icon: Icons.door_front_door_outlined,
              seeAllLabel: 'عرض الكل',
              onSeeAll: widget.onGoCategories,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppData.doors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => DoorChip(
                door: AppData.doors[i],
                onTap: () => _openGate(AppData.doors[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactoriesSlider() {
    if (AppData.featured.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
      margin: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: SectionHeader(
              title: 'أهم المصانع',
              icon: Icons.factory_outlined,
              seeAllLabel: 'عرض الكل',
              onSeeAll: widget.onGoCompanies,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppData.featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => FactoryCardSm(
                factory: AppData.featured[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: AppData.featured[i]))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      margin: const EdgeInsets.only(bottom: 5),
      child: Column(
        children: [
          Row(
            children: [
              AvatarCircle(label: AuthService.i.name.isEmpty ? '؟' : String.fromCharCode(AuthService.i.name.runes.first).toUpperCase(), color: '#D4A017', size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPostModal(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('اكتب منشورك هنا...', style: GoogleFonts.tajawal(fontSize: 12.5, color: const Color(0xFFAAAAAA))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.only(top: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _composerType(Icons.image_outlined, 'صورة'),
                _composerType(Icons.videocam_outlined, 'فيديو'),
                _composerType(Icons.star_outline, 'تقييم'),
                _composerType(Icons.local_offer_outlined, 'منتج'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composerType(IconData icon, String label) {
    return GestureDetector(
      onTap: _showPostModal,
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 14),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ],
      ),
    );
  }

  void _showPostModal() {
    if (!AuthService.i.isLoggedIn) {
      showAppToast(context, 'سجّل الدخول لإضافة منشور');
      LoginModal.show(context);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  void _showPostModalOld() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PostModal(),
    );
  }

  /// "هل تبحث عن فرصة؟" call-to-action (same as the website's AgentBanner).
  Widget _buildAgentBanner() {
    final items = [
      [Icons.business, 'تريد أن تكون وكيلًا لمصنع'],
      [Icons.search, 'تبحث عن منتج معين'],
      [Icons.handshake_outlined, 'تبحث عن فرص للتعاون مع مصنع'],
    ];
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOpportunityScreen())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.dark, Color(0xFF3D3A35)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(16),
          border: const Border(right: BorderSide(color: AppColors.gold, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تبحث عن فرصة؟ دعنا نوفرها لك نيابةً عنك.', style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: items.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e[0] as IconData, color: AppColors.gold2, size: 13),
                  const SizedBox(width: 5),
                  Text(e[1] as String, style: GoogleFonts.tajawal(fontSize: 10.5, color: Colors.white70)),
                ]),
              )).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
              child: Text('اطلب فرصتك', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunitiesStrip() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: SectionHeader(title: 'الفرص', icon: Icons.bolt_outlined, seeAllLabel: 'عرض الكل', onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpportunitiesScreen()))),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppData.opportunities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final o = AppData.opportunities[i];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OpportunityDetailScreen(opp: o))),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          width: 60, height: 60,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF8E7)),
                          child: NetImage(url: o.imageUrl, fallback: o.emoji, fallbackSize: 24, width: 60, height: 60),
                        ),
                        const SizedBox(height: 4),
                        Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 10, color: AppColors.text)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedGrid() {
    final list = AppData.featured.take(4).toList();
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: list.map((f) => GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FactoryProfileScreen(factory: f))),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Expanded(child: NetImage(url: f.logoUrl, brandFallback: true, fallback: f.emoji, fallbackSize: 34, width: double.infinity, height: double.infinity, fit: BoxFit.contain)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7),
                  color: Colors.white,
                  child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _PostModal extends StatefulWidget {
  const _PostModal();

  @override
  State<_PostModal> createState() => _PostModalState();
}

class _PostModalState extends State<_PostModal> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close, size: 15),
                  ),
                ),
                const Spacer(),
                Text('إضافة منشور', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    showAppToast(context, '✅ تم نشر منشورك بنجاح!');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                    child: Text('نشر', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'شارك رأيك أو تجربتك...',
                  hintStyle: GoogleFonts.tajawal(color: const Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _modalType(Icons.image_outlined, 'صورة'),
                _modalType(Icons.videocam_outlined, 'فيديو'),
                _modalType(Icons.star_outline, 'تقييم'),
                _modalType(Icons.local_offer_outlined, 'منتج'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modalType(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.gold, size: 22),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.tajawal(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
