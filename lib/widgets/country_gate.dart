import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../screens/opportunities/opportunities_screen.dart' show tri;
import '../theme/app_theme.dart';

/// First-launch popup: the visitor must pick the country to browse. Only countries the admin
/// activated (`/countries`, `is_active`) are listed. The choice is saved and can be changed later
/// from the country chip in the header.
class CountryGate {
  static bool _open = false;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (_open || !AppData.needsCountry || !AppData.loaded) return;
    _open = true;
    // The popup is only a fallback: if the device location resolves to an active country we use it silently.
    final detected = await _detectCountryId();
    if (detected != null) {
      await AppData.setCountry(detected);
      _open = false;
      return;
    }
    if (!context.mounted) {
      _open = false;
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: _CountryDialog()),
    );
    _open = false;
  }

  /// Device location → country code (same reverse-geocode service the website uses) → an active country id.
  static Future<int?> _detectCountryId() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 10));
      final res = await http
          .get(Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${pos.latitude}&longitude=${pos.longitude}&localityLanguage=en'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final code = '${(jsonDecode(res.body) as Map)['countryCode'] ?? ''}'.toUpperCase();
      if (code.isEmpty) return null;
      for (final c in AppData.countries) {
        if ('${c['code']}'.toUpperCase() == code) return c['id'] as int;
      }
    } catch (_) {}
    return null;
  }
}

class _CountryDialog extends StatefulWidget {
  const _CountryDialog();

  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  bool _busy = false;

  Future<void> _pick(Map<String, dynamic> c) async {
    setState(() => _busy = true);
    await AppData.setCountry(c['id'] as int);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final countries = AppData.countries;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/images/logo.svg', width: 52, height: 52),
            const SizedBox(height: 12),
            Text(tri('اختر الدولة', 'Ülkeni seç', 'Choose your country'), style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              tri('اختر الدولة التي تريد تصفّح المصانع والمنتجات فيها. يمكنك تغييرها لاحقاً من الهيدر.', 'Fabrikaları ve ürünleri görmek istediğin ülkeyi seç. Daha sonra üst menüden değiştirebilirsin.', 'Pick the country whose factories and products you want to browse. You can change it later from the header.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.gold))
            else if (countries.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text(tri('لا توجد دول متاحة حالياً', 'Şu anda ülke yok', 'No countries available'), style: GoogleFonts.tajawal(color: AppColors.muted)))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in countries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _pick(c),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                            child: Row(children: [
                              Container(
                                width: 42, height: 42,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: AppColors.gold3, shape: BoxShape.circle),
                                child: Text('${c['code'] ?? '?'}', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.dark)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(AppData.tr(c, 'name'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text))),
                              Icon(Icons.chevron_left, color: AppColors.muted.withAlpha(150)),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
