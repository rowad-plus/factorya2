import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/net_image.dart';
import '../../widgets/shell_widgets.dart';
import 'dash_kit.dart';

class _NewItem {
  final String name;
  final List<int> bytes;
  final TextEditingController title;
  final TextEditingController role = TextEditingController();
  _NewItem(this.name, this.bytes, String initialTitle) : title = TextEditingController(text: initialTitle);
}

/// My-factory steps 5 and 6: add catalog PDFs or team members, and list / delete the existing ones.
class MediaStepSection extends StatefulWidget {
  final bool team;
  final bool embedded;
  const MediaStepSection({super.key, required this.team, this.embedded = false});

  @override
  State<MediaStepSection> createState() => _MediaStepSectionState();
}

class _MediaStepSectionState extends State<MediaStepSection> {
  List<Map<String, dynamic>> _existing = [];
  final List<_NewItem> _new = [];
  String? _capability;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/my-factory'));
      final f = Map<String, dynamic>.from(r['data'] as Map);
      _existing = ApiClient.list(f[widget.team ? 'team_members' : 'catalogs']);
    } on ApiException catch (e) {
      if (e.status == 403) _capability = e.capability;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    if (widget.team) {
      final imgs = await ImagePicker().pickMultiImage(limit: 10);
      for (final i in imgs) {
        _new.add(_NewItem(i.name, await i.readAsBytes(), ''));
      }
    } else {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true, withData: true);
      for (final f in r?.files ?? <PlatformFile>[]) {
        if (f.bytes != null) _new.add(_NewItem(f.name, f.bytes!, ''));
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_new.isEmpty) return;
    setState(() => _saving = true);
    final lang = L10n.i.lang;
    try {
      final fields = <String, String>{'_method': 'PUT', 'save_step': widget.team ? '6' : '5'};
      final files = <MapEntry<String, http.MultipartFile>>[];
      for (var i = 0; i < _new.length; i++) {
        final n = _new[i];
        final field = widget.team ? 'team_images[$i]' : 'catalogs[$i]';
        files.add(MapEntry(field, http.MultipartFile.fromBytes(field, n.bytes, filename: n.name)));
        if (widget.team) {
          fields['team_names_$lang[$i]'] = n.title.text.trim();
          fields['team_roles_$lang[$i]'] = n.role.text.trim();
        } else {
          fields['catalog_names_$lang[$i]'] = n.title.text.trim();
        }
      }
      await ApiClient.i.postMultipart(dp('/my-factory'), fields: fields, files: files);
      if (mounted) {
        showAppToast(context, '✅ ${td('factories.factory_updated')}');
        setState(() => _new.clear());
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    try {
      await ApiClient.i.delete(dp(widget.team ? '/factories/team-member/${it['id']}' : '/factories/catalog/${it['id']}'));
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _capability != null
            ? UpgradeNotice(capability: _capability)
            : _loading
                ? emptyState('', loading: true)
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final e in _existing)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          if (widget.team)
                            Container(width: 46, height: 46, margin: const EdgeInsetsDirectional.only(end: 10), clipBehavior: Clip.antiAlias, decoration: const BoxDecoration(shape: BoxShape.circle), child: NetImage(url: '${e['image_url'] ?? ''}', fallback: '👤', width: 46, height: 46))
                          else
                            const Padding(padding: EdgeInsetsDirectional.only(end: 10), child: Icon(Icons.picture_as_pdf_outlined, color: AppColors.gold)),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(AppData.tr(e, 'name'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
                              if (widget.team) Text(AppData.tr(e, 'role'), style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted)),
                            ]),
                          ),
                          IconButton(onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline, color: AppColors.red)),
                        ]),
                      ),
                    if (_existing.isEmpty && _new.isEmpty) emptyState(widget.team ? t('factory_profile.no_team', '') : t('factory_profile.no_catalogs', '')),
                    for (final n in _new)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.gold3, borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          if (!widget.team) Align(alignment: AlignmentDirectional.centerStart, child: Text(n.name, style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.muted))),
                          TextField(controller: n.title, decoration: InputDecoration(labelText: td('factories.name'))),
                          if (widget.team) TextField(controller: n.role, decoration: InputDecoration(labelText: td('factories.role'))),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.add, color: AppColors.gold), label: Text(widget.team ? td('factories.add_team_member') : td('factories.add_pdf'), style: GoogleFonts.tajawal(color: AppColors.text))),
                    if (_new.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(td('dashboard.save'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
                    ],
                  ]);
    return widget.embedded ? body : DashPage(title: widget.team ? td('factories.team') : td('factories.catalog'), child: body);
  }
}
