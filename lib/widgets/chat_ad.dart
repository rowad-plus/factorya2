import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/dashboard/dash_kit.dart' show dp;
import '../screens/opportunities/opportunities_screen.dart' show tri;
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Banner shown inside chats (admin banners with location "chat").
/// A visitor chatting with a *free* factory sees the visitor banners; a *free* factory owner sees the
/// banners the admin marked "factory only". Nothing is shown for paid factories.
class ChatAd extends StatefulWidget {
  /// Factory-targeted ad (owner side) instead of visitor-targeted.
  final bool forFactory;

  /// Visitor side: the factory being messaged (its plan decides whether the ad is shown).
  final String? factoryId;

  const ChatAd({super.key, this.forFactory = false, this.factoryId});

  @override
  State<ChatAd> createState() => _ChatAdState();
}

class _ChatAdState extends State<ChatAd> {
  List<Map<String, dynamic>> _ads = [];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _isFree() async {
    if (widget.forFactory) {
      final r = await ApiClient.i.get(dp('/my-factory'));
      final d = r['data'];
      if (d is! Map) return false;
      final type = d['subscription_type'];
      return type == null ? d['package'] == null : type == 'free';
    }
    final r = await ApiClient.i.get('/factories/${widget.factoryId}');
    final d = r['data'];
    return d is Map && (d['subscription_type'] ?? 'free') == 'free';
  }

  Future<void> _load() async {
    try {
      if (!await _isFree()) return;
      final res = await ApiClient.i.get('/banners', query: {'location': 'chat'});
      final data = res['data'];
      final all = data is Map ? ApiClient.list(data['banners']) : <Map<String, dynamic>>[];
      final ads = all.where((b) => (b['is_factory_only'] == true) == widget.forFactory && _image(b).isNotEmpty).toList()..shuffle(Random());
      if (!mounted || ads.isEmpty) return;
      setState(() => _ads = ads);
      if (ads.length > 1) {
        _timer = Timer.periodic(const Duration(seconds: 8), (_) {
          if (mounted) setState(() => _i = (_i + 1) % _ads.length);
        });
      }
    } catch (_) {}
  }

  String _image(Map<String, dynamic> b) {
    for (final k in const ['mobile_image_url', 'website_image_url']) {
      final v = b[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) return const SizedBox.shrink();
    final b = _ads[_i % _ads.length];
    final url = _image(b);
    return GestureDetector(
      onTap: () async {
        final link = b['link_url'] as String?;
        final uri = link == null || link.isEmpty ? null : Uri.tryParse(link);
        if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 4,
          child: Stack(fit: StackFit.expand, children: [
            Image.network(url, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFEEEEEE))),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(tri('إعلان', 'Reklam', 'Ad'), style: GoogleFonts.tajawal(fontSize: 10, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
