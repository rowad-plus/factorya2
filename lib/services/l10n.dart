import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Same translation files and `t('nav.home')` lookup the website uses (ar / en / tr).
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n i = L10n._();

  static const supported = ['ar', 'en', 'tr'];
  static const _kLang = 'lang';

  String lang = 'ar';
  final Map<String, dynamic> _tables = {};
  final Map<String, dynamic> _dash = {};

  bool get isRtl => lang == 'ar';

  /// Loads all three tables and restores the saved language.
  Future<void> load() async {
    for (final l in supported) {
      try {
        _tables[l] = jsonDecode(await rootBundle.loadString('assets/locales/$l.json'));
      } catch (_) {
        _tables[l] = <String, dynamic>{};
      }
    }
    for (final l in supported) {
      try {
        _dash[l] = jsonDecode(await rootBundle.loadString('assets/locales/dash_$l.json'));
      } catch (_) {
        _dash[l] = <String, dynamic>{};
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kLang);
      if (saved != null && supported.contains(saved)) lang = saved;
    } catch (_) {}
    ApiClient.i.locale = lang;
  }

  Future<void> setLang(String l) async {
    if (!supported.contains(l) || l == lang) return;
    lang = l;
    ApiClient.i.locale = l;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLang, l);
    } catch (_) {}
    notifyListeners();
  }

  /// `t('nav.home')`; returns [fallback] (or the key) when the string is missing.
  String t(String key, [String? fallback]) {
    dynamic cur = _tables[lang];
    for (final part in key.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return fallback ?? key;
      }
    }
    return cur is String ? cur : (fallback ?? key);
  }
}

/// Dashboard strings (the site's `lang/*/dashboard.php`, `products.php`, ...): `td('products.add_product')`.
/// `:name` style placeholders are replaced from [args].
String td(String key, [Map<String, Object?> args = const {}]) {
  dynamic cur = L10n.i._dash[L10n.i.lang];
  for (final part in key.split('.')) {
    if (cur is Map && cur.containsKey(part)) {
      cur = cur[part];
    } else {
      cur = null;
      break;
    }
  }
  var out = cur is String ? cur : (() {
    dynamic fb = L10n.i._dash['ar'];
    for (final part in key.split('.')) {
      if (fb is Map && fb.containsKey(part)) {
        fb = fb[part];
      } else {
        return key;
      }
    }
    return fb is String ? fb : key;
  })();
  args.forEach((k, v) => out = out.replaceAll(':$k', '$v'));
  return out;
}

/// Shorthand: `t('nav.home')`.
String t(String key, [String? fallback]) => L10n.i.t(key, fallback);
