import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/net_image.dart';
import '../../widgets/shell_widgets.dart';
import '../../widgets/site_footer.dart';
import '../auth/login_modal.dart';
import '../dashboard/dash_sections.dart' show DashChatBody;
import 'chat_screen.dart';

/// `/chat`: the signed-in user's conversations with factories.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if ('${AuthService.i.user?['account_type']}' != 'factory') AppData.loadUserData();
    // Live inbox: refresh conversations and unread counts every few seconds while the tab is open.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (AuthService.i.isLoggedIn && '${AuthService.i.user?['account_type']}' != 'factory') AppData.loadUserData();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppData.revision, AuthService.i, L10n.i]),
      builder: (context, _) {
        if (!AuthService.i.isLoggedIn) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline, size: 44, color: AppColors.gold),
              const SizedBox(height: 10),
              Text(t('post.login_required', 'سجّل الدخول أولاً'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: () => LoginModal.show(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold), child: Text(t('nav.login', 'تسجيل الدخول'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
            ]),
          );
        }
        // A factory account answers its visitors from the dashboard conversations.
        if ('${AuthService.i.user?['account_type']}' == 'factory') {
          return Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(t('chat.title', 'الرسائل'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800)))),
            const Expanded(child: DashChatBody()),
          ]);
        }
        final list = AppData.messages;
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: AppData.loadUserData,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
                const HeaderBanner(),
              Padding(padding: const EdgeInsets.all(16), child: Text(t('chat.title', 'الرسائل'), style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800))),
              if (list.isEmpty)
                emptyState(t('chat.no_conversations', 'لا توجد محادثات بعد'))
              else
                for (final m in list)
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(factoryId: m['factoryId'] as String, name: m['name'] as String, avatar: m['avatar'] as String, color: AppColors.gold, logo: '${m['logo'] ?? ''}')));
                      AppData.loadUserData();
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
                      child: Row(children: [
                        Container(width: 46, height: 46, clipBehavior: Clip.antiAlias, decoration: const BoxDecoration(shape: BoxShape.circle), child: NetImage(url: '${m['logo'] ?? ''}', brandFallback: true, fallbackSize: 12, width: 46, height: 46)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(m['name'] as String, style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w800))),
                            Text('${m['time']}', style: GoogleFonts.tajawal(fontSize: 11, color: AppColors.muted)),
                          ]),
                          Text('${m['preview']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.muted)),
                        ])),
                        if ((m['unread'] as int) > 0)
                          Container(
                            margin: const EdgeInsetsDirectional.only(start: 8),
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(11)),
                            child: Text('${m['unread']}', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.dark)),
                          ),
                      ]),
                    ),
                  ),
              const SiteFooter(),
            ],
          ),
        );
      },
    );
  }
}
