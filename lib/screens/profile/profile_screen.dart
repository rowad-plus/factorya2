import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/net_image.dart';
import '../../widgets/post_card.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';
import '../opportunities/opportunities_screen.dart' show tri;

Widget _needLogin(BuildContext context) => Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 44, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(t('post.login_required', 'سجّل الدخول أولاً'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => LoginModal.show(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold), child: Text(t('nav.login', 'تسجيل الدخول'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
        ]),
      ),
    );

/// `/profile`: cover, avatar, name, type, location, brief summary, shortcuts and the user's posts.
class ProfileScreen extends StatefulWidget {
  /// Another user's public profile (`/profile/{id}`); null = the signed-in user.
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _u;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    AuthService.i.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AuthService.i.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!AuthService.i.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await ApiClient.i.get(widget.userId == null ? '/profile' : '/profile/${widget.userId}');
      final u = Map<String, dynamic>.from(res['data'] as Map);
      final posts = await ApiClient.i.get('/users/${u['id']}/posts', query: {'per_page': 20});
      if (mounted) {
        setState(() {
          _u = u;
          _posts = ApiClient.list(posts['data']);
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _edit() {
    if (widget.userId != null) return;
    final u = _u!;
    final name = TextEditingController(text: '${u['name'] ?? ''}');
    final desc = TextEditingController(text: '${u['description'] ?? ''}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t('edit_profile.title', 'تعديل الملف الشخصي'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: InputDecoration(labelText: t('edit_profile.name_label', 'الاسم'))),
              const SizedBox(height: 10),
              TextField(controller: desc, maxLines: 4, decoration: InputDecoration(labelText: t('edit_profile.description_label', 'النبذة المختصرة'))),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ApiClient.i.post('/profile', body: {'display_name': name.text.trim(), 'description': desc.text.trim()});
                    if (sheet.mounted) Navigator.pop(sheet);
                    if (mounted) showAppToast(context, '✅ ${t('edit_profile.toast_success_title', 'تم تحديث الملف الشخصي')}');
                    _load();
                  } on ApiException catch (e) {
                    if (mounted) showAppToast(context, '⚠️ ${e.message}');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(t('edit_profile.save_btn', 'حفظ'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.i, AuthService.i]),
      builder: (context, _) {
        if (!AuthService.i.isLoggedIn) return _needLogin(context);
        if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        final u = _u;
        if (u == null) return emptyState(_failed ? t('profile_page.failed_load_profile', 'فشل تحميل الملف الشخصي') : '');
        final name = '${u['name'] ?? ''}';
        final country = u['country'] is Map ? AppData.tr(Map<String, dynamic>.from(u['country'] as Map), 'name') : '';
        final city = u['city'] is Map ? AppData.tr(Map<String, dynamic>.from(u['city'] as Map), 'name') : '';
        final isFactory = u['account_type'] == 'factory';
        final desc = '${u['description'] ?? ''}';
        Widget link(IconData icon, String label, String route) => ListTile(
              leading: Icon(icon, color: AppColors.gold),
              title: Text(label, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700)),
              trailing: Icon(L10n.i.isRtl ? Icons.chevron_left : Icons.chevron_right, size: 18, color: AppColors.muted),
              onTap: () => context.push(route),
            );
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
                const HeaderBanner(),
              Stack(clipBehavior: Clip.none, children: [
                Container(height: 140, width: double.infinity, color: AppColors.dark, child: u['banner_image'] != null ? NetImage(url: '${ApiClient.host}/api/users/${u['id']}/banner', fallback: '', width: double.infinity, height: 140) : null),
                PositionedDirectional(bottom: -40, start: 16, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: (u['account_type'] == 'factory' || u['has_factory'] == true) && AppData.userImageUrl(u).isEmpty
                    ? Container(width: 84, height: 84, clipBehavior: Clip.antiAlias, decoration: const BoxDecoration(shape: BoxShape.circle), child: NetImage(url: u['factory_id'] != null ? '${ApiClient.host}/api/factories/${u['factory_id']}/logo' : '', brandFallback: true, fallbackSize: 22, width: 84, height: 84))
                    : netAvatar(AppData.userImageUrl(u), name, size: 84))),
              ]),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name.isEmpty ? t('profile_page.default_user', 'مستخدم') : name, style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800))),
                    if (widget.userId == null) IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined, color: AppColors.gold)),
                  ]),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(20)), child: Text(isFactory ? t('profile_page.company', 'شركة') : t('profile_page.individual', 'فرد'), style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold))),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.muted),
                    Text([city, country].where((e) => e.isNotEmpty).join('، ').isEmpty ? t('profile_page.default_country', 'البلد غير محدد') : [city, country].where((e) => e.isNotEmpty).join('، '), style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                  const SizedBox(height: 14),
                  Text(t('profile_page.brief_summary', 'نبذة مختصرة'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(desc.isEmpty ? t('profile_page.no_description', 'لا يوجد نبذة مختصرة حالياً') : desc, style: GoogleFonts.tajawal(fontSize: 13.5, color: AppColors.muted, height: 1.7)),
                ]),
              ),
              if (widget.userId == null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.white,
                child: Column(children: [
                  link(Icons.receipt_long_outlined, t('nav.orders', 'طلباتي'), '/profile/orders'),
                  const Divider(height: 1),
                  link(Icons.assignment_outlined, t('nav.my_requests', 'طلباتي (الفرص)'), '/profile/my-requests'),
                  const Divider(height: 1),
                  link(Icons.history, t('nav.activity_log', 'سجل النشاط'), '/profile/activity-log'),
                  if (isFactory) ...[const Divider(height: 1), link(Icons.dashboard_outlined, t('nav.dashboard', 'لوحة التحكم'), '/dashboard')],
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text(t('profile_page.posts', 'المنشورات'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
              if (_posts.isEmpty) emptyState(t('profile_page.no_posts', 'لا توجد منشورات حالياً')) else for (final p in _posts) PostCard(key: ValueKey(p['id']), post: AppData.postFromJson(p)),
              const SiteFooter(),
            ],
          ),
        );
      },
    );
  }
}

