import 'dart:async';
import 'dart:io' show File;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/chat_ad.dart';
import '../../widgets/net_image.dart';
import '../auth/login_modal.dart';
import '../opportunities/opportunities_screen.dart' show tri;

enum _Status { sent, sending, failed }

/// One chat bubble: a server message, or a local one still being uploaded.
class _Msg {
  int? id;
  final String localId;
  String text;
  String type; // text | image | audio | file
  String? url;
  String? name;
  String? mime;
  int? size;
  int? duration;
  bool mine;
  bool read;
  DateTime time;
  _Status status;
  Uint8List? bytes; // local preview while uploading
  _Send? retry;

  _Msg({this.id, required this.localId, this.text = '', this.type = 'text', this.url, this.name, this.mime, this.size, this.duration, required this.mine, this.read = false, required this.time, this.status = _Status.sent, this.bytes, this.retry});
}

class _Send {
  final String text;
  final String type;
  final List<int>? bytes;
  final String? filename;
  final int? duration;
  const _Send({this.text = '', this.type = 'text', this.bytes, this.filename, this.duration});
}

class ChatScreen extends StatefulWidget {
  final String factoryId;
  final String name;
  final String avatar;
  final Color color;
  final String? logo;

  const ChatScreen({super.key, required this.factoryId, required this.name, required this.avatar, required this.color, this.logo});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _perPage = 30;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<_Msg> _msgs = [];
  bool _loading = true;
  bool _hasText = false;
  bool _loadingOlder = false;
  int _firstPage = 1;
  int _lastPage = 1;
  Timer? _poll;
  bool _polling = false;

  // voice
  final _recorder = AudioRecorder();
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTicker;
  DateTime? _recStart;

