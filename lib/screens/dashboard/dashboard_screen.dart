import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';
import 'dash_kit.dart';
import 'dash_sections.dart';

/// Native factory dashboard (`/api/v1/factory-dashboard`): home with statistics, then every
/// section of the site's Blade dashboard — locked ones (by package capability) show an upgrade notice.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _home;
  final Map<String, bool> _allowed = {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.i.isLoggedIn || !AuthService.i.hasFactory) {
      setState(() => _loading = false);
      return;
    }
    try {
      final r = await ApiClient.i.get(dp('/'));
      _home = Map<String, dynamic>.from(r['data'] as Map);
      try {
        final c = await ApiClient.i.get(dp('/capabilities'));
        final menu = (c['data'] is Map ? (c['data'] as Map)['menu'] : null);
        if (menu is List) {
          for (final m in menu) {
            if (m is Map) _allowed['${m['route']}'] = m['allowed'] == true;
          }
        }
      } catch (_) {}
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _ok(String route) => _allowed[route] ?? true;

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.i, L10n.i]),
      builder: (context, _) {
        final auth = AuthService.i;
        if (!auth.isLoggedIn) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t('post.login_required', 'سجّل الدخول أولاً'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: () => LoginModal.show(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold), child: Text(t('nav.login', 'تسجيل الدخول'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
            ]),
          );
        }
        if (!auth.hasFactory) return emptyState(td('factories.no_factory_found'));
        if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        final home = _home;
        if (home == null) return emptyState(_error ?? td('dashboard.no_results'));
        final stats = home['stats'] is Map ? Map<String, dynamic>.from(home['stats'] as Map) : <String, dynamic>{};
        final factory = home['factory'] is Map ? Map<String, dynamic>.from(home['factory'] as Map) : <String, dynamic>{};
        final recent = home['recent_quote_requests'] is List ? ApiClient.list(home['recent_quote_requests']) : <Map<String, dynamic>>[];
        final cards = [
          (Icons.inventory_2_outlined, td('dashboard.products_count'), '${stats['products'] ?? 0}', td('dashboard.active_products_count', {'count': stats['products_active'] ?? 0})),
          (Icons.groups_outlined, td('dashboard.clients_count'), '${stats['clients'] ?? 0}', ''),
          (Icons.store_mall_directory_outlined, td('dashboard.branches_count'), '${stats['branches'] ?? 0}', ''),
          (Icons.visibility_outlined, td('dashboard.visits_count'), '${stats['profile_views'] ?? 0}', ''),
          (Icons.chat_bubble_outline, td('dashboard.messages'), '${stats['unread_messages'] ?? 0}', td('dashboard.unread_messages')),
          (Icons.request_quote_outlined, td('dashboard.quote_requests'), '${stats['quote_requests'] ?? 0}', td('dashboard.new_quote_requests_this_week')),
        ];
        Widget menu(IconData icon, String label, String route, Widget Function() page, {String? badge}) {
          final ok = _ok(route);
          return ListTile(
            dense: true,
            leading: Icon(icon, color: ok ? AppColors.gold : AppColors.muted),
            title: Text(label, style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w600, color: ok ? AppColors.text : AppColors.muted)),
            trailing: ok ? Icon(L10n.i.isRtl ? Icons.chevron_left : Icons.chevron_right, size: 18, color: AppColors.muted) : const Icon(Icons.lock_outline, size: 17, color: AppColors.muted),
            onTap: () => _open(page()),
          );
        }

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
                const HeaderBanner(),
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.dark, Color(0xFF3D3A35)]), borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(td('dashboard.welcome_user', {'name': auth.name}), style: GoogleFonts.tajawal(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(td('dashboard.welcome_message'), style: GoogleFonts.tajawal(fontSize: 12.5, color: Colors.white70, height: 1.6)),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)), child: Text(td('dashboard.current_plan', {'plan': home['current_plan'] ?? ''}), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.dark))),
                  if (factory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(onTap: () => context.push('/factory/${factory['id']}'), child: Text('${td('factories.view_factory')} ›', style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.gold, fontWeight: FontWeight.w700))),
                  ],
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Text(td('dashboard.statistics'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.45,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in cards)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Row(children: [Icon(c.$1, size: 18, color: AppColors.gold), const SizedBox(width: 6), Expanded(child: Text(c.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)))]),
                        Text(c.$3, style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800)),
                        if (c.$4.isNotEmpty) Text(c.$4, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.muted)),
                      ]),
                    ),
                ],
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 4), child: Text(td('dashboard.quick_actions'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  menu(Icons.edit_outlined, td('dashboard.edit_factory'), 'my-factory', () => const MyFactorySection()),
                  const Divider(height: 1),
                  menu(Icons.groups_outlined, td('dashboard.clients'), 'factorydashboard.clients', clientsSection),
                  menu(Icons.store_mall_directory_outlined, td('dashboard.branches'), 'factorydashboard.branches', branchesSection),
                  menu(Icons.inventory_2_outlined, td('dashboard.products'), 'factorydashboard.products.index', productsSection),
                  menu(Icons.work_outline, td('dashboard.jobs'), 'jobs', jobsSection),
                  menu(Icons.assignment_ind_outlined, td('dashboard.job_applications'), 'job-applications', jobApplicationsSection),
                  menu(Icons.videocam_outlined, td('dashboard.videos'), 'factorydashboard.videos.index', videosSection),
                  menu(Icons.photo_library_outlined, td('dashboard.images'), 'factorydashboard.images.index', imagesSection),
                  menu(Icons.request_quote_outlined, td('dashboard.quote_requests'), 'quote-requests', quoteRequestsSection),
                  menu(Icons.gavel_outlined, td('dashboard.rfqs'), 'rfq-offers', () => const RfqSection()),
                  menu(Icons.person_add_alt_outlined, td('dashboard.customer_join_requests'), 'factorydashboard.customer-join-requests.index', joinRequestsSection),
                  menu(Icons.share_outlined, td('dashboard.contact_channels'), 'factorydashboard.contact-channels.index', () => const ContactChannelsSection()),
                  menu(Icons.campaign_outlined, td('dashboard.banners'), 'factorydashboard.banners.index', bannersSection),
                  menu(Icons.chat_outlined, td('dashboard.chat'), 'factorydashboard.chat.index', () => const DashChatSection()),
                  menu(Icons.palette_outlined, td('dashboard.website_theme'), 'factorydashboard.website-theme', () => const ThemeSection()),
                  menu(Icons.travel_explore, td('dashboard.seo'), 'factorydashboard.seo', () => const SeoSection()),
                  ListTile(dense: true, leading: const Icon(Icons.workspace_premium_outlined, color: AppColors.gold), title: Text(td('dashboard.subscription_requests'), style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w600)), trailing: Icon(L10n.i.isRtl ? Icons.chevron_left : Icons.chevron_right, size: 18, color: AppColors.muted), onTap: () => context.push('/subscription')),
                ]),
              ),
              if (recent.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6), child: Text(td('dashboard.recent_quote_requests'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
                for (final q in recent)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${q['name'] ?? ''}', style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
                      Text('${q['phone'] ?? ''} · ${q['email'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
                      Text('${q['details'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12.5, height: 1.5)),
                    ]),
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
