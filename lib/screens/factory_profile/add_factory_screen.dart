import 'package:flutter/material.dart';
import '../../widgets/shell_widgets.dart';
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
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';

/// `/factory/create`: two-step factory registration (`POST /factories/register`).
class AddFactoryScreen extends StatefulWidget {
  const AddFactoryScreen({super.key});

  @override
  State<AddFactoryScreen> createState() => _AddFactoryScreenState();
}

class _AddFactoryScreenState extends State<AddFactoryScreen> {
  int _step = 0;
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nickname = TextEditingController();
  final _responsible = TextEditingController();
  final _register = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  int? _country;
  int? _city;
  int? _gate;
  int? _category;
  final Set<int> _opps = {};
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _categories = [];
  XFile? _logo;
  bool _busy = false;
  bool _hidePass = true;

  @override
  void initState() {
    super.initState();
    _country = AppData.countryId;
    _loadCities();
  }

  Future<void> _loadCities() async {
    final id = _country;
    if (id == null) return;
    try {
      final res = await ApiClient.i.get('/countries/$id/cities', query: {'per_page': 100});
      if (mounted) setState(() => _cities = ApiClient.list(res['data']));
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    if (_gate == null) return;
    final subs = await AppData.fetchSubcategories(_gate!);
    if (mounted) setState(() => _categories = subs);
  }

  void _toast(String s) => showAppToast(context, '⚠️ $s');

  /// `+<dial code><number without leading zero>`, the format the website stores and logs in with.
  String _e164(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    final dial = AppData.countries.where((c) => c['id'] == _country).map((c) => '${c['phone_code'] ?? ''}').firstOrNull ?? '+966';
    return '${dial.startsWith('+') ? dial : '+$dial'}${digits.replaceFirst(RegExp(r'^0+'), '')}';
  }

  bool _validStep1() {
    if (_name.text.trim().isEmpty) return _no(t('add_factory.validation_factory_name_req', 'اسم المصنع مطلوب'));
    if (_password.text.length < 6) return _no(t('add_factory.validation_password_min', 'كلمة المرور 6 أحرف على الأقل'));
    if (_password.text != _confirm.text) return _no(t('add_factory.validation_confirm_password_match', 'كلمتا المرور غير متطابقتين'));
    if (_nickname.text.trim().isNotEmpty && !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(_nickname.text.trim())) return _no(t('add_factory.validation_nickname_invalid', 'أحرف إنجليزية وأرقام فقط'));
    if (_responsible.text.trim().isEmpty) return _no(t('add_factory.validation_responsible_name_req', 'اسم المسؤول مطلوب'));
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) return _no(t('add_factory.validation_email_invalid', 'بريد غير صالح'));
    if (_phone.text.trim().length < 7) return _no(t('add_factory.validation_phone_req', 'رقم الهاتف مطلوب'));
    if (_country == null) return _no(t('add_factory.validation_country_req', 'اختر الدولة'));
    if (_city == null) return _no(t('add_factory.validation_city_req', 'اختر المدينة'));
    return true;
  }

  bool _no(String msg) {
    _toast(msg);
    return false;
  }

