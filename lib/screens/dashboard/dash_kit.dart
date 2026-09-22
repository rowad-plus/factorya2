import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/rich_text_field.dart';
import '../../widgets/net_image.dart';
import '../../widgets/shell_widgets.dart';

/// Base path of the factory dashboard API.
String dp(String path) => '/factory-dashboard$path';

/// Shown when the API answers 403 because the factory's package lacks a feature.
class UpgradeNotice extends StatelessWidget {
  final String? capability;
  const UpgradeNotice({super.key, this.capability});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 46, color: AppColors.gold),
            const SizedBox(height: 10),
            Text(td('dashboard.package_upgrade_required_title'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(td('dashboard.package_upgrade_required_body', {'feature': capability ?? ''}), textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted, height: 1.7)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => context.push('/subscription'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: Text(td('dashboard.upgrade_package_cta'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
            ),
          ]),
        ),
      );
}

/// Page frame with a back arrow and title (dashboard sub-pages).
class DashPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? fab;
  const DashPage({super.key, required this.title, required this.child, this.actions = const [], this.fab});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: fab,
        body: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(L10n.i.isRtl ? Icons.arrow_forward : Icons.arrow_back, size: 20)),
              Expanded(child: Text(title, style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800))),
              ...actions,
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ]),
      );
}

enum FT { text, multiline, number, email, url, date, select, country, image, images, video, bool, lines, richtext }

class DField {
  final String key;
  final String label;
  final FT type;
  final bool required;
  final bool translated;
  final List<(String, String)> options;
  final String? hint;
  final String? fileField;
  final int? maxLength;
  const DField(this.key, this.label, {this.type = FT.text, this.required = false, this.translated = false, this.options = const [], this.hint, this.fileField, this.maxLength});
}

const statusOptions = [('active', 'active'), ('inactive', 'inactive')];

/// Generic create / edit form. Sends JSON, or multipart (with `_method=PUT` for updates) when files are picked.
class DashForm extends StatefulWidget {
  final String title;
  final String path; // collection path e.g. /products
  final Map<String, dynamic>? item;
  final List<DField> fields;
  final String savedMessage;
  /// Singleton resources (`/my-factory`, `/seo`): PUT to [path] itself, no id.
  final bool single;
  /// Extra fixed fields (for example `save_step`).
  final Map<String, String> extra;
  /// Always send multipart (needed for array fields such as `gate_ids[0]`).
  final bool multipart;
  /// Tab mode: no page chrome, and [onSaved] is called instead of closing the page.
  final bool embedded;
  final VoidCallback? onSaved;
  const DashForm({super.key, required this.title, required this.path, required this.fields, this.item, required this.savedMessage, this.single = false, this.extra = const {}, this.multipart = false, this.embedded = false, this.onSaved});

  @override
  State<DashForm> createState() => _DashFormState();
}

class _DashFormState extends State<DashForm> {
  final Map<String, TextEditingController> _c = {};
  final Map<String, dynamic> _v = {};
  final Map<String, List<XFile>> _files = {};
  final Map<String, List<TextEditingController>> _lines = {};
  List<Map<String, dynamic>> _cities = [];
  bool _busy = false;

  bool get _edit => widget.item != null || widget.single;

