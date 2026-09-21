import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Passwordless sign-in like the website: phone → 4-digit OTP; register (name, phone) → OTP.
class LoginModal {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AuthSheet(),
    );
  }
}

enum _Step { login, register, otp }

class _AuthSheet extends StatefulWidget {
  const _AuthSheet();

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  _Step _step = _Step.login;
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _signup = false;
  int _timer = 0;
  Timer? _ticker;

  String get _country => '${AppData.country?['code'] ?? 'SA'}';
  String get _dial => '${AppData.country?['phone_code'] ?? '+966'}';

  /// `+9665XXXXXXXX` — dial code plus the number without its leading zero.
  String get _full {
    final raw = _phone.text.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.startsWith('+')) return raw;
    return '$_dial${raw.replaceFirst(RegExp(r'^0+'), '')}';
  }

  /// The phone format the server accepted (`+966...`, or the bare number older accounts were saved with).
  String? _matched;

  /// Formats to try for a typed number: E.164 first, then the number exactly as typed, then without a leading zero.
  List<String> get _candidates {
    final typed = _phone.text.replaceAll(RegExp(r'[^\d+]'), '');
    final noZero = typed.replaceFirst(RegExp(r'^0+'), '');
    return {_full, typed, noZero}.where((e) => e.isNotEmpty).toList();
  }

  String get _phoneForServer => _matched ?? _full;

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_phone, _name, _email, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _ticker?.cancel();
    setState(() => _timer = 60);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _timer--);
      if (_timer <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } catch (_) {
      if (mounted) showAppToast(context, '⚠️ ${t('login_page.login_error', 'حدث خطأ')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _need(bool ok, String msg) {
    if (!ok) showAppToast(context, '⚠️ $msg');
    return ok;
  }

  Future<void> _login() => _run(() async {
        if (!_need(_phone.text.trim().length >= 7, t('login_page.validation_phone_invalid', 'رقم الهاتف غير صالح'))) return;
        String? firstMessage;
        String? otherMessage;
        _matched = null;
        for (final candidate in _candidates) {
          try {
            await AuthService.i.requestLoginOtp(candidate, country: _country);
            _matched = candidate;
            break;
          } on ApiException catch (e) {
            if (e.status != 422) rethrow;
            firstMessage ??= e.message;
            if (e.message != firstMessage) otherMessage ??= e.message;
          }
        }
        // A different message from another format means the account exists there (e.g. wrong password).
        if (_matched == null) throw ApiException(otherMessage ?? firstMessage ?? t('login_page.login_error', 'حدث خطأ'), status: 422);
        _signup = false;
        _code.clear();
        setState(() => _step = _Step.otp);
        _startTimer();
        if (mounted) showAppToast(context, t('login_page.otp_sent_title', 'تم إرسال رمز التحقق'));
      });

  Future<void> _register() => _run(() async {
        if (!_need(_name.text.trim().isNotEmpty, t('add_factory.validation_responsible_name_req', 'الاسم مطلوب'))) return;
        if (!_need(_phone.text.trim().length >= 7, t('login_page.validation_phone_invalid', 'رقم الهاتف غير صالح'))) return;
        _matched = _full;
        await AuthService.i.register(_name.text.trim(), _full, email: _email.text.trim(), country: _country);
        _signup = true;
        _code.clear();
        setState(() => _step = _Step.otp);
        _startTimer();
        if (mounted) showAppToast(context, t('register_page.otp_sent_title', 'تم إرسال رمز التحقق'));
      });

  Future<void> _verify() => _run(() async {
        if (!_need(_code.text.length == 4, t('verify_otp_page.error_desc', 'رمز التحقق غير صحيح'))) return;
        await AuthService.i.verifyOtp(_phoneForServer, _code.text, signup: _signup, country: _country);
        if (!mounted) return;
        Navigator.pop(context);
        showAppToast(context, '✅ ${t('verify_otp_page.success_title', 'تم التحقق بنجاح')}');
      });

  Future<void> _resend() => _run(() async {
        await AuthService.i.resendOtp(_phoneForServer, signup: _signup, country: _country);
        _startTimer();
        if (mounted) showAppToast(context, t('login_page.otp_sent_title', 'تم إرسال رمز التحقق'));
      });

  // ───────────────────────── UI ─────────────────────────

  InputDecoration _dec(String hint, {Widget? suffix, String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.tajawal(color: AppColors.muted, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        prefixText: prefix,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      );

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(s, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700))));

  Widget _phoneField() => TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        style: GoogleFonts.tajawal(fontSize: 15),
        decoration: _dec('5XXXXXXXX', prefix: '$_dial  '),
      );

  Widget _btn(String label, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : onTap,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(label, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)),
          ),
        ),
      );

  Widget _link(String label, VoidCallback onTap) => TextButton(onPressed: onTap, child: Text(label, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)));

  Widget _otpField() => TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 14),
        decoration: _dec('••••').copyWith(counterText: ''),
      );

  List<Widget> _body() {
    switch (_step) {
      case _Step.login:
        return [
          Text(t('login_page.welcome_back', 'مرحبًا بعودتك!'), style: GoogleFonts.tajawal(fontSize: 21, fontWeight: FontWeight.w900)),
          Text(t('login_page.login_to_your_account', 'تسجيل الدخول إلى حسابك'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
          _label(t('login_page.phone_label', 'رقم الهاتف')),
          _phoneField(),
          _btn(t('verify_otp_page.send_code', 'إرسال رمز التحقق'), _login),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(t('login_page.no_account', 'ليس لديك حساب؟'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
            _link(t('login_page.register_now', 'سجل الآن'), () => setState(() => _step = _Step.register)),
          ]),
        ];
      case _Step.register:
        return [
          Text(t('login_page.register_now', 'سجل الآن'), style: GoogleFonts.tajawal(fontSize: 21, fontWeight: FontWeight.w900)),
          _label(t('add_factory.responsible_name_label', 'الاسم')),
          TextField(controller: _name, style: GoogleFonts.tajawal(fontSize: 15), decoration: _dec('')),
          _label(t('login_page.phone_label', 'رقم الهاتف')),
          _phoneField(),
          _label(t('add_factory.email_label', 'البريد الإلكتروني')),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _dec('example@mail.com')),
          _btn(t('login_page.register_now', 'سجل الآن'), _register),
          _link(t('login_page.login', 'تسجيل الدخول'), () => setState(() => _step = _Step.login)),
        ];
      case _Step.otp:
        return [
          Text(t('verify_otp_page.title', 'أدخل رمز التحقق'), style: GoogleFonts.tajawal(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${t('verify_otp_page.desc_1', '')}$_phoneForServer${t('verify_otp_page.desc_2', '')}', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.6)),
          const SizedBox(height: 16),
          _otpField(),
          _btn(t('verify_otp_page.verify_btn', 'تحقق'), _verify),
          _timer > 0
              ? Padding(padding: const EdgeInsets.only(top: 10), child: Text('${t('verify_otp_page.try_again', 'حاول مرة أخرى بعد')} $_timer', style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.muted)))
              : _link(t('verify_otp_page.didnt_receive', 'لم تستلم الرمز؟'), _resend),
          _link('←', () => setState(() => _step = _signup ? _Step.register : _Step.login)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(children: [
            Container(width: 38, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16), decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            ..._body(),
          ]),
        ),
      ),
    );
  }
}
