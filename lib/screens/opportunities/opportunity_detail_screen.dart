import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/opportunity_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/net_image.dart';
import 'create_opportunity_screen.dart';

class OpportunityDetailScreen extends StatelessWidget {
  final OpportunityModel opp;
  const OpportunityDetailScreen({super.key, required this.opp});

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
                Text('تفاصيل الفرصة', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Share.share('${opp.title}\n\nعبر فاكتوريا 🏭 https://factorya.net'),
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withAlpha(23), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.share_outlined, color: Colors.white, size: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: NetImage(url: opp.imageUrl, fallback: opp.emoji, fallbackSize: 70, width: double.infinity, height: 200),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opp.title, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.4)),
                      if (opp.postedAgo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(opp.postedAgo, style: GoogleFonts.tajawal(fontSize: 10.5, color: AppColors.muted)),
                      ],
                      const SizedBox(height: 12),
                      Text(opp.description.isNotEmpty ? opp.description : 'قدّم طلبك وسيتواصل معك فريقنا.',
                          style: GoogleFonts.tajawal(fontSize: 13, color: const Color(0xFF555555), height: 1.8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOpportunityScreen(preselected: opp))),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('تقديم طلب', style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
