import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../models/opportunity_model.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Submits an opportunity request (`/opportunity-requests/store` or `/guest-store`).
class CreateOpportunityScreen extends StatefulWidget {
  final OpportunityModel? preselected;
  const CreateOpportunityScreen({super.key, this.preselected});

  @override
  State<CreateOpportunityScreen> createState() => _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState extends State<CreateOpportunityScreen> {
  final _nameCtrl = TextEditingController(text: AuthService.i.name);
  final _phoneCtrl = TextEditingController(text: AuthService.i.phone);
  final _emailCtrl = TextEditingController(text: AuthService.i.email);
  final _messageCtrl = TextEditingController();
  late String? _oppId = widget.preselected?.id ?? (AppData.opportunities.isNotEmpty ? AppData.opportunities.first.id : null);
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_oppId == null || _nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      showAppToast(context, '⚠️ يرجى ملء الاسم والهاتف والتفاصيل');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.i.post(
        AuthService.i.isLoggedIn ? '/opportunity-requests/store' : '/opportunity-requests/guest-store',
        body: {
          'opportunity_id': int.parse(_oppId!),
          'full_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
          'message': _messageCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(context, '🎉 تم إرسال طلبك بنجاح');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.tajawal(color: AppColors.muted, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 12),
        child: Text(t, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const StatusBar(),
          Container(
            color: AppColors.dark,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withAlpha(23), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16)),
                ),
                const Spacer(),
                Text('تقديم طلب فرصة', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                const Spacer(),
                const SizedBox(width: 32),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _label('نوع الفرصة'),
                DropdownButtonFormField<String>(
                  initialValue: _oppId,
                  isExpanded: true,
                  decoration: _dec('اختر النوع'),
                  items: AppData.opportunities
                      .map((o) => DropdownMenuItem(value: o.id, child: Text(o.title, style: GoogleFonts.tajawal(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _oppId = v),
                ),
                _label('الاسم الكامل'),
                TextField(controller: _nameCtrl, decoration: _dec('الاسم'), style: GoogleFonts.tajawal(fontSize: 13)),
                _label('رقم الهاتف'),
                TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: _dec('05XXXXXXXX'), style: GoogleFonts.tajawal(fontSize: 13)),
                _label('البريد الإلكتروني (اختياري)'),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _dec('name@example.com'), style: GoogleFonts.tajawal(fontSize: 13)),
                _label('تفاصيل الطلب'),
                TextField(controller: _messageCtrl, maxLines: 6, decoration: _dec('اكتب تفاصيل طلبك...'), style: GoogleFonts.tajawal(fontSize: 13)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('إرسال الطلب', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
