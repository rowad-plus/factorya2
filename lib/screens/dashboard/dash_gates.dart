import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/shell_widgets.dart';
import 'dash_kit.dart';

/// Links the factory to gates (الأبواب) and categories (التصنيفات) — `PUT /my-factory` step 1.
/// Step 1 validates the whole basic-info block, so every existing value is sent back with the new links.
class GatesCategoriesSection extends StatefulWidget {
  const GatesCategoriesSection({super.key});

  @override
  State<GatesCategoriesSection> createState() => _GatesCategoriesSectionState();
}

class _GatesCategoriesSectionState extends State<GatesCategoriesSection> {
  Map<String, dynamic>? _f;
  final Set<int> _gates = {};
  final Set<int> _cats = {};
  final Map<int, List<Map<String, dynamic>>> _subs = {};
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<int> _ids(dynamic list, [String key = 'id']) {
    final out = <int>{};
    if (list is List) {
      for (final e in list) {
        final v = e is Map ? e[key] : e;
        final n = v is num ? v.toInt() : int.tryParse('$v');
        if (n != null) out.add(n);
      }
    }
    return out;
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/my-factory'), allLocales: true);
      final f = Map<String, dynamic>.from(r['data'] as Map);
      _gates
        ..clear()
        ..addAll(_ids(f['gate_ids']).isNotEmpty ? _ids(f['gate_ids']) : _ids(f['gates']));
      var cats = _ids(f['category_ids']);
      if (cats.isEmpty) cats = _ids(f['categories']);
      if (cats.isEmpty && f['category'] is Map) cats = _ids([f['category']]);
      if (cats.isEmpty && f['category_id'] != null) cats = _ids([f['category_id']]);
      _cats
        ..clear()
        ..addAll(cats);
      for (final g in _gates) {
        await _loadSubs(g);
      }
      if (mounted) setState(() => _f = f);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadSubs(int gate) async {
    if (_subs.containsKey(gate)) return;
    try {
      final subs = await AppData.fetchSubcategories(gate);
      if (mounted) setState(() => _subs[gate] = subs);
    } catch (_) {}
  }

  Future<void> _save() async {
    final f = _f;
    if (f == null) return;
    if (_gates.isEmpty) return showAppToast(context, '⚠️ ${t('add_factory.validation_gate_req', 'اختر بابًا واحدًا على الأقل')}');
    // Keep only categories that belong to a selected gate.
    final allowed = {for (final g in _gates) ...(_subs[g] ?? []).map((c) => c['id'] as int)};
    final cats = _cats.where(allowed.contains).toList();
    if (cats.isEmpty) return showAppToast(context, '⚠️ ${t('add_factory.validation_category_req', 'اختر تصنيفًا واحدًا على الأقل')}');

    final body = <String, String>{'_method': 'PUT', 'save_step': '1'};
    // Existing basic info (all translations) so nothing is lost.
    for (final l in ['ar', 'en', 'tr']) {
      for (final k in ['name', 'short_description']) {
        final v = f['${k}_$l'];
        if (v is String && v.isNotEmpty) body['${k}_$l'] = v;
      }
    }
    if ((body['name_ar'] ?? body['name_en'] ?? body['name_tr'] ?? '').isEmpty && f['name'] is String) body['name_${L10n.i.lang}'] = f['name'] as String;
    for (final k in ['nickname', 'founded_year', 'employees_count', 'status', 'country_id', 'city_id']) {
      if (f[k] != null && '${f[k]}'.isNotEmpty) body[k] = '${f[k]}';
    }
    final opps = _ids(f['opportunity_ids']).isNotEmpty ? _ids(f['opportunity_ids']) : _ids(f['opportunities']);
    var i = 0;
    for (final o in opps) {
      body['opportunity_ids[$i]'] = '$o';
      i++;
    }
    i = 0;
    for (final g in _gates) {
      body['gate_ids[$i]'] = '$g';
      i++;
    }
    i = 0;
    for (final c in cats) {
      body['category_ids[$i]'] = '$c';
      i++;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.i.postMultipart(dp('/my-factory'), fields: body);
      if (mounted) showAppToast(context, '✅ ${td('factories.factory_updated')}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: on ? AppColors.gold : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? AppColors.gold : AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (on) const Padding(padding: EdgeInsetsDirectional.only(end: 4), child: Icon(Icons.check, size: 14, color: AppColors.dark)),
            Flexible(child: Text(label, style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: AppColors.dark))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DashPage(
      title: '${t('add_factory.gates_label', 'الأبواب')} / ${t('add_factory.categories_label', 'التصنيفات')}',
      child: _f == null
          ? (_error != null ? emptyState(_error!) : emptyState('', loading: true))
          : ListView(padding: const EdgeInsets.all(14), children: [
              Text(t('add_factory.gates_label', 'الأبواب'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in AppData.doors)
                  _chip(d['name'] as String, _gates.contains(d['id']), () {
                    final id = d['id'] as int;
                    setState(() {
                      if (!_gates.remove(id)) {
                        _gates.add(id);
                      } else {
                        // Drop categories of the gate that was removed.
                        final own = (_subs[id] ?? []).map((c) => c['id'] as int).toSet();
                        _cats.removeWhere(own.contains);
                      }
                    });
                    if (_gates.contains(id)) _loadSubs(id);
                  }),
              ]),
              for (final g in _gates)
                if (AppData.doors.any((d) => d['id'] == g)) ...[
                  const SizedBox(height: 18),
                  Text('${t('add_factory.categories_label', 'التصنيفات')} · ${AppData.doors.firstWhere((d) => d['id'] == g)['name']}', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_subs[g] == null)
                    const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in _subs[g]!)
                        _chip(c['name'] as String, _cats.contains(c['id']), () => setState(() {
                              final id = c['id'] as int;
                              if (!_cats.remove(id)) _cats.add(id);
                            })),
                    ]),
                ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(td('dashboard.save'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)),
              ),
              const SizedBox(height: 20),
            ]),
    );
  }
}
