import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/net_image.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';
import 'opportunities_screen.dart';

/// `/opportunity-requests/{id}`: the request and its comment thread.
class RequestDetailScreen extends StatefulWidget {
  final String id;
  const RequestDetailScreen({super.key, required this.id});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Map<String, dynamic>? _r;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!AuthService.i.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final r = await ApiClient.i.get('/opportunity-requests/${widget.id}');
      final c = await ApiClient.i.get('/opportunity-requests/${widget.id}/comments', query: {'per_page': 100});
      if (mounted) {
        setState(() {
          _r = Map<String, dynamic>.from(r['data'] as Map);
          _comments = ApiClient.list(c['data']);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.i.post('/opportunity-requests/${widget.id}/comments', body: {'message': txt});
      _ctrl.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : r == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(AuthService.i.isLoggedIn ? tri('الطلب غير موجود', 'Talep bulunamadı', 'Request not found') : tri('سجّل دخول عشان تشوف الطلبات', 'Talepleri görmek için giriş yapın', 'Sign in to view requests'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(tri('قد يكون هذا الطلب غير متاح أو لا تملك صلاحية الاطلاع عليه.', 'Bu talep artık mevcut olmayabilir veya görüntüleme yetkiniz yok.', "This request may no longer be available or you don't have permission to view it."), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 14),
                      if (!AuthService.i.isLoggedIn) ElevatedButton(onPressed: () => LoginModal.show(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold), child: Text(tri('تسجيل الدخول', 'Giriş Yap', 'Sign In'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
                      TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(tri('الرجوع لطلبات الفرص والشراكات', 'Fırsat Taleplerine Dön', 'Back to Opportunity Requests'), style: GoogleFonts.tajawal(color: AppColors.gold, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                )
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                const HeaderBanner(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: Icon(L10n.i.isRtl ? Icons.arrow_forward : Icons.arrow_back, size: 16, color: AppColors.gold),
                              label: Text(tri('الرجوع لطلبات الفرص والشراكات', 'Fırsat Taleplerine Dön', 'Back to Opportunity Requests'), style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
                            ),
                          ),
                        ),
                        _requestCard(r),
                        _commentsCard(),
                        const SiteFooter(),
                      ],
                    ),
                  ),
                  _composer(),
                ]),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final opp = r['opportunity'] is Map ? Map<String, dynamic>.from(r['opportunity'] as Map) : <String, dynamic>{};
    final oppName = AppData.tr(opp, 'name').isNotEmpty ? AppData.tr(opp, 'name') : AppData.tr(opp, 'title');
    final email = '${r['email'] ?? ''}';
    final attachment = '${r['attachment_url'] ?? ''}';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (oppName.isNotEmpty)
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(20)), child: Text(oppName, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold))),
        const SizedBox(height: 10),
        Text('${r['full_name'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.phone_outlined, size: 15, color: AppColors.gold),
          const SizedBox(width: 6),
          Directionality(textDirection: TextDirection.ltr, child: Text('${r['phone'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 13))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.mail_outline, size: 15, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(email.isEmpty ? tri('لا يوجد بريد إلكتروني', 'E-posta yok', 'No email provided') : email, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
        ]),
        const SizedBox(height: 12),
        Text('${r['message'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 14, color: const Color(0xFF4A5568), height: 1.8)),
        if (attachment.isNotEmpty) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(attachment);
              if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.attach_file, size: 16, color: AppColors.gold),
            label: Text(tri('المرفق', 'Ek', 'Attachment'), style: GoogleFonts.tajawal(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  Widget _commentsCard() => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
        child: _comments.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(12), child: Text(tri('لا توجد تعليقات بعد.', 'Henüz yorum yok.', 'No comments yet.'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted))))
            : Column(children: [
                for (final c in _comments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      netAvatar(AppData.userImageUrl(c['user'] is Map ? Map<String, dynamic>.from(c['user'] as Map) : {}), c['user'] is Map ? '${(c['user'] as Map)['name'] ?? ''}' : '', size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['user'] is Map ? '${(c['user'] as Map)['name'] ?? ''}' : '', style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w800)),
                            if ('${c['message'] ?? ''}'.isNotEmpty) Text('${c['message']}', style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF4A5568), height: 1.6)),
                            if ('${c['image_url'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 140, width: double.infinity, child: NetImage(url: '${c['image_url']}', fallback: '', width: double.infinity, height: 140)))),
                            Text(AppData.timeAgo(c['created_at'] as String?), style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.muted)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
              ]),
      );

  Widget _composer() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.tajawal(fontSize: 13),
              decoration: InputDecoration(
                hintText: tri('اكتب تعليقك...', 'Yorumunuzu yazın...', 'Write a comment...'),
                hintStyle: GoogleFonts.tajawal(fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.gold)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle), child: _sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : const Icon(Icons.send_rounded, size: 18, color: AppColors.dark)),
          ),
        ]),
      );
}
