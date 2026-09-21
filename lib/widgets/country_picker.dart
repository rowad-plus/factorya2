import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../theme/app_theme.dart';
import 'country_flag.dart';

/// Bottom sheet to switch the market (country) the whole app browses.
class CountryPicker {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('اختر الدولة', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            // The country the user is browsing from comes first, the others follow.
            for (final c in [...AppData.countries]..sort((a, b) => (b['id'] == AppData.countryId ? 1 : 0) - (a['id'] == AppData.countryId ? 1 : 0)))
              ListTile(
                leading: CountryFlag('${c['code'] ?? ''}', width: 40),
                title: Row(children: [
                  Flexible(child: Text(AppData.tr(c, 'name'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  CountryCodeBox('${c['code'] ?? ''}'),
                ]),
                trailing: c['id'] == AppData.countryId ? const Icon(Icons.check_circle, color: AppColors.gold) : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (c['id'] != AppData.countryId) AppData.setCountry(c['id'] as int);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