  Future<void> _submit() async {
    if (_gate == null) return _toast(t('add_factory.validation_gate_req', 'اختر الباب'));
    if (_category == null) return _toast(t('add_factory.validation_category_req', 'اختر التصنيف'));
    if (_description.text.trim().isEmpty) return _toast(t('add_factory.validation_description_req', 'النبذة مطلوبة'));
    if (_opps.isEmpty) return _toast(t('add_factory.validation_options_min', 'اختر خياراً واحداً على الأقل'));
    setState(() => _busy = true);
    try {
      final cityName = _cities.where((c) => c['id'] == _city).map((c) => AppData.tr(c, 'name')).firstOrNull ?? '';
      final fields = <String, String>{
        'factory_name': _name.text.trim(),
        'username': _nickname.text.trim().isEmpty ? _name.text.trim() : _nickname.text.trim(),
        if (_nickname.text.trim().isNotEmpty) 'nickname': _nickname.text.trim(),
        'password': _password.text,
        'password_confirmation': _confirm.text,
        'responsible_person_name': _responsible.text.trim(),
        'commercial_register_number': _register.text.trim(),
        'email': _email.text.trim(),
        'phone_number': _e164(_phone.text),
        'country_code': '${AppData.countries.where((c) => c['id'] == _country).map((c) => c['code']).firstOrNull ?? 'SA'}',
        'country_id': '$_country',
        'city_id': '$_city',
        'governorate': cityName,
        'gate_id': '$_gate',
        'category_id': '$_category',
        'description': _description.text.trim(),
        for (var i = 0; i < _opps.length; i++) 'opportunity_ids[$i]': '${_opps.elementAt(i)}',
      };
      final files = <MapEntry<String, http.MultipartFile>>[];
      if (_logo != null) files.add(MapEntry('logo', http.MultipartFile.fromBytes('logo', await _logo!.readAsBytes(), filename: _logo!.name)));
      await ApiClient.i.postMultipart('/factories/register', fields: fields, files: files);
      if (!mounted) return;
      showAppToast(context, '✅ ${t('add_factory.toast_success_title', 'تم تسجيل المصنع بنجاح')}');
      context.go('/');
      LoginModal.show(context);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${t('add_factory.toast_error_title', 'فشل تسجيل المصنع')}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _l(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(s, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700)));

  Widget _dropdown<T>(String hint, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) =>
      DropdownButtonFormField<T>(initialValue: value, isExpanded: true, decoration: _dec(hint), items: items, onChanged: onChanged);

  @override
  Widget build(BuildContext context) {
    if (AuthService.i.isLoggedIn) {
      return Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t('add_factory.already_registered_title', 'مسجل بالفعل'), style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(t('add_factory.already_registered_desc'), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
      ])));
    }
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) => ListView(
        padding: EdgeInsets.zero,
        children: [
                const HeaderBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Row(children: [
              for (var i = 0; i < 2; i++) ...[
                Expanded(child: Container(height: 5, decoration: BoxDecoration(color: i <= _step ? AppColors.gold : AppColors.border, borderRadius: BorderRadius.circular(3)))),
                if (i == 0) const SizedBox(width: 6),
              ],
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(_step == 0 ? t('add_factory.heading_step_1') : t('add_factory.heading_step_2'), style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w800))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _step == 0 ? _step1() : _step2(),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _step1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _l(t('add_factory.factory_name_label')),
        TextField(controller: _name, decoration: _dec(t('add_factory.factory_name_placeholder'))),
        _l(t('add_factory.password_label')),
        TextField(controller: _password, obscureText: _hidePass, decoration: _dec(t('add_factory.password_placeholder')).copyWith(suffixIcon: IconButton(icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: () => setState(() => _hidePass = !_hidePass)))),
        _l(t('add_factory.confirm_password_label')),
        TextField(controller: _confirm, obscureText: _hidePass, decoration: _dec(t('add_factory.confirm_password_placeholder'))),
        _l('${t('add_factory.nickname_label')} ${t('add_factory.nickname_hint')}'),
        TextField(controller: _nickname, textDirection: TextDirection.ltr, decoration: _dec(t('add_factory.nickname_placeholder'))),
        _l(t('add_factory.responsible_name_label')),
        TextField(controller: _responsible, decoration: _dec(t('add_factory.responsible_name_placeholder'))),
        _l(t('add_factory.commercial_reg_label')),
        TextField(controller: _register, decoration: _dec(t('add_factory.commercial_reg_placeholder'))),
        _l(t('add_factory.email_label')),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _dec(t('add_factory.email_placeholder'))),
        _l(t('add_factory.phone_label')),
        TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: _dec('+966...')),
        _l(t('add_factory.country_label')),
        _dropdown<int>(t('add_factory.country_placeholder'), _country, [for (final c in AppData.countries) DropdownMenuItem(value: c['id'] as int, child: Text(AppData.tr(c, 'name'), style: GoogleFonts.tajawal(fontSize: 13)))], (v) {
          setState(() {
            _country = v;
            _city = null;
            _cities = [];
          });
          _loadCities();
        }),
        _l(t('add_factory.city_label')),
        _dropdown<int>(t('add_factory.city_placeholder'), _city, [for (final c in _cities) DropdownMenuItem(value: c['id'] as int, child: Text(AppData.tr(c, 'name'), style: GoogleFonts.tajawal(fontSize: 13)))], (v) => setState(() => _city = v)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { if (_validStep1()) setState(() => _step = 1); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(t('add_factory.btn_next', 'التالي'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)))),
      ]);

  Widget _step2() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _l(t('add_factory.gates_label')),
        _dropdown<int>(t('add_factory.gates_placeholder'), _gate, [for (final d in AppData.doors) DropdownMenuItem(value: d['id'] as int, child: Text(d['name'] as String, style: GoogleFonts.tajawal(fontSize: 13), overflow: TextOverflow.ellipsis))], (v) {
          setState(() {
            _gate = v;
            _category = null;
            _categories = [];
          });
          _loadCategories();
        }),
        _l(t('add_factory.categories_label')),
        _dropdown<int>(t('add_factory.categories_placeholder'), _category, [for (final c in _categories) DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String, style: GoogleFonts.tajawal(fontSize: 13), overflow: TextOverflow.ellipsis))], (v) => setState(() => _category = v)),
        _l(t('add_factory.logo_description_label')),
        GestureDetector(
          onTap: () async {
            final f = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (f != null) setState(() => _logo = f);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              if (_logo == null)
                const Icon(Icons.upload_outlined, color: AppColors.gold)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder(
                    future: _logo!.readAsBytes(),
                    builder: (_, snap) => snap.hasData ? Image.memory(snap.data!, width: 48, height: 48, fit: BoxFit.cover) : const SizedBox(width: 48, height: 48),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(child: Text(_logo == null ? t('add_factory.logo_upload_prompt') : t('add_factory.change_image', 'تغيير الصورة'), style: GoogleFonts.tajawal(fontSize: 13, color: _logo == null ? AppColors.muted : AppColors.text))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        TextField(controller: _description, maxLines: 4, decoration: _dec(t('add_factory.description_placeholder'))),
        _l(t('add_factory.opportunities_label')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in AppData.opportunities)
            FilterChip(
              label: Text(o.title, style: GoogleFonts.tajawal(fontSize: 12.5)),
              selected: _opps.contains(int.tryParse(o.id)),
              selectedColor: AppColors.gold.withAlpha(90),
              onSelected: (v) => setState(() => v ? _opps.add(int.parse(o.id)) : _opps.remove(int.parse(o.id))),
            ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(t('add_factory.btn_back', 'السابق'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, color: AppColors.text)))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: ElevatedButton(onPressed: _busy ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(t('add_factory.btn_submit', 'إضافة المصنع'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)))),
        ]),
      ]);
}