  String get _path => '/factories/${widget.factoryId}/chat';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    if (AuthService.i.isLoggedIn && '${AuthService.i.user?['account_type']}' != 'factory') {
      _load(initial: true);
      _startPolling();
    } else {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _recTicker?.cancel();
    _recorder.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ───────────────────────── data ─────────────────────────

  _Msg _fromJson(Map<String, dynamic> m) {
    final me = AuthService.i.userId;
    return _Msg(
      id: m['id'] as int?,
      localId: 's${m['id']}',
      text: (m['message'] as String?) ?? '',
      type: (m['type'] as String?) ?? 'text',
      url: m['attachment_url'] as String?,
      name: m['attachment_name'] as String?,
      mime: m['attachment_mime'] as String?,
      size: (m['attachment_size'] as num?)?.toInt(),
      duration: (m['duration'] as num?)?.toInt(),
      mine: m['sender_id'] == me,
      read: m['is_read'] == true,
      time: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }

  Future<Map<String, dynamic>> _fetchPage(int page) => ApiClient.i.get('$_path/messages', query: {'per_page': _perPage, 'page': page});

  int _metaLast(Map<String, dynamic> res) {
    final meta = res['meta'];
    if (meta is Map) {
      final v = meta['last_page'] ?? (meta['pagination'] is Map ? (meta['pagination'] as Map)['last_page'] : null);
      if (v is num) return v.toInt();
    }
    return 1;
  }

  /// Merge server rows into the list (by id), keeping local pending / failed bubbles at the end.
  void _merge(List<Map<String, dynamic>> rows) {
    final byId = {for (final m in _msgs.where((m) => m.id != null)) m.id!: m};
    for (final r in rows) {
      final n = _fromJson(r);
      final old = byId[n.id];
      if (old != null) {
        old.read = n.read;
        old.url = n.url ?? old.url;
      } else {
        byId[n.id!] = n;
      }
    }
    final pending = _msgs.where((m) => m.id == null).toList();
    final server = byId.values.toList()..sort((a, b) => a.id!.compareTo(b.id!));
    _msgs
      ..clear()
      ..addAll(server)
      ..addAll(pending);
  }

  Future<void> _load({bool initial = false}) async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      var res = await _fetchPage(initial ? 1 : _lastPage);
      final last = _metaLast(res);
      if (initial && last > 1) {
        res = await _fetchPage(last);
      } else if (!initial && last > _lastPage) {
        // A new page appeared: fetch it and remember it.
        res = await _fetchPage(last);
      }
      final rows = ApiClient.list(res['data']);
      final me = AuthService.i.userId;
      if (!mounted) return;
      final before = _msgs.where((m) => m.id != null).length;
      final nearBottom = !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.position.pixels < 160;
      final incoming = rows.any((m) => m['sender_id'] != me && !_msgs.any((x) => x.id == m['id']));
      setState(() {
        _lastPage = last;
        if (initial) _firstPage = last;
        _merge(rows);
        _loading = false;
      });
      final after = _msgs.where((m) => m.id != null).length;
      if (initial || (after != before && (nearBottom || !incoming))) _scrollToEnd(jump: initial);
      if (rows.any((m) => m['sender_id'] != me && m['is_read'] == false)) {
        ApiClient.i.patch('$_path/messages/read').then((_) => AppData.loadUserData()).catchError((_) => <String, dynamic>{});
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (initial) showAppToast(context, '⚠️ ${e.message}');
      }
    } finally {
      _polling = false;
    }
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels < 60 && _firstPage > 1 && !_loadingOlder) _loadOlder();
  }

  Future<void> _loadOlder() async {
    _loadingOlder = true;
    try {
      final res = await _fetchPage(_firstPage - 1);
      final oldMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
      if (!mounted) return;
      setState(() {
        _firstPage -= 1;
        _merge(ApiClient.list(res['data']));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.pixels + (_scroll.position.maxScrollExtent - oldMax));
      });
    } catch (_) {} finally {
      _loadingOlder = false;
    }
  }

  void _scrollToEnd({bool jump = false}) {
    Future.delayed(Duration(milliseconds: jump ? 30 : 120), () {
      if (!_scroll.hasClients) return;
      if (jump) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ───────────────────────── sending ─────────────────────────

  bool _ensureLogin() {
    if (AuthService.i.isLoggedIn) return true;
    LoginModal.show(context);
    return false;
  }

  Future<void> _dispatch(_Send s) async {
    final local = _Msg(
      localId: 'l${DateTime.now().microsecondsSinceEpoch}',
      text: s.text,
      type: s.type,
      name: s.filename,
      size: s.bytes?.length,
      duration: s.duration,
      mine: true,
      time: DateTime.now(),
      status: _Status.sending,
      bytes: s.type == 'image' && s.bytes != null ? Uint8List.fromList(s.bytes!) : null,
      retry: s,
    );
    setState(() => _msgs.add(local));
    _scrollToEnd();
    await _transmit(local);
  }

  Future<void> _transmit(_Msg local) async {
    final s = local.retry!;
    setState(() => local.status = _Status.sending);
    try {
      final fields = <String, String>{'type': s.type, if (s.text.isNotEmpty) 'message': s.text, if (s.duration != null) 'duration': '${s.duration}'};
      final files = <MapEntry<String, http.MultipartFile>>[];
      if (s.bytes != null) files.add(MapEntry('attachment', http.MultipartFile.fromBytes('attachment', s.bytes!, filename: s.filename ?? 'file')));
      final res = s.bytes == null && s.type == 'text'
          ? await ApiClient.i.post('$_path/messages', body: {'message': s.text})
          : await ApiClient.i.postMultipart('$_path/messages', fields: fields, files: files);
      final data = res['data'];
      if (!mounted) return;
      setState(() {
        if (data is Map) {
          final real = _fromJson(Map<String, dynamic>.from(data));
          if (_msgs.any((m) => m.id == real.id)) {
            _msgs.remove(local);
          } else {
            local
              ..id = real.id
              ..url = real.url
              ..name = real.name ?? local.name
              ..mime = real.mime
              ..text = real.text
              ..time = real.time
              ..status = _Status.sent
              ..retry = null;
          }
        }
      });
      AppData.loadUserData();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => local.status = _Status.failed);
        showAppToast(context, '⚠️ ${e.message}');
      }
    } catch (_) {
      if (mounted) setState(() => local.status = _Status.failed);
    }
  }

  Future<void> _sendText() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || !_ensureLogin()) return;
    _ctrl.clear();
    await _dispatch(_Send(text: txt));
  }

  Future<void> _pickImage(ImageSource src) async {
    if (!_ensureLogin()) return;
    try {
      final img = await ImagePicker().pickImage(source: src, imageQuality: 82, maxWidth: 1800);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      await _dispatch(_Send(type: 'image', bytes: bytes, filename: img.name.isEmpty ? 'photo.jpg' : img.name));
    } catch (_) {
      if (mounted) showAppToast(context, '⚠️ ${tri('تعذّر اختيار الصورة', 'Görsel seçilemedi', 'Could not pick the image')}');
    }
  }

  Future<void> _pickDocument() async {
    if (!_ensureLogin()) return;
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'zip', 'rar'],
      withData: true,
    );
    final f = r?.files.first;
    if (f == null || f.bytes == null) return;
    if (f.size > 20 * 1024 * 1024) {
      if (mounted) showAppToast(context, '⚠️ ${tri('الحد الأقصى للملف 20 ميجا', 'Dosya en fazla 20 MB olabilir', 'Max file size is 20 MB')}');
      return;
    }
    await _dispatch(_Send(type: 'file', bytes: f.bytes, filename: f.name));
  }

  void _attachSheet() {
    if (!_ensureLogin()) return;
    Widget tile(IconData icon, Color color, String label, VoidCallback onTap) => InkWell(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle), child: Icon(icon, color: color, size: 26)),
              const SizedBox(height: 6),
              Text(label, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            tile(Icons.photo_library_outlined, const Color(0xFF7E57C2), tri('المعرض', 'Galeri', 'Gallery'), () => _pickImage(ImageSource.gallery)),
            if (!kIsWeb) tile(Icons.photo_camera_outlined, const Color(0xFFEC407A), tri('الكاميرا', 'Kamera', 'Camera'), () => _pickImage(ImageSource.camera)),
            tile(Icons.insert_drive_file_outlined, const Color(0xFF29B6F6), tri('مستند', 'Belge', 'Document'), _pickDocument),
          ]),
        ),
      ),
    );
  }

  // ───────────────────────── voice ─────────────────────────

  Future<void> _startRecording() async {
    if (!_ensureLogin()) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) showAppToast(context, '⚠️ ${tri('اسمح للتطبيق باستخدام الميكروفون', 'Mikrofon izni gerekli', 'Microphone permission is required')}');
        return;
      }
      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: path);
      _recStart = DateTime.now();
      _recSeconds = 0;
      _recTicker?.cancel();
      _recTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds = DateTime.now().difference(_recStart!).inSeconds);
      });
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) showAppToast(context, '⚠️ ${tri('تعذّر بدء التسجيل', 'Kayıt başlatılamadı', 'Could not start recording')}');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTicker?.cancel();
    final secs = _recStart == null ? 0 : DateTime.now().difference(_recStart!).inSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    if (path == null || !send) {
      if (path != null && !kIsWeb) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }
    if (secs < 1) {
      if (mounted) showAppToast(context, tri('التسجيل قصير جداً', 'Kayıt çok kısa', 'Recording is too short'));
      return;
    }
    try {
      final bytes = await XFile(path).readAsBytes();
      await _dispatch(_Send(type: 'audio', bytes: bytes, filename: kIsWeb ? 'voice.webm' : 'voice.m4a', duration: secs));
      if (!kIsWeb) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) showAppToast(context, '⚠️ ${tri('تعذّر إرسال التسجيل', 'Kayıt gönderilemedi', 'Could not send the recording')}');
    }
  }

  // ───────────────────────── UI ─────────────────────────

  /// The server only lets visitor ("user") accounts start chats with a factory.
  bool get _factoryAccount => AuthService.i.isLoggedIn && '${AuthService.i.user?['account_type']}' == 'factory';

  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return tri('اليوم', 'Bugün', 'Today');
    if (diff == 1) return tri('أمس', 'Dün', 'Yesterday');
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _size(int? b) {
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String? name) {
    final ext = (name ?? '').split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx', 'txt'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_outlined;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow_outlined;
    if (['zip', 'rar'].contains(ext)) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  void _openImage(_Msg m) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: m.url != null ? Image.network(m.url!, fit: BoxFit.contain) : Image.memory(m.bytes!, fit: BoxFit.contain),
            ),
          ),
          SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)))),
        ]),
      ),
    );
  }

  Future<void> _openFile(_Msg m) async {
    final uri = m.url == null ? null : Uri.tryParse(m.url!);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _bubbleBody(_Msg m) {
    final fg = m.mine ? Colors.white : AppColors.text;
    switch (m.type) {
      case 'image':
        return GestureDetector(
          onTap: () => _openImage(m),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230, maxHeight: 280, minWidth: 140, minHeight: 100),
              child: m.url != null
                  ? Image.network(m.url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 160, height: 120, child: Icon(Icons.broken_image_outlined)))
                  : (m.bytes != null ? Image.memory(m.bytes!, fit: BoxFit.cover) : const SizedBox(width: 160, height: 120)),
            ),
          ),
        );
      case 'audio':
        return _VoiceBubble(key: ValueKey(m.localId), url: m.url, bytes: m.bytes, seconds: m.duration ?? 0, mine: m.mine);
      case 'file':
        return GestureDetector(
          onTap: () => _openFile(m),
          child: SizedBox(
            width: 220,
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: (m.mine ? Colors.white : AppColors.gold).withAlpha(m.mine ? 50 : 40), borderRadius: BorderRadius.circular(10)), child: Icon(_fileIcon(m.name), color: m.mine ? Colors.white : AppColors.gold)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                  Text(_size(m.size), style: GoogleFonts.tajawal(fontSize: 11, color: fg.withAlpha(180))),
                ]),
              ),
            ]),
          ),
        );
      default:
        return SelectableText(m.text, style: GoogleFonts.tajawal(fontSize: 14, color: fg, height: 1.55));
    }
  }

  Widget _bubble(_Msg m) {
    final mine = m.mine;
    final media = m.type == 'image';
    final fg = mine ? Colors.white : AppColors.text;
    Widget ticks() {
      if (!mine) return const SizedBox.shrink();
      if (m.status == _Status.sending) return Icon(Icons.access_time, size: 12, color: fg.withAlpha(180));
      if (m.status == _Status.failed) return const Icon(Icons.error_outline, size: 13, color: Color(0xFFFFCDD2));
      return Icon(m.read ? Icons.done_all : Icons.done, size: 14, color: m.read ? const Color(0xFF8CF0FF) : fg.withAlpha(190));
    }

    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onTap: m.status == _Status.failed ? () => _transmit(m) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: media ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(12, 9, 12, 6),
          decoration: BoxDecoration(
            color: mine ? AppColors.gold : Colors.white,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(16),
              topEnd: const Radius.circular(16),
              bottomStart: Radius.circular(mine ? 4 : 16),
              bottomEnd: Radius.circular(mine ? 16 : 4),
            ),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _bubbleBody(m),
              const SizedBox(height: 3),
              Padding(
                padding: media ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.zero,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (m.status == _Status.failed) Text('${tri('فشل - اضغط لإعادة المحاولة', 'Hata - tekrar dene', 'Failed - tap to retry')}  ', style: GoogleFonts.tajawal(fontSize: 10.5, color: const Color(0xFFFFCDD2))),
                  Text(_clock(m.time), style: GoogleFonts.tajawal(fontSize: 10, color: fg.withAlpha(mine ? 200 : 140))),
                  const SizedBox(width: 4),
                  ticks(),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageList() {
    final children = <Widget>[];
    DateTime? lastDay;
    for (final m in _msgs) {
      final day = DateTime(m.time.year, m.time.month, m.time.day);
      if (lastDay != day) {
        lastDay = day;
        children.add(Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFE8EAED), borderRadius: BorderRadius.circular(10)),
            child: Text(_dayLabel(m.time), style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
        ));
      }
      children.add(_bubble(m));
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        if (_firstPage > 1) const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)))),
        ...children,
      ],
    );
  }

  Widget _composer() {
    if (_recording) {
      return Row(children: [
        IconButton(onPressed: () => _stopRecording(send: false), icon: const Icon(Icons.delete_outline, color: AppColors.red)),
        const SizedBox(width: 4),
        const _BlinkDot(),
        const SizedBox(width: 8),
        Text(_mmss(_recSeconds), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(child: Text(tri('جارٍ التسجيل...', 'Kaydediliyor...', 'Recording...'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted))),
        _roundBtn(Icons.send_rounded, () => _stopRecording(send: true)),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      IconButton(onPressed: _attachSheet, icon: const Icon(Icons.attach_file, color: AppColors.muted)),
      Expanded(
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          minLines: 1,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: tri('اكتب رسالتك...', 'Mesajını yaz...', 'Type a message...'),
            hintStyle: GoogleFonts.tajawal(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.gold, width: 1.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 8),
      _hasText ? _roundBtn(Icons.send_rounded, _sendText) : _roundBtn(Icons.mic, _startRecording),
    ]);
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 21)),
      );

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: const Color(0xFFF0EFEA),
      body: Column(
        children: [
          Container(
            color: AppColors.dark,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(rtl ? Icons.arrow_forward : Icons.arrow_back, color: Colors.white)),
                  Container(
                    width: 40, height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(76))),
                    child: (widget.logo != null && widget.logo!.isNotEmpty)
                        ? NetImage(url: widget.logo, brandFallback: true, fallbackSize: 10, width: 40, height: 40)
                        : Center(child: Text(widget.avatar.isNotEmpty ? String.fromCharCode(widget.avatar.runes.first) : '?', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
                ]),
              ),
            ),
          ),
          if (!_factoryAccount) ChatAd(factoryId: widget.factoryId),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _factoryAccount
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.lock_outline, size: 40, color: AppColors.gold),
                            const SizedBox(height: 12),
                            Text(
                              tri('محادثات الزوّار متاحة لحسابات المستخدمين فقط. حساب المصنع يستقبل الرسائل ويردّ عليها من لوحة التحكم ← الرسائل.', 'Sohbet yalnızca kullanıcı hesapları içindir. Fabrika hesabı mesajları panelden yanıtlar.', 'Starting a chat is available to visitor accounts only. A factory account receives and answers messages from the dashboard → Messages.'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(fontSize: 13.5, color: AppColors.muted, height: 1.8),
                            ),
                          ]),
                        ),
                      )
                    : !AuthService.i.isLoggedIn
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(tri('سجّل الدخول لبدء المحادثة', 'Sohbet için giriş yap', 'Sign in to start chatting'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => LoginModal.show(context),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                            child: Text(tri('تسجيل الدخول', 'Giriş yap', 'Sign in'), style: GoogleFonts.tajawal(color: AppColors.dark, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      )
                    : _msgs.isEmpty
                        ? Center(child: Text(tri('ابدأ المحادثة بإرسال رسالة', 'Bir mesaj göndererek başla', 'Start the conversation'), style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)))
                        : _messageList(),
          ),
          Container(
            color: Colors.white,
            child: _factoryAccount ? const SizedBox.shrink() : SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(6, 8, 10, 8), child: _composer())),
          ),
        ],
      ),
    );
  }
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _c, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)));
}