/// `/profile/my-requests`.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (AuthService.i.isLoggedIn) {
      ApiClient.i.get('/opportunity-requests/mine', query: {'per_page': 50}).then((r) {
        if (mounted) setState(() => _items = ApiClient.list(r['data']));
      }).catchError((_) {}).whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.i.isLoggedIn) return _needLogin(context);
    final labels = {
      'new': tri('جديد', 'Yeni', 'New'),
      'contacted': tri('تم التواصل', 'İletişime geçildi', 'Contacted'),
      'closed': tri('مغلق', 'Kapatıldı', 'Closed'),
    };
    return ListView(padding: EdgeInsets.zero, children: [
                const HeaderBanner(),
      Padding(padding: const EdgeInsets.all(16), child: Text(t('nav.my_requests', 'طلباتي (الفرص)'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800))),
      if (_loading)
        emptyState('', loading: true)
      else if (_items.isEmpty)
        emptyState(tri('لا توجد طلبات بعد', 'Henüz talep yok', 'No requests yet'))
      else
        for (final r in _items)
          GestureDetector(
            onTap: () => context.push('/opportunity-requests/${r['id']}'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${r['full_name'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(20)), child: Text(labels['${r['status']}'] ?? '${r['status']}', style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.gold))),
                ]),
                const SizedBox(height: 6),
                Text('${r['message'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF4A5568), height: 1.6)),
                if ('${r['attachment_url'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.attach_file, size: 14, color: AppColors.gold), Text(tri('يحتوي على مرفق', 'Ek içerir', 'Has attachment'), style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))])),
              ]),
            ),
          ),
      const SiteFooter(),
    ]);
  }
}

