import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown for any non-2xx response or network failure.
class ApiException implements Exception {
  final int? status;
  final String message;
  final Map<String, dynamic> errors;
  final Map<String, dynamic> body;

  ApiException(this.message, {this.status, this.errors = const {}, this.body = const {}});

  /// Set on `403` when the feature is not in the factory's package.
  String? get capability => body['capability'] as String?;

  bool get isUnauthorized => status == 401;
  bool get isValidation => status == 422;

  @override
  String toString() => message;
}

/// Thin JSON client for the Factorya Laravel API (`/api/v1`).
class ApiClient {
  ApiClient._();
  static final ApiClient i = ApiClient._();

  static const String host = 'https://factorya.net';
  static const String base = '$host/api/v1';

  String? token;
  String locale = 'ar';
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Accept-Language': locale,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$base$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  /// [allLocales] omits the language header so translated fields come back as `name_ar`, `name_en`, ...
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, bool allLocales = false}) =>
      _send(() => http.get(_uri(path, query), headers: allLocales ? (Map.of(_headers)..remove('Accept-Language')) : _headers));

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) =>
      _send(() => http.post(
            _uri(path),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body ?? {}),
          ));

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send(() => http.put(
            _uri(path),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body ?? {}),
          ));

  Future<Map<String, dynamic>> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) =>
      _send(() => http.patch(
            _uri(path),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body ?? {}),
          ));

  /// Multipart POST (image / video uploads). [files] maps a field name (`media[]`) to picked files.
  Future<Map<String, dynamic>> postMultipart(String path, {Map<String, String> fields = const {}, List<MapEntry<String, http.MultipartFile>> files = const []}) =>
      _send(() async {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers)
          ..fields.addAll(fields);
        for (final f in files) {
          req.files.add(f.value);
        }
        return http.Response.fromStream(await req.send());
      });

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException('تعذّر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى');
    }

    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    if (res.statusCode == 401) onUnauthorized?.call();

    final errors = json['errors'] is Map ? Map<String, dynamic>.from(json['errors'] as Map) : <String, dynamic>{};
    var message = (json['message'] as String?) ?? 'حدث خطأ غير متوقع (${res.statusCode})';
    if (errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = '${first.first}';
    }
    throw ApiException(message, status: res.statusCode, errors: errors, body: json);
  }

  /// Returns `data` as a list, whether the endpoint is paginated or not.
  static List<Map<String, dynamic>> list(dynamic data) {
    if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }
}
