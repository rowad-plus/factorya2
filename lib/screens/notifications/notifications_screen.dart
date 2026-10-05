import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shell_widgets.dart' show emptyState;
import '../auth/login_modal.dart';
import '../opportunities/opportunities_screen.dart' show tri;

/// `/notifications`: the user's notifications (same items that arrive as push), newest first.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    AuthService.i.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    AuthService.i.removeListener(_reload);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _items.clear();
    _page = 0;
    _lastPage = 1;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage || !AuthService.i.isLoggedIn) {
      if (mounted) setState(() {});
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiClient.i.get('/notifications', query: {'page': _page + 1, 'per_page': 20});
      final meta = res['meta'];
      _lastPage = meta is Map ? ((meta['last_page'] as num?)?.toInt() ?? 1) : 1;
      if (meta is Map) PushService.unread.value = (meta['unread_count'] as num?)?.toInt() ?? PushService.unread.value;
      _items.addAll(ApiClient.list(res['data']).map((e) => Map<String, dynamic>.from(e as Map)));
      _page++;
      _failed = false;
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.i.post('/notifications/read');
      for (final n in _items) {
        n['is_read'] = true;
      }
      PushService.unread.value = 0;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _open(Map<String, dynamic> n) {
    if (n['is_read'] != true) {
      n['is_read'] = true;
      PushService.unread.value = (PushService.unread.value - 1).clamp(0, 1 << 30);
      ApiClient.i.post('/notifications/read', body: {'ids': [n['id']]}).catchError((_) => <String, dynamic>{});
      setState(() {});
    }
    final data = n['data'] is Map ? Map<String, dynamic>.from(n['data'] as Map) : <String, dynamic>{'type': n['type']};
    final route = PushService.routeFor(data);
    if (route != null && route != '/notifications') PushService.navigate?.call(route);
  }

  static (IconData, Color) _style(String type) => switch (type) {
        'chat' => (Icons.chat_bubble_outline, const Color(0xFF5563DE)),
        'comment' || 'comment_reply' || 'opportunity_comment' => (Icons.mode_comment_outlined, const Color(0xFF22A855)),
        'like' => (Icons.favorite_border, const Color(0xFFE84040)),
        'opportunity' => (Icons.campaign_outlined, AppColors.gold),
        'admin' => (Icons.notifications_active_outlined, AppColors.gold),
        _ => (Icons.inbox_outlined, const Color(0xFF7A5600)),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.i, AuthService.i]),
      builder: (context, _) {
        if (!AuthService.i.isLoggedIn) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 44, color: AppColors.gold),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => LoginModal.show(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                child: Text(t('nav.login', 'تسجيل الدخول'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
              ),
            ]),
          );
        }
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _reload,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            children: [
              Row(children: [
                Expanded(
                  child: Text(tri('الإشعارات', 'Bildirimler', 'Notifications'),
                      style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: PushService.unread,
                  builder: (_, count, __) => count == 0
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _markAllRead,
                          child: Text(tri('تعليم الكل كمقروء', 'Tümünü okundu say', 'Mark all read'),
                              style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
                        ),
                ),
              ]),
              const SizedBox(height: 8),
              if (_items.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: emptyState(_failed
                      ? tri('تعذّر تحميل الإشعارات', 'Bildirimler yüklenemedi', 'Could not load notifications')
                      : tri('لا توجد إشعارات بعد', 'Henüz bildirim yok', 'No notifications yet')),
                ),
              for (final n in _items) _tile(n),
              if (_loading)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.gold))),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final read = n['is_read'] == true;
    final (icon, color) = _style('${n['type'] ?? ''}');
    final body = '${n['body'] ?? ''}';
    return GestureDetector(
      onTap: () => _open(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: read ? Colors.white : AppColors.gold3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: read ? AppColors.border : AppColors.gold.withAlpha(90)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['title'] ?? ''}',
                  style: GoogleFonts.tajawal(fontSize: 14, fontWeight: read ? FontWeight.w600 : FontWeight.w800, color: AppColors.text, height: 1.4)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.4)),
              ],
              const SizedBox(height: 4),
              Text(AppData.timeAgo(n['created_at'] as String?), style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          if (!read)
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
