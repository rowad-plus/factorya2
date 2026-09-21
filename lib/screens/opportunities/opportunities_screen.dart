import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';
import 'create_opportunity_screen.dart';

/// Picks the site's Arabic / Turkish / English string.
String tri(String ar, String tr, String en) => L10n.i.lang == 'ar' ? ar : (L10n.i.lang == 'tr' ? tr : en);

/// `/opportunity-requests`: the request call-to-action, then the list of requests
/// (only visible to signed-in users, like on the website).
class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthService.i.addListener(_onAuth);
    _load();
  }

  @override
  void dispose() {
    AuthService.i.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    if (!AuthService.i.isLoggedIn) {
      if (mounted) setState(() => _items = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.i.get('/opportunity-requests/get', query: {'per_page': 50});
      if (mounted) setState(() => _items = ApiClient.list(res['data']));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final loggedIn = AuthService.i.isLoggedIn;
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
                const HeaderBanner(),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOpportunityScreen()));
                  _load();
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.dark, Color(0xFF3D3A35)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(right: BorderSide(color: AppColors.gold, width: 4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('home.agent_banner_title', 'هل تريد أن تصل للمصانع المناسبة؟'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, height: 1.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                      child: Text(t('home.agent_banner_cta', 'اطلب فرصتك'), style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.dark)),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(tri('طلبات الفرص والشراكات', 'Fırsat ve Ortaklık Talepleri', 'Opportunity & Partnership Requests'), style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  tri('قائمة بالطلبات والفرص التي أرسلها المستخدمون والشركاء للتواصل مع المصانع.', 'Kullanıcılar ve ortaklar tarafından fabrikalara gönderilen tüm taleplerin ve fırsatların listesi.', 'A list of requests and business opportunities sent by users to reach out to factories.'),
                  style: GoogleFonts.tajawal(fontSize: 13.5, color: AppColors.muted, height: 1.7),
                ),
              ),
              if (!loggedIn)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF3F4F6))),
                  child: Column(children: [
                    Container(width: 70, height: 70, decoration: const BoxDecoration(color: AppColors.gold3, shape: BoxShape.circle), child: const Icon(Icons.lock_outline, color: AppColors.gold, size: 30)),
                    const SizedBox(height: 14),
                    Text(tri('سجّل دخول عشان تشوف الطلبات', 'Talepleri görmek için giriş yapın', 'Sign in to view requests'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(tri('قائمة طلبات الفرص والشراكات متاحة فقط للمستخدمين المسجَّلين.', 'Fırsat ve ortaklık talepleri listesi yalnızca giriş yapmış kullanıcılar için görüntülenebilir.', 'The opportunity & partnership requests list is only visible to signed-in users.'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.6)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => LoginModal.show(context),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(tri('تسجيل الدخول', 'Giriş Yap', 'Sign In'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
                    ),
                  ]),
                )
              else if (_loading)
                Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [const CircularProgressIndicator(color: AppColors.gold), const SizedBox(height: 10), Text(tri('جاري تحميل الطلبات...', 'Talepler yükleniyor...', 'Loading requests...'), style: GoogleFonts.tajawal(color: AppColors.muted))])))
              else if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    const Icon(Icons.work_outline, size: 40, color: AppColors.muted),
                    const SizedBox(height: 8),
                    Text(_error ?? tri('لا توجد طلبات مطابقة', 'Eşleşen talep bulunamadı', 'No requests found'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(tri('لم يتم العثور على أي طلبات في هذه الصفحة حالياً.', 'Şu anda görüntülenecek herhangi bir talep bulunmuyor.', 'No opportunities matching your criteria are currently available.'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
                  ]),
                )
              else
                for (final r in _items) _card(r),
              const SiteFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final opp = r['opportunity'] is Map ? Map<String, dynamic>.from(r['opportunity'] as Map) : <String, dynamic>{};
    final oppName = AppData.tr(opp, 'name').isNotEmpty ? AppData.tr(opp, 'name') : AppData.tr(opp, 'title');
    final email = '${r['email'] ?? ''}';
    return GestureDetector(
      onTap: () => context.push('/opportunity-requests/${r['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(child: Text('${r['full_name'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text))),
              if (oppName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(20)),
                  child: Text(oppName, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.gold)),
                ),
            ]),
            const SizedBox(height: 8),
            Text('${r['message'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 13.5, color: const Color(0xFF4A5568), height: 1.7)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.mail_outline, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 5),
              Expanded(child: Text(email.isEmpty ? tri('لا يوجد بريد إلكتروني', 'E-posta yok', 'No email provided') : email, style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))),
              const Icon(Icons.access_time, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(_date(r['created_at'] as String?), style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.muted)),
            ]),
          ],
        ),
      ),
    );
  }
}