/// `/profile/activity-log`.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (AuthService.i.isLoggedIn) {
      ApiClient.i.get('/profile/activity-log', query: {'per_page': 50}).then((r) {
        if (mounted) setState(() => _items = ApiClient.list(r['data']));
      }).catchError((_) {}).whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.i.isLoggedIn) return _needLogin(context);
    return ListView(padding: EdgeInsets.zero, children: [
                const HeaderBanner(),
      Padding(padding: const EdgeInsets.all(16), child: Text(t('nav.activity_log', 'سجل النشاط'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800))),
      if (_loading)
        emptyState('', loading: true)
      else if (_items.isEmpty)
        emptyState(tri('لا يوجد نشاط بعد', 'Henüz etkinlik yok', 'No activity yet'))
      else
        for (final a in _items)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
            child: Row(children: [
              const Icon(Icons.history, size: 20, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['description'] ?? a['action'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(AppData.dateTime(a['created_at'] as String?), style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.muted)),
              ])),
            ]),
          ),
      const SiteFooter(),
    ]);
  }
}


/// `/profile/orders`: the signed-in user's requests (`GET /profile/requests`).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _last = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _page >= _last || !AuthService.i.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final r = await ApiClient.i.get('/profile/requests', query: {'page': _page + 1, 'per_page': 15});
      final meta = r['meta'];
      if (mounted) {
        setState(() {
          _items.addAll(ApiClient.list(r['data']));
          _page++;
          if (meta is Map) _last = (meta['last_page'] as num?)?.toInt() ?? 1;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String, Color) _status(String raw) {
    final s = raw.toLowerCase();
    if (RegExp('complete|done|accept|approved').hasMatch(s)) return (tri('مكتمل', 'Tamamlandı', 'Completed'), AppColors.green);
    if (RegExp('process|work|ship|deliver').hasMatch(s)) return (tri('قيد التنفيذ', 'İşleniyor', 'Processing'), AppColors.blue);
    if (RegExp('cancel|reject|refuse|deny').hasMatch(s)) return (tri('ملغي', 'İptal', 'Cancelled'), AppColors.red);
    return (tri('قيد الانتظار', 'Beklemede', 'Pending'), AppColors.gold);
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.i.isLoggedIn) return _needLogin(context);
    final ar = L10n.i.lang == 'ar';
    return ListView(controller: _scroll, padding: EdgeInsets.zero, children: [
      const HeaderBanner(),
      Padding(padding: const EdgeInsets.all(16), child: Text(t('nav.orders', 'طلباتي'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800))),
      if (_items.isEmpty && !_loading) emptyState(tri('لا توجد طلبات', 'Talep yok', 'No requests')),
      for (final o in _items)
        Builder(builder: (context) {
          final st = _status('${o['status'] ?? ''}');
          final title = ar ? ('${o['product_name_ar'] ?? ''}'.isNotEmpty ? '${o['product_name_ar']}' : ('${o['message'] ?? ''}'.isNotEmpty ? '${o['message']}' : 'طلب فرصة')) : ('${o['product_name_en'] ?? ''}'.isNotEmpty ? '${o['product_name_en']}' : ('${o['message'] ?? ''}'.isNotEmpty ? '${o['message']}' : 'Opportunity Request'));
          final factory = ar ? ('${o['factory_name_ar'] ?? ''}'.isNotEmpty ? '${o['factory_name_ar']}' : 'منصة رواد') : ('${o['factory_name_en'] ?? ''}'.isNotEmpty ? '${o['factory_name_en']}' : 'Rowad Platform');
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('REQ-${o['id']}', style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: st.$2.withAlpha(30), borderRadius: BorderRadius.circular(20)), child: Text(st.$1, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w700, color: st.$2))),
              ]),
              const SizedBox(height: 6),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
              Text(factory, style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.gold, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Text('${o['price'] ?? '---'} ${o['currency'] ?? (ar ? 'ر.س' : 'SAR')}', style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(AppData.dateTime(o['created_at'] as String?), style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ]),
          );
        }),
      if (_loading) emptyState('', loading: true),
      const SiteFooter(),
    ]);
  }
}