  @override
  void initState() {
    super.initState();
    final it = widget.item ?? {};
    for (final f in widget.fields) {
      switch (f.type) {
        case FT.image:
        case FT.images:
        case FT.video:
          break;
        case FT.select:
          _v[f.key] = it[f.key] == null ? (f.options.isNotEmpty && !_edit ? f.options.first.$1 : null) : '${it[f.key]}';
        case FT.bool:
          _v[f.key] = it[f.key] == true || it[f.key] == 1;
        case FT.country:
          _v['country_id'] = it['country_id'] ?? AppData.countryId;
          _v['city_id'] = it['city_id'];
          _loadCities();
        case FT.lines:
          var raw = it[f.key] ?? it['${f.key}_${L10n.i.lang}'];
          final rows = raw is List ? raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() : <String>[];
          final count = rows.length < 4 ? 4 : rows.length;
          _lines[f.key] = [for (var i = 0; i < count; i++) TextEditingController(text: i < rows.length ? rows[i] : '')];
        default:
          var val = it[f.key];
          if (f.translated) val ??= it['${f.key}_${L10n.i.lang}'];
          if (val is List) val = val.map((e) => '$e').join('\n');
          _c[f.key] = TextEditingController(text: val == null ? '' : '$val');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final l in _lines.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadCities() async {
    final id = _v['country_id'];
    if (id == null) return;
    try {
      final r = await ApiClient.i.get('/countries/$id/cities', query: {'per_page': 100});
      if (mounted) setState(() => _cities = ApiClient.list(r['data']));
    } catch (_) {}
  }

  Future<void> _pick(DField f) async {
    final picker = ImagePicker();
    if (f.type == FT.video) {
      final v = await picker.pickVideo(source: ImageSource.gallery);
      if (v != null) setState(() => _files[f.key] = [v]);
    } else if (f.type == FT.images) {
      final imgs = await picker.pickMultiImage(limit: 10);
      if (imgs.isNotEmpty) setState(() => _files[f.key] = imgs);
    } else {
      final i = await picker.pickImage(source: ImageSource.gallery);
      if (i != null) setState(() => _files[f.key] = [i]);
    }
  }

  Future<void> _save() async {
    final body = <String, String>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case FT.image:
        case FT.images:
        case FT.video:
          if (f.required && !_edit && (_files[f.key] ?? []).isEmpty) return showAppToast(context, '⚠️ ${f.label}');
        case FT.select:
          if (_v[f.key] != null) body[f.key] = '${_v[f.key]}';
        case FT.bool:
          body[f.key] = _v[f.key] == true ? '1' : '0';
        case FT.country:
          if (_v['country_id'] == null || _v['city_id'] == null) return showAppToast(context, '⚠️ ${td('clients.select_country')}');
          body['country_id'] = '${_v['country_id']}';
          body['city_id'] = '${_v['city_id']}';
        case FT.lines:
          final rows = (_lines[f.key] ?? []).map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();
          if (f.required && rows.isEmpty) return showAppToast(context, '⚠️ ${f.label}');
          for (var i = 0; i < rows.length; i++) {
            body['${f.key}_${L10n.i.lang}[$i]'] = rows[i];
          }
        default:
          final txt = _c[f.key]!.text.trim();
          if (f.required && txt.isEmpty) return showAppToast(context, '⚠️ ${f.label}');
          if (txt.isNotEmpty) body[f.translated ? '${f.key}_${L10n.i.lang}' : f.key] = txt;
      }
    }
    body.addAll(widget.extra);
    setState(() => _busy = true);
    try {
      final hasFiles = widget.multipart || _files.values.any((l) => l.isNotEmpty);
      final id = widget.item?['id'];
      final target = widget.single ? widget.path : (_edit ? '${widget.path}/$id' : widget.path);
      if (hasFiles) {
        final files = <MapEntry<String, http.MultipartFile>>[];
        for (final f in widget.fields) {
          for (final x in _files[f.key] ?? <XFile>[]) {
            final field = f.type == FT.images ? '${f.fileField ?? f.key}[]' : (f.fileField ?? f.key);
            files.add(MapEntry(field, http.MultipartFile.fromBytes(field, await x.readAsBytes(), filename: x.name)));
          }
        }
        if (_edit) body['_method'] = 'PUT';
        await ApiClient.i.postMultipart(dp(target), fields: body, files: files);
      } else if (_edit) {
        await ApiClient.i.put(dp(target), body: body);
      } else {
        await ApiClient.i.post(dp(widget.path), body: body);
      }
      if (!mounted) return;
      showAppToast(context, '✅ ${widget.savedMessage}');
      if (widget.embedded) {
        widget.onSaved?.call();
      } else {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.tajawal(fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _field(DField f) {
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.type) {
      case FT.select:
        return DropdownButtonFormField<String>(initialValue: _v[f.key] as String?, isExpanded: true, decoration: _dec(label), items: [for (final o in f.options) DropdownMenuItem(value: o.$1, child: Text(o.$2.contains('.') ? td(o.$2) : o.$2, style: GoogleFonts.tajawal(fontSize: 13)))], onChanged: (v) => setState(() => _v[f.key] = v));
      case FT.richtext:
        return RichTextField(controller: _c[f.key]!, label: f.required ? '${f.label} *' : f.label);
      case FT.lines:
        final rows = _lines[f.key] ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.required ? '${f.label} *' : f.label, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                if (i > 0)
                  IconButton(
                    onPressed: () => setState(() {
                      rows.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.cancel, color: AppColors.muted, size: 22),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(child: TextField(controller: rows[i], decoration: _dec('${td('factories.activity')} ${i + 1}').copyWith(hintText: td('factories.activity_placeholder')))),
              ]),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => rows.add(TextEditingController())),
              child: Text(td('factories.add_activity'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ),
          ),
        ]);
      case FT.bool:
        return SwitchListTile(value: _v[f.key] == true, onChanged: (v) => setState(() => _v[f.key] = v), title: Text(f.label, style: GoogleFonts.tajawal(fontSize: 13.5)), activeThumbColor: AppColors.gold, contentPadding: EdgeInsets.zero);
      case FT.country:
        return Column(children: [
          DropdownButtonFormField<int>(
            initialValue: _v['country_id'] as int?,
            isExpanded: true,
            decoration: _dec('${td('clients.country')} *'),
            items: [for (final c in AppData.countries) DropdownMenuItem(value: c['id'] as int, child: Text(AppData.tr(c, 'name'), style: GoogleFonts.tajawal(fontSize: 13)))],
            onChanged: (v) {
              setState(() {
                _v['country_id'] = v;
                _v['city_id'] = null;
                _cities = [];
              });
              _loadCities();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _cities.any((c) => c['id'] == _v['city_id']) ? _v['city_id'] as int? : null,
            isExpanded: true,
            decoration: _dec('${td('branches.city')} *'),
            items: [for (final c in _cities) DropdownMenuItem(value: c['id'] as int, child: Text(AppData.tr(c, 'name'), style: GoogleFonts.tajawal(fontSize: 13)))],
            onChanged: (v) => setState(() => _v['city_id'] = v),
          ),
        ]);
      case FT.image:
      case FT.images:
      case FT.video:
        final picked = _files[f.key] ?? [];
        return OutlinedButton.icon(
          onPressed: () => _pick(f),
          icon: Icon(f.type == FT.video ? Icons.videocam_outlined : Icons.image_outlined, color: AppColors.gold),
          label: Align(alignment: AlignmentDirectional.centerStart, child: Text(picked.isEmpty ? label : (f.type == FT.images ? '✓ $label (${picked.length})' : '✓ $label'), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(color: AppColors.text))),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      case FT.date:
        return TextField(
          controller: _c[f.key],
          readOnly: true,
          decoration: _dec(label),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime(2100));
            if (d != null) _c[f.key]!.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          },
        );
      default:
        return TextField(
          controller: _c[f.key],
          minLines: f.type == FT.multiline ? (f.key == 'about' ? 8 : 3) : 1,
          maxLines: f.type == FT.multiline ? (f.key == 'about' ? 14 : 6) : 1,
          maxLength: f.maxLength,
          keyboardType: f.type == FT.number ? TextInputType.number : (f.type == FT.email ? TextInputType.emailAddress : (f.type == FT.url ? TextInputType.url : null)),
          textDirection: f.type == FT.email || f.type == FT.url ? TextDirection.ltr : null,
          decoration: _dec(label).copyWith(helperText: f.hint),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(td('dashboard.save'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark)),
          ),
          const SizedBox(height: 20),
        ],
      );
    return widget.embedded ? list : DashPage(title: widget.title, child: list);
  }
}

