import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Job application (`POST /jobs/{id}/apply`) or CV submission (`POST /cvs`) with a PDF/DOC upload.
class ApplySheet {
  static void job(BuildContext context, {required int jobId, required String title}) =>
      _show(context, path: '/jobs/$jobId/apply', title: '${t('jobs.apply_title', 'تقديم طلب')} · $title', cvRequired: false, isCv: false);

  static void cv(BuildContext context) => _show(context, path: '/cvs', title: t('cvs.title', 'السيرة الذاتية'), cvRequired: true, isCv: true);

  static void _show(BuildContext context, {required String path, required String title, required bool cvRequired, required bool isCv}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ApplyForm(path: path, title: title, cvRequired: cvRequired, isCv: isCv),
    );
  }
}

class _ApplyForm extends StatefulWidget {
  final String path;
  final String title;
  final bool cvRequired;
  final bool isCv;
  const _ApplyForm({required this.path, required this.title, required this.cvRequired, required this.isCv});

  @override
  State<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends State<_ApplyForm> {
  final _name = TextEditingController(text: AuthService.i.name);
  final _phone = TextEditingController(text: AuthService.i.phone);
  final _email = TextEditingController();
  final _text = TextEditingController();
  final _jobTitle = TextEditingController();
  PlatformFile? _cv;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _text, _jobTitle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
    if (r != null && r.files.isNotEmpty) setState(() => _cv = r.files.first);
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || (widget.cvRequired && _cv == null)) {
      showAppToast(context, '⚠️ ${t('jobs.apply_error', 'تحقق من البيانات')}');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.i.postMultipart(
        widget.path,
        fields: {
          'full_name': _name.text.trim(),
          'phone': _phone.text.trim(),
          if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
          if (widget.isCv && _jobTitle.text.trim().isNotEmpty) 'job_title': _jobTitle.text.trim(),
          if (_text.text.trim().isNotEmpty) (widget.isCv ? 'description' : 'message'): _text.text.trim(),
        },
        files: [
          if (_cv?.bytes != null) MapEntry('cv', http.MultipartFile.fromBytes('cv', _cv!.bytes!, filename: _cv!.name)),
        ],
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(context, '✅ ${t('jobs.apply_success', 'تم التقديم بنجاح')}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.tajawal(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.title, style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: _dec(t('jobs.full_name', 'الاسم الكامل'))),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: _dec(t('jobs.phone', 'رقم الهاتف'))),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _dec(t('jobs.email', 'البريد الإلكتروني'))),
            if (widget.isCv) ...[const SizedBox(height: 10), TextField(controller: _jobTitle, decoration: _dec(t('cvs.no_job_title', 'المسمى الوظيفي')))],
            const SizedBox(height: 10),
            TextField(controller: _text, maxLines: 3, decoration: _dec(t('jobs.message', 'رسالة'))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.upload_file, color: AppColors.gold),
              label: Align(alignment: AlignmentDirectional.centerStart, child: Text(_cv?.name ?? t('jobs.upload_cv', 'رفع السيرة الذاتية'), overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(color: AppColors.text))),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _send,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(t('jobs.send_application', 'إرسال الطلب'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)),
            ),
          ]),
        ),
      ),
    );
  }
}
