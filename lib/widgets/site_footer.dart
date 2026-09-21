import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_data.dart';
import '../screens/auth/login_modal.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// The website's footer (`sheared/Footer.tsx`): about text, link groups, contact details
/// (from `/landing-page`) and social links. Put it at the end of every page.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  Future<void> _open(String url) async {
    final u = url.startsWith('http') || url.startsWith('mailto:') || url.startsWith('tel:') ? url : 'https://$url';
    final uri = Uri.tryParse(u);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([L10n.i, AppData.revision]),
      builder: (context, _) {
        final footer = AppData.landing['footer'] is Map ? Map<String, dynamic>.from(AppData.landing['footer'] as Map) : <String, dynamic>{};
        final about = AppData.landing['about_us'] is Map ? Map<String, dynamic>.from(AppData.landing['about_us'] as Map) : <String, dynamic>{};
        final description = AppData.tr(about, 'description').isNotEmpty ? AppData.tr(about, 'description') : ('${about['description'] ?? ''}'.isNotEmpty ? '${about['description']}' : t('footer.about_us_default'));

        Widget group(String title, List<(String, VoidCallback)> links) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  const SizedBox(height: 10),
                  for (final l in links)
                    GestureDetector(
                      onTap: l.$2,
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(l.$1, style: GoogleFonts.tajawal(fontSize: 13.5, color: Colors.white70))),
                    ),
                ],
              ),
            );

        final email = '${footer['contact_email'] ?? ''}';
        final phone = '${footer['contact_phone'] ?? ''}';
        final socials = [
          (Icons.business_center_outlined, '${footer['linkedin_url'] ?? ''}'),
          (Icons.camera_alt_outlined, '${footer['instagram_url'] ?? ''}'),
          (Icons.alternate_email, '${footer['x_url'] ?? ''}'),
        ].where((s) => s.$2.isNotEmpty).toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 20),
          color: AppColors.dark,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  SvgPicture.asset('assets/images/logo_white.svg', width: 34, height: 34),
                  const SizedBox(width: 6),
                  RichText(text: TextSpan(children: [
                    TextSpan(text: 'Factory', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    TextSpan(text: 'a', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),
              Text(description, style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white60, height: 1.8)),
              const SizedBox(height: 22),
              group(t('footer.about_site', 'عن الموقع'), [
                (t('nav.home', 'الرئيسية'), () => context.go('/')),
                (t('nav.about', 'تعرف علينا'), () => context.push('/about')),
                (t('nav.gates', 'الأبواب'), () => context.go('/categories')),
                (t('nav.factories', 'المصانع'), () => context.push('/companies')),
                (t('nav.products_services', 'المنتجات'), () => context.go('/products')),
                (t('nav.blog', 'المدونة'), () => context.push('/blog')),
                (t('nav.contact', 'اتصل بنا'), () => context.push('/contact')),
              ]),
              group(t('footer.important_links', 'روابط مهمة'), [
                (t('about.packages', 'الأسعار'), () => context.push('/prices')),
                (t('footer.faq', 'الأسئلة الشائعة'), () => context.push('/about')),
                (t('nav.login', 'تسجيل الدخول'), () => LoginModal.show(context)),
                (t('footer.register', 'إنشاء حساب'), () => context.push('/factory/create')),
                (t('terms.title', 'الشروط والأحكام'), () => context.push('/terms')),
              ]),
              group(footer['contact_title'] != null && '${footer['contact_title']}'.isNotEmpty ? '${footer['contact_title']}' : t('footer.contact_us', 'تواصل معنا'), [
                if (email.isNotEmpty) (email, () => _open('mailto:$email')),
                if (phone.isNotEmpty) (phone, () => _open('tel:$phone')),
              ]),
              if (socials.isNotEmpty) ...[
                Text(footer['follow_title'] != null && '${footer['follow_title']}'.isNotEmpty ? '${footer['follow_title']}' : t('footer.follow_us', 'تابعنا'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
                const SizedBox(height: 10),
                Row(children: [
                  for (final s in socials)
                    GestureDetector(
                      onTap: () => _open(s.$2),
                      child: Container(
                        width: 38, height: 38,
                        margin: const EdgeInsetsDirectional.only(end: 10),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                        child: Icon(s.$1, color: Colors.white, size: 20),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF464646)),
              Center(child: Text('© ${DateTime.now().year} Factorya', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white38))),
            ],
          ),
        );
      },
    );
  }
}
