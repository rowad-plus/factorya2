import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Holds the signed-in user and the Sanctum token (persisted locally).
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService i = AuthService._();

  static const _kToken = 'auth_token';

  Map<String, dynamic>? user;

  bool get isLoggedIn => ApiClient.i.token != null && user != null;
  String get name => (user?['name'] as String?) ?? '';
  String get phone => (user?['phone_number'] as String?) ?? '';
  int? get userId => user?['id'] as int?;
  int? get factoryId => user?['factory_id'] as int?;
  bool get hasFactory => user?['has_factory'] == true;

  /// Restores a saved session; drops it if the server rejects the token.
  Future<void> restore() async {
    ApiClient.i.onUnauthorized = () => _clear(notify: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_kToken);
      if (t == null) return;
      ApiClient.i.token = t;
      final res = await ApiClient.i.get('/profile');
      user = _userFrom(res['data']);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _clear();
    } catch (_) {}
    notifyListeners();
  }

  Map<String, dynamic>? _userFrom(dynamic data) {
    if (data is Map && data['user'] is Map) return Map<String, dynamic>.from(data['user'] as Map);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Same as the website: the password is checked first, then the login OTP is sent.
  Future<void> requestLoginOtp(String phone, {String? password, String country = 'SA'}) async {
    await ApiClient.i.post('/auth/login', body: {'phone_number': phone, 'country_code': country, if (password != null && password.isNotEmpty) 'password': password});
  }

  /// Creates an account and sends the signup OTP.
  Future<void> register(String name, String phone, {String? email, String? password, String country = 'SA'}) async {
    await ApiClient.i.post('/auth/register', body: {
      'name': name,
      'phone_number': phone,
      'country_code': country,
      if (email != null && email.isNotEmpty) 'email': email,
      if (password != null && password.isNotEmpty) ...{'password': password, 'password_confirmation': password},
    });
  }

  Future<void> forgotPassword(String phone, {String country = 'SA'}) async {
    await ApiClient.i.post('/auth/forgot-password', body: {'phone_number': phone, 'country_code': country});
  }

  Future<void> resetPassword(String phone, String code, String password, {String country = 'SA'}) async {
    await ApiClient.i.post('/auth/reset-password', body: {'phone_number': phone, 'code': code, 'password': password, 'password_confirmation': password, 'country_code': country});
  }

  Future<void> resendOtp(String phone, {required bool signup, String country = 'SA'}) async {
    await ApiClient.i.post('/auth/resend-otp', body: {
      'phone_number': phone,
      'type': signup ? 'signup' : 'login',
      'country_code': country,
    });
  }

  Future<void> verifyOtp(String phone, String code, {required bool signup, String country = 'SA'}) async {
    final res = await ApiClient.i.post('/auth/verify-otp', body: {
      'phone_number': phone,
      'code': code,
      'type': signup ? 'signup' : 'login',
      'country_code': country,
    });
    final data = res['data'];
    final token = data is Map ? data['token'] as String? : null;
    if (token == null) throw ApiException('تعذّر إكمال تسجيل الدخول');
    ApiClient.i.token = token;
    user = _userFrom(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await ApiClient.i.post('/auth/logout');
    } catch (_) {}
    await _clear(notify: true);
  }

  Future<void> _clear({bool notify = false}) async {
    ApiClient.i.token = null;
    user = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
    } catch (_) {}
    if (notify) notifyListeners();
  }
}