/// Generic paginated list with create / edit / delete / toggle-status.
class DashList extends StatefulWidget {
  final String title;
  final String path;
  final List<DField>? fields; // null → read-only list
  final String emptyText;
  final String addLabel;
  final String editLabel;
  final String confirmDelete;
  final String savedMessage;
  final String deletedMessage;
  final bool toggle;
  final bool searchable;
  final String? statusFilterKey;
  final Map<String, dynamic> extraQuery;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>)? subtitleOf;
  final String? Function(Map<String, dynamic>)? imageOf;
  final String? Function(Map<String, dynamic>)? statusOf;
  final void Function(BuildContext, Map<String, dynamic>)? onOpen;

  const DashList({
    super.key,
    required this.title,
    required this.path,
    required this.emptyText,
    required this.titleOf,
    this.fields,
    this.addLabel = '',
    this.editLabel = '',
    this.confirmDelete = '',
    this.savedMessage = '',
    this.deletedMessage = '',
    this.toggle = false,
    this.searchable = true,
    this.statusFilterKey,
    this.extraQuery = const {},
    this.subtitleOf,
    this.imageOf,
    this.statusOf,
    this.onOpen,
  });

  @override
  State<DashList> createState() => _DashListState();
}

class _DashListState extends State<DashList> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _last = 1;
  bool _loading = false;
  String _search = '';
  String? _capability;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    _reset();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() {
      _items.clear();
      _page = 0;
      _last = 1;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    try {
      final res = await ApiClient.i.get(dp(widget.path), query: {'page': _page + 1, 'per_page': 20, 'search': _search, ...widget.extraQuery});
      final meta = res['meta'];
      if (!mounted) return;
      setState(() {
        _items.addAll(ApiClient.list(res['data']));
        _page++;
        if (meta is Map) _last = (meta['last_page'] as num?)?.toInt() ?? 1;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if (e.status == 403 && e.capability != null) {
            _capability = e.capability;
          } else {
            _error = e.message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _form([Map<String, dynamic>? item]) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DashForm(title: item == null ? widget.addLabel : widget.editLabel, path: widget.path, item: item, fields: widget.fields!, savedMessage: widget.savedMessage)));
    if (ok == true) _reset();
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(widget.confirmDelete, style: GoogleFonts.tajawal()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(td('products.cancel'), style: GoogleFonts.tajawal())),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(td('products.delete'), style: GoogleFonts.tajawal(color: AppColors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ApiClient.i.delete(dp('${widget.path}/${it['id']}'));
      if (mounted) showAppToast(context, '✅ ${widget.deletedMessage}');
      _reset();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    }
  }

  Future<void> _toggle(Map<String, dynamic> it) async {
    try {
      await ApiClient.i.patch(dp('${widget.path}/${it['id']}/toggle-status'));
      _reset();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashPage(
      title: widget.title,
      fab: widget.fields == null ? null : FloatingActionButton(backgroundColor: AppColors.gold, onPressed: () => _form(), child: const Icon(Icons.add, color: AppColors.dark)),
      child: _capability != null
          ? UpgradeNotice(capability: _capability)
          : Column(children: [
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: TextField(
                    onSubmitted: (q) {
                      _search = q.trim();
                      _reset();
                    },
                    decoration: InputDecoration(hintText: td('dashboard.search'), prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border))),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.gold,
                  onRefresh: _reset,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_items.isEmpty && !_loading) emptyState(_error ?? widget.emptyText),
                      for (final it in _items) _card(it),
                      if (_loading) emptyState('', loading: true),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _card(Map<String, dynamic> it) {
    final img = widget.imageOf?.call(it);
    final status = widget.statusOf?.call(it);
    final active = status == null ? null : (status == 'active' || status == 'true');
    return GestureDetector(
      onTap: widget.onOpen == null ? null : () => widget.onOpen!(context, it),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (img != null)
            Container(width: 60, height: 60, margin: const EdgeInsetsDirectional.only(end: 12), clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.bg), child: NetImage(url: img, fallback: '🖼️', fallbackSize: 22, width: 60, height: 60)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.titleOf(it), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w800)),
              if (widget.subtitleOf != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(widget.subtitleOf!(it), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.muted, height: 1.5))),
              if (widget.fields != null || widget.toggle)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(spacing: 4, children: [
                    if (widget.fields != null) _act(Icons.edit_outlined, () => _form(it), AppColors.gold),
                    if (widget.toggle) _act(active == true ? Icons.toggle_on : Icons.toggle_off_outlined, () => _toggle(it), active == true ? AppColors.green : AppColors.muted),
                    if (widget.fields != null) _act(Icons.delete_outline, () => _delete(it), AppColors.red),
                  ]),
                ),
            ]),
          ),
          if (active != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (active ? AppColors.green : AppColors.muted).withAlpha(30), borderRadius: BorderRadius.circular(20)), child: Text(active ? td('products.active') : td('products.inactive'), style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: active ? AppColors.green : AppColors.muted))),
        ]),
      ),
    );
  }

  Widget _act(IconData icon, VoidCallback onTap, Color color) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 22, color: color)));
}
