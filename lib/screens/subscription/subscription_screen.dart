import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';
import '../opportunities/opportunities_screen.dart' show tri;

/// `/subscription`: choose a package, see the bank details, upload the transfer receipt
/// (`POST /factories/{id}/subscription-requests`) and follow previous requests.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _requests = [];
  int? _package;
  XFile? _receipt;
  bool _loading = true;
  bool _sending = false;

  int? get _factoryId => AuthService.i.factoryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fid = _factoryId;
    try {
      final b = await ApiClient.i.get('/bank-accounts');
      final bd = b['data'];
      _banks = bd is Map ? ApiClient.list(bd['bank_accounts']) : [];
      if (fid != null && AuthService.i.isLoggedIn) {
        final p = await ApiClient.i.get('/factories/$fid/subscription-requests/packages');
        final pd = p['data'];
        _packages = pd is Map ? ApiClient.list(pd['packages']) : ApiClient.list(pd);
        final r = await ApiClient.i.get('/factories/$fid/subscription-requests');
        _requests = ApiClient.list(r['data']);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final fid = _factoryId;
    if (fid == null || _package == null || _receipt == null) {
      showAppToast(context, '⚠️ ${tri('اختر الباقة وارفع إيصال التحويل', 'Paketi seçin ve dekontu yükleyin', 'Choose a package and upload the transfer receipt')}');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.i.postMultipart('/factories/$fid/subscription-requests', fields: {'package_id': '$_package'}, files: [
        MapEntry('transfer_receipt', http.MultipartFile.fromBytes('transfer_receipt', await _receipt!.readAsBytes(), filename: _receipt!.name)),
      ]);
      if (!mounted) return;
      showAppToast(context, '✅ ${tri('تم إرسال طلب الاشتراك', 'Abonelik talebi gönderildi', 'Subscription request sent')}');
      setState(() {
        _receipt = null;
        _package = null;
      });
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.i, AuthService.i]),
      builder: (context, _) {
        final auth = AuthService.i;
        if (!auth.isLoggedIn) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('prices.login_first', 'يرجى تسجيل الدخول أولاً'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => LoginModal.show(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold), child: Text(t('nav.login', 'تسجيل الدخول'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
          ]));
        }
        if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        if (_factoryId == null) return emptyState(t('prices.factory_account_required', 'يجب أن تمتلك حساب مصنع للاشتراك في الباقات'));
        return ListView(
          padding: EdgeInsets.zero,
          children: [
                const HeaderBanner(),
            Padding(padding: const EdgeInsets.all(16), child: Text(t('prices.title', 'خطط الأسعار'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800))),
            for (final p in _packages)
              GestureDetector(
                onTap: () => setState(() => _package = p['id'] as int),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _package == p['id'] ? AppColors.gold : AppColors.border, width: _package == p['id'] ? 2 : 1)),
                  child: Row(children: [
                    Icon(_package == p['id'] ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(AppData.tr(p, 'name'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(AppData.tr(p, 'description'), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
                    ])),
                  ]),
                ),
              ),
            if (_packages.isEmpty) emptyState(t('prices.no_plans', 'لا توجد خطط متاحة حالياً')),
            if (_banks.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: Text(tri('بيانات التحويل البنكي', 'Banka havalesi bilgileri', 'Bank transfer details'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
              for (final b in _banks)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b['bank_name'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
                    for (final row in [('account_holder_name', tri('صاحب الحساب', 'Hesap sahibi', 'Account holder')), ('iban', 'IBAN'), ('account_number', tri('رقم الحساب', 'Hesap no', 'Account number')), ('swift_code', 'SWIFT'), ('currency', tri('العملة', 'Para birimi', 'Currency'))])
                      if ('${b[row.$1] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('${row.$2}: ${b[row.$1]}', style: GoogleFonts.tajawal(fontSize: 12.5))),
                    if ('${b['instructions'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${b['instructions']}', style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))),
                  ]),
                ),
            ],
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (f != null) setState(() => _receipt = f);
                  },
                  icon: const Icon(Icons.upload_file, color: AppColors.gold),
                  label: Text(_receipt == null ? tri('رفع إيصال التحويل', 'Dekont yükle', 'Upload transfer receipt') : '✓ ${tri('تم اختيار الإيصال', 'Dekont seçildi', 'Receipt selected')}', style: GoogleFonts.tajawal(color: AppColors.text)),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(t('prices.btn_subscribe', 'اشترك الآن'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)),
                ),
              ]),
            ),
            if (_requests.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: Text(tri('طلبات الاشتراك', 'Abonelik talepleri', 'Subscription requests'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
              for (final r in _requests)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(child: Text(r['package'] is Map ? AppData.tr(Map<String, dynamic>.from(r['package'] as Map), 'name') : '#${r['id']}', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700))),
                    Text('${r['status'] ?? ''}', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  ]),
                ),
            ],
            TextButton(onPressed: () => context.push('/prices'), child: Text(t('about_hero.packages', 'باقات الاشتراك'), style: GoogleFonts.tajawal(color: AppColors.gold, fontWeight: FontWeight.w700))),
            const SiteFooter(),
          ],
        );
      },
    );
  }
}