/// Play / pause + progress for a voice note (server URL, or local bytes while uploading).
class _VoiceBubble extends StatefulWidget {
  final String? url;
  final Uint8List? bytes;
  final int seconds;
  final bool mine;
  const _VoiceBubble({super.key, this.url, this.bytes, required this.seconds, required this.mine});

  static AudioPlayer? current;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  AudioPlayer? _player;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration? _dur;
  final List<StreamSubscription> _subs = [];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    if (_VoiceBubble.current == _player) _VoiceBubble.current = null;
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.url == null) return;
    if (_player == null) {
      final p = AudioPlayer();
      _player = p;
      _subs.add(p.onPositionChanged.listen((d) => mounted ? setState(() => _pos = d) : null));
      _subs.add(p.onDurationChanged.listen((d) => mounted ? setState(() => _dur = d) : null));
      _subs.add(p.onPlayerStateChanged.listen((s) {
        if (!mounted) return;
        setState(() {
          _playing = s == PlayerState.playing;
          if (s == PlayerState.completed) _pos = Duration.zero;
        });
      }));
    }
    final p = _player!;
    if (_playing) {
      await p.pause();
      return;
    }
    if (_VoiceBubble.current != null && _VoiceBubble.current != p) await _VoiceBubble.current!.pause();
    _VoiceBubble.current = p;
    if (p.state == PlayerState.paused) {
      await p.resume();
    } else {
      await p.play(UrlSource(widget.url!));
    }
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : AppColors.gold;
    final total = (_dur?.inMilliseconds ?? widget.seconds * 1000).clamp(1, 1 << 30);
    final progress = (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    final shown = _playing || _pos > Duration.zero ? _pos.inSeconds : widget.seconds;
    return SizedBox(
      width: 210,
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: widget.mine ? Colors.white.withAlpha(60) : AppColors.gold.withAlpha(36), shape: BoxShape.circle),
            child: widget.url == null
                ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Icon(_playing ? Icons.pause : Icons.play_arrow, color: fg),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 4, color: fg, backgroundColor: fg.withAlpha(60)),
            ),
            const SizedBox(height: 5),
            Text(_mmss(shown), style: GoogleFonts.tajawal(fontSize: 11, color: widget.mine ? Colors.white70 : AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 4),
        Icon(Icons.mic, size: 16, color: fg.withAlpha(180)),
      ]),
    );
  }
}
