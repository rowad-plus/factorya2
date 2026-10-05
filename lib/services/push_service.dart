import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'auth_service.dart';

/// Background/terminated messages: the system shows the notification itself.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Push notifications (FCM): registers this device for the logged-in user, shows
/// notifications while the app is open, tracks the unread count and opens the
/// right screen when a notification is tapped.
class PushService {
  PushService._();

  /// Unread notifications badge (header bell).
  static final ValueNotifier<int> unread = ValueNotifier(0);

  /// Set by main.dart: pushes a go_router location.
  static void Function(String location)? navigate;

  static const _channel = AndroidNotificationChannel(
    'factorya_default',
    'إشعارات فاكتوريا',
    description: 'الرسائل والتعليقات والطلبات والفرص الجديدة',
    importance: Importance.high,
  );

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String? _token;
  static Map<String, dynamic>? _pendingOpen;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push disabled: $e');
      return;
    }
    _ready = true;
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == null) return;
        try {
          open(Map<String, dynamic>.from(jsonDecode(r.payload!) as Map));
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // App open: FCM does not show the notification, so show it ourselves.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null && !Platform.isIOS) {
        _local.show(
          m.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(_channel.id, _channel.name,
                channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
          ),
          payload: jsonEncode(m.data),
        );
      }
      refreshUnread();
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _pendingOpen = initial.data;

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _token = t;
      register();
    });
    AuthService.i.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  /// Called once the router is ready, to handle a notification that launched the app.
  static void flushPendingOpen() {
    final data = _pendingOpen;
    _pendingOpen = null;
    if (data != null) open(data);
  }

  static bool _wasLoggedIn = false;
  static void _onAuthChanged() {
    final loggedIn = AuthService.i.isLoggedIn;
    if (loggedIn && !_wasLoggedIn) {
      register();
      refreshUnread();
    } else if (!loggedIn) {
      unread.value = 0;
    }
    _wasLoggedIn = loggedIn;
  }

  static Future<void> register() async {
    if (!_ready || !AuthService.i.isLoggedIn) return;
    try {
      _token ??= await FirebaseMessaging.instance.getToken();
      if (_token == null) return;
      await ApiClient.i.post('/device-tokens', body: {'token': _token, 'platform': Platform.isIOS ? 'ios' : 'android'});
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }

  /// Must run before the auth token is cleared on logout.
  static Future<void> unregister() async {
    if (!_ready || _token == null || !AuthService.i.isLoggedIn) return;
    try {
      await ApiClient.i.delete('/device-tokens', body: {'token': _token});
    } catch (_) {}
  }

  static Future<void> refreshUnread() async {
    if (!AuthService.i.isLoggedIn) return;
    try {
      final res = await ApiClient.i.get('/notifications/unread-count');
      final data = res['data'];
      unread.value = data is Map ? ((data['unread_count'] as num?)?.toInt() ?? 0) : 0;
    } catch (_) {}
  }

  /// Screen for a notification's data payload.
  static String? routeFor(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}';
    final requestId = '${data['opportunity_request_id'] ?? ''}';
    switch (type) {
      case 'chat':
        return '/chat';
      case 'comment':
      case 'comment_reply':
      case 'like':
        return AuthService.i.profileRoute;
      case 'opportunity':
      case 'opportunity_comment':
        return requestId.isNotEmpty ? '/opportunity-requests/$requestId' : '/opportunity-requests';
      case 'admin':
        final link = '${data['link'] ?? ''}';
        if (link.isEmpty) return '/notifications';
        final uri = Uri.tryParse(link);
        if (uri != null && uri.host.endsWith('factorya.net')) return uri.path.isEmpty ? '/' : uri.path;
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        return null;
      default:
        // E-mail mirrored notifications (quote requests, RFQ offers, job applications, subscriptions…).
        return AuthService.i.hasFactory ? '/dashboard' : '/notifications';
    }
  }

  static void open(Map<String, dynamic> data) {
    final route = routeFor(data);
    if (route != null) navigate?.call(route);
    refreshUnread();
  }
}
