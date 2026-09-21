import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// New post (`POST /posts`): text in the current language, up to 4 images and an optional sector.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _text = TextEditingController();
  final List<XFile> _images = [];
  int? _sector;
  bool _posting = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage(limit: 4);
    if (picked.isNotEmpty) setState(() => _images..clear()..addAll(picked.take(4)));
  }

  Future<void> _publish() async {
    if (_text.text.trim().isEmpty && _images.isEmpty) {
      showAppToast(context, '⚠️ ${t('home.create_post_placeholder', 'اكتب محتوى المنشور')}');
      return;
    }
    setState(() => _posting = true);
    try {
      final files = <MapEntry<String, http.MultipartFile>>[];
      for (final img in _images) {
        files.add(MapEntry('media[]', http.MultipartFile.fromBytes('media[]', await img.readAsBytes(), filename: img.name)));
      }
      await ApiClient.i.postMultipart('/posts', fields: {
        if (_text.text.trim().isNotEmpty) 'content_${L10n.i.lang}': _text.text.trim(),
        if (_sector != null) 'sector_id': '$_sector',
      }, files: files);
      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(context, '✅ ${t('post.publish', 'نشر')}');
      AppData.refresh();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.i.name;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              Expanded(child: Text(t('home.create_post_placeholder', 'إنشاء منشور'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800))),
              ElevatedButton(
                onPressed: _posting ? null : _publish,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: _posting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)) : Text(t('post.publish', 'نشر'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark)),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(14), children: [
              Row(children: [
                CircleAvatar(backgroundColor: AppColors.gold, child: Text(name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
                const SizedBox(width: 10),
                Text(name, style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                maxLines: 8,
                minLines: 4,
                style: GoogleFonts.tajawal(fontSize: 15),
                decoration: InputDecoration(border: InputBorder.none, hintText: t('home.create_post_placeholder', 'اكتب منشورك هنا...'), hintStyle: GoogleFonts.tajawal(color: AppColors.muted)),
              ),
              if (_images.isNotEmpty)
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: FutureBuilder(future: _images[i].readAsBytes(), builder: (_, s) => s.hasData ? Image.memory(s.data!, width: 92, height: 92, fit: BoxFit.cover) : const SizedBox(width: 92, height: 92))),
                      PositionedDirectional(top: 2, end: 2, child: GestureDetector(onTap: () => setState(() => _images.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                    ]),
                  ),
                ),
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.image_outlined, color: AppColors.gold), label: Text(t('post.add_image', 'صورة'), style: GoogleFonts.tajawal(color: AppColors.text))),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _sector,
                    isExpanded: true,
                    decoration: InputDecoration(hintText: t('nav.gates', 'الأبواب'), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: [for (final d in AppData.doors) DropdownMenuItem(value: d['id'] as int, child: Text(d['name'] as String, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 13)))],
                    onChanged: (v) => setState(() => _sector = v),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
