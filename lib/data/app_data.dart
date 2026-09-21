import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/factory_model.dart';
import '../models/product_model.dart';
import '../models/post_model.dart';
import '../models/opportunity_model.dart';
import '../services/api_client.dart';
import '../services/l10n.dart';

/// Live data loaded from the Factorya API (replaces the old mock data).
/// Lists are filled by [load] before the first frame and refreshed by [refresh].
class AppData {
  static List<Map<String, dynamic>> doors = [];
  static Map<String, Map<String, dynamic>> gateData = {};
  static List<FactoryModel> factories = [];
  /// Spotlight factories (`/factories/imported-by-subscriptions`), as on the website home.
  static List<FactoryModel> featured = [];
  static List<ProductModel> products = [];
  static List<PostModel> posts = [];
  static List<OpportunityModel> opportunities = [];
  static List<Map<String, dynamic>> countries = [];
  static List<Map<String, dynamic>> packages = [];
  static List<Map<String, dynamic>> sponsors = [];
  /// `/landing-page` (footer + about text) and `/site-statistics`.
  static Map<String, dynamic> landing = {};
  static Map<String, dynamic> stats = {};

  /// Signed-in user's chat conversations and activity feed (empty when logged out).
  static List<Map<String, dynamic>> messages = [];
  static List<Map<String, dynamic>> notifications = [];

  /// Selected market. The API lists free factories only when a country is given.
  static int countryId = 183; // Saudi Arabia by default
  static const _kCountry = 'country_id';

  static Map<String, dynamic>? get country {
    for (final c in countries) {
      if (c['id'] == countryId) return c;
    }
    return null;
  }

  /// True until the visitor has picked a country (first launch): the app shows the country popup.
  static bool needsCountry = false;

  static bool loaded = false;
  static String? error;

  /// Bumped after every refresh so listening screens can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static final _api = ApiClient.i;

  static Future<void> setCountry(int id) async {
    countryId = id;
    needsCountry = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kCountry, id);
    } catch (_) {}
    await Future.wait([_guard(_loadFactories), _guard(_loadPosts), _guard(_loadSponsors)]);
    revision.value++;
  }

  static Future<void> load() async {
    error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_kCountry);
      needsCountry = saved == null;
      countryId = saved ?? countryId;
    } catch (_) {}
    await Future.wait([
      _guard(_loadGates),
      _guard(_loadFactories),
      _guard(_loadFeatured),
      _guard(_loadProducts),
      _guard(_loadPosts),
      _guard(_loadOpportunities),
      _guard(_loadCountries),
      _guard(_loadPackages),
      _guard(_loadSponsors),
      _guard(_loadLanding),
      _guard(_loadStats),
    ]);
    loaded = true;
    revision.value++;
  }

  static Future<void> refresh() async {
    await load();
    if (ApiClient.i.token != null) await loadUserData();
  }

  /// Loads data that needs a signed-in user.
  static Future<void> loadUserData() async {
    if (ApiClient.i.token == null) {
      clearUserData();
      return;
    }
    await Future.wait([_guard(_loadConversations), _guard(_loadNotifications)]);
    revision.value++;
  }

  static void clearUserData() {
    messages = [];
    notifications = [];
    revision.value++;
  }

  static Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'تعذّر تحميل البيانات';
    }
  }

  // ───────────────────────── loaders ─────────────────────────

  static Future<void> _loadGates() async {
    final gatesRes = await _api.get('/gates', query: {'per_page': 100});
    final list = <Map<String, dynamic>>[];
    final data = <String, Map<String, dynamic>>{};
    for (final g in ApiClient.list(gatesRes['data'])) {
      final id = g['id'] as int;
      final name = tr(g, 'name');
      final emoji = gateEmoji(name);
      list.add({
        'id': id,
        'name': name,
        'emoji': emoji,
        'short': _shortName(name),
        'count': g['categories_count'] ?? 0,
        'image': g['image_url'],
      });
      data[name] = {'id': id, 'emoji': emoji};
    }
    doors = list;
    gateData = data;
  }

  static final Map<int, List<Map<String, dynamic>>> _subCache = {};

  /// Sub-categories of a gate, fetched on demand and cached.
  static Future<List<Map<String, dynamic>>> fetchSubcategories(int gateId) async {
    final cached = _subCache[gateId];
    if (cached != null) return cached;
    final res = await _api.get('/gates/$gateId/categories', query: {'per_page': 100});
    final subs = ApiClient.list(res['data']).map((c) => {'id': c['id'] as int, 'name': tr(c, 'name'), 'image': c['image_url']}).toList();
    return _subCache[gateId] = subs;
  }

  static Future<void> _loadFactories() async {
    final res = await _api.get('/factories', query: {'per_page': 30, 'country_id': countryId});
    factories = ApiClient.list(res['data']).map(factoryFromJson).toList();
  }

  static Future<void> _loadFeatured() async {
    final res = await _api.get('/factories/imported-by-subscriptions');
    final data = res['data'];
    final raw = data is Map ? data['factories'] : data;
    featured = ApiClient.list(raw).map(factoryFromJson).toList();
  }

  static Future<void> _loadLanding() async {
    final res = await _api.get('/landing-page');
    landing = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : {};
  }

  static Future<void> _loadStats() async {
    final res = await _api.get('/site-statistics');
    stats = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : {};
  }

  static Future<void> _loadProducts() async {
    final res = await _api.get('/products', query: {'per_page': 100, 'country_id': countryId});
    products = ApiClient.list(res['data']).map(productFromJson).toList();
  }

  static Future<void> _loadPosts() async {
    final res = await _api.get('/posts', query: {'per_page': 30, 'order': 'latest', 'country_id': countryId});
    posts = ApiClient.list(res['data']).map(postFromJson).toList();
  }

  static Future<void> _loadOpportunities() async {
    final res = await _api.get('/opportunities', query: {'per_page': 100});
    opportunities = ApiClient.list(res['data']).map(opportunityFromJson).toList();
  }

  static Future<void> _loadCountries() async {
    final res = await _api.get('/countries', query: {'per_page': 100});
    // Only the countries the admin activated.
    countries = ApiClient.list(res['data']).where((c) => c['is_active'] != false).toList();
  }

  static Future<void> _loadPackages() async {
    final res = await _api.get('/packages');
    final data = res['data'];
    packages = data is Map ? ApiClient.list(data['packages']) : [];
  }

  static Future<void> _loadSponsors() async {
    final res = await _api.get('/sponsers');
    final data = res['data'];
    final out = <Map<String, dynamic>>[];
    if (data is Map && data['factories'] is Map) {
      (data['factories'] as Map).forEach((group, items) {
        for (final f in ApiClient.list(items)) {
          out.add({'group': '$group', 'factory': factoryFromJson(f)});
        }
      });
    }
    sponsors = out;
  }

  static Future<void> _loadConversations() async {
    final res = await _api.get('/chat/conversations', query: {'per_page': 50});
    messages = ApiClient.list(res['data']).map((c) {
      final f = c['factory'] is Map ? Map<String, dynamic>.from(c['factory'] as Map) : <String, dynamic>{};
      final last = c['last_message'] is Map ? Map<String, dynamic>.from(c['last_message'] as Map) : <String, dynamic>{};
      final name = tr(f, 'name').isNotEmpty ? tr(f, 'name') : 'محادثة';
      return {
        'name': name,
        'avatar': String.fromCharCode(name.runes.first).toUpperCase(),
        'color': _avatarColors[(f['id'] as int? ?? 0) % _avatarColors.length],
        'preview': (last['message'] as String?) ?? '',
        'time': timeAgo(last['created_at'] as String?),
        'unread': (c['unread_count'] as num?)?.toInt() ?? 0,
        'factoryId': '${f['id'] ?? ''}',
        'logo': logoUrl(f),
      };
    }).toList();
  }

  static Future<void> _loadNotifications() async {
    final res = await _api.get('/profile/activity-log', query: {'per_page': 30});
    notifications = ApiClient.list(res['data']).map((a) {
      final action = '${a['action'] ?? ''}';
      final style = _activityStyle(action);
      return {
        'icon': style[0],
        'color': style[1],
        'bg': style[2],
        'text': (a['description'] as String?) ?? action,
        'time': timeAgo(a['created_at'] as String?),
        'type': 'الكل',
        'read': true,
      };
    }).toList();
  }

  static List<String> _activityStyle(String action) {
    if (action.contains('delete') || action.contains('remove')) return ['🗑️', '#E84040', '#FFF0F0'];
    if (action.contains('create') || action.contains('store')) return ['✅', '#22A855', '#E8F8EE'];
    if (action.contains('update')) return ['✏️', '#5563DE', '#EEF0FF'];
    return ['🔔', '#D4A017', '#FFF8E7'];
  }

  // ───────────────────────── on-demand fetches ─────────────────────────

  static Future<FactoryModel> fetchFactory(String id) async {
    final res = await _api.get('/factories/$id');
    return factoryFromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  static final Map<String, List<Map<String, dynamic>>> _bannerCache = {};

  /// Active banners for a `/banners?location=` slot (cached per session).
  static Future<List<Map<String, dynamic>>> fetchBanners(String location) async {
    final cached = _bannerCache[location];
    if (cached != null) return cached;
    try {
      final res = await _api.get('/banners', query: {'location': location});
      final data = res['data'];
      return _bannerCache[location] = data is Map ? ApiClient.list(data['banners']) : [];
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>>? _sliders;

  static Future<List<Map<String, dynamic>>> fetchSliders() async {
    if (_sliders != null) return _sliders!;
    try {
      final res = await _api.get('/sliders');
      final data = res['data'];
      return _sliders = data is Map ? ApiClient.list(data['sliders']) : [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFactoryVideos(String factoryId) async {
    final res = await _api.get('/factories/$factoryId/videos', query: {'per_page': 50});
    return ApiClient.list(res['data']);
  }

  static Future<List<Map<String, dynamic>>> fetchFactoryImages(String factoryId) async {
    final res = await _api.get('/factories/$factoryId/factory-images', query: {'per_page': 50});
    return ApiClient.list(res['data']);
  }

  static Future<List<BranchModel>> fetchBranches(String factoryId) async {
    final res = await _api.get('/factories/$factoryId/branches', query: {'per_page': 50});
    return ApiClient.list(res['data']).map((b) {
      final city = b['city'] is Map ? tr(Map<String, dynamic>.from(b['city'] as Map), 'name') : '';
      return BranchModel(
        name: (b['city_ar'] as String?) ?? (b['city_en'] as String?) ?? city,
        address: city.isNotEmpty ? city : ((b['city_ar'] as String?) ?? ''),
        phone: (b['phone'] as String?) ?? '',
        hours: '',
      );
    }).toList();
  }

  static Future<List<ProductModel>> fetchFactoryProducts(String factoryId) async {
    final res = await _api.get('/factories/$factoryId/products', query: {'per_page': 100});
    return ApiClient.list(res['data']).map(productFromJson).toList();
  }

  static Future<List<FactoryModel>> searchFactories({String? q, int? gateId, int? categoryId, int? countryId, int? opportunityId}) async {
    final res = await _api.get('/factories', query: {
      'per_page': 100,
      'search': q,
      'gate_id': gateId,
      'category_id': categoryId,
      'opportunity_id': opportunityId,
      'country_id': countryId ?? AppData.countryId,
    });
    return ApiClient.list(res['data']).map(factoryFromJson).toList();
  }

  // ───────────────────────── mappers ─────────────────────────

  /// Picks the Arabic value of a translated field (`name_ar`), falling back to English/Turkish.
  static String tr(Map<String, dynamic> m, String key) {
    final pref = L10n.i.lang;
    for (final l in [pref, 'ar', 'en', 'tr']) {
      final v = m['${key}_$l'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final v = m[key];
    return v is String ? v : '';
  }

  static FactoryModel factoryFromJson(Map<String, dynamic> f) {
    Map<String, dynamic> map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};
    final id = '${f['id']}';
    final gates = f['gates'] is List ? ApiClient.list(f['gates']) : <Map<String, dynamic>>[];
    final gateName = gates.isNotEmpty ? tr(gates.first, 'name') : '';
    final category = tr(map(f['category']), 'name');
    final sub = '${f['subscription_type'] ?? ''}';
    final phones = map(f['phones']);
    final whatsapp = phones['whatsapp'] ?? phones['whatsapp_number'];
    final activities = f['activities_ar'] is List && (f['activities_ar'] as List).isNotEmpty
        ? f['activities_ar']
        : f['activities_en'];

    return FactoryModel(
      id: id,
      name: tr(f, 'name'),
      category: category.isNotEmpty ? category : gateName,
      emoji: gateEmoji(gateName.isNotEmpty ? gateName : category),
      rating: 0,
      reviewCount: 0,
      inquiryCount: 0,
      isPremium: sub == 'premium' || f['is_featured'] == true,
      isVerified: f['is_verified'] == true,
      isAvailable: true,
      city: tr(map(f['city']), 'name'),
      foundedYear: (f['founded_year'] as num?)?.toInt() ?? 0,
      employeeCount: (f['employees_count'] as num?)?.toInt() ?? 0,
      description: tr(f, 'about').isNotEmpty ? tr(f, 'about') : tr(f, 'short_description'),
      phone: (f['phone'] as String?) ?? '',
      whatsapp: whatsapp is String ? whatsapp : '',
      email: (f['email'] as String?) ?? '',
      tags: activities is List ? activities.map((e) => '$e').toList() : const [],
      nickname: (f['nickname'] as String?) ?? id,
      logoUrl: logoUrl(f),
      subscriptionType: sub,
      country: tr(map(f['country']), 'name'),
      viewsCount: (f['views_count'] as num?)?.toInt() ?? 0,
      productsCount: (f['products_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Avatar of a post author (`/users/{id}/image` when the user has an image).
  static String userImageUrl(Map<String, dynamic> user) {
    final img = user['image'];
    if (img is String && img.startsWith('http')) return img;
    if (img is String && img.isNotEmpty) return '${ApiClient.host}/api/users/${user['id']}/image';
    return '';
  }

  static String logoUrl(Map<String, dynamic> f) {
    final path = f['logo_path'];
    if (path is String && path.startsWith('http')) return path;
    if (path is String && path.isNotEmpty) return '${ApiClient.host}/api/factories/${f['id']}/logo';
    return '';
  }

  static ProductModel productFromJson(Map<String, dynamic> p) {
    final factory = p['factory'] is Map ? Map<String, dynamic>.from(p['factory'] as Map) : <String, dynamic>{};
    final cats = p['categories'] is List ? ApiClient.list(p['categories']) : <Map<String, dynamic>>[];
    final images = p['images'] is List ? (p['images'] as List) : const [];
    final category = cats.isNotEmpty ? tr(cats.first, 'name') : '';
    final price = p['price'];
    return ProductModel(
      id: '${p['id']}',
      name: tr(p, 'name'),
      factoryName: tr(factory, 'name'),
      factoryId: '${p['factory_id'] ?? factory['id'] ?? ''}',
      category: category,
      emoji: gateEmoji(category),
      description: tr(p, 'description'),
      isAvailable: p['status'] == null || '${p['status']}' == 'active' || '${p['status']}' == 'published',
      origin: (p['manufacturing'] as String?) ?? '',
      minOrder: p['stock_quantity'] != null ? '${p['stock_quantity']}' : '',
      leadTime: '',
      certification: (p['warranty'] as String?) ?? '',
      imageUrl: images.isNotEmpty ? '${images.first}' : '',
      price: price == null ? '' : '$price ${p['currency'] ?? ''}'.trim(),
    );
  }

  static PostModel postFromJson(Map<String, dynamic> p) {
    final user = p['user'] is Map ? Map<String, dynamic>.from(p['user'] as Map) : <String, dynamic>{};
    final name = (user['name'] as String?) ?? '';
    final images = p['image_urls'] is List ? (p['image_urls'] as List).map((e) => '$e').toList() : <String>[];
    final videos = p['video_urls'] is List ? p['video_urls'] as List : const [];
    final uid = '${user['id'] ?? p['user_id'] ?? 0}';
    PostType type = PostType.text;
    if (p['is_autogenerated'] == true) {
      type = PostType.update;
    } else if (images.length > 1) {
      type = PostType.photos;
    } else if (images.isNotEmpty) {
      type = PostType.image;
    } else if (videos.isNotEmpty) {
      type = PostType.video;
    }
    final text = tr(p, 'content');
    return PostModel(
      id: '${p['id']}',
      authorName: name.isEmpty ? 'مستخدم' : name,
      authorAvatar: name.isEmpty ? '؟' : String.fromCharCode(name.runes.first).toUpperCase(),
      authorColor: _avatarColors[(int.tryParse(uid) ?? 0) % _avatarColors.length],
      time: dateTime(p['created_at'] as String?),
      text: text,
      type: type,
      isVerified: user['has_factory'] == true,
      likes: (p['likes_count'] as num?)?.toInt() ?? 0,
      comments: (p['comments_count'] as num?)?.toInt() ?? 0,
      isLiked: p['is_liked'] == true,
      imageUrls: images,
      authorId: uid,
      authorImage: userImageUrl(user),
      authorIsFactory: user['account_type'] == 'factory' || user['has_factory'] == true,
      authorFactoryId: user['factory_id'] == null ? '' : '${user['factory_id']}',
      isAutogenerated: p['is_autogenerated'] == true,
      sourceEntity: '${p['source_entity'] ?? ''}',
      metadata: p['metadata'] is Map ? Map<String, dynamic>.from(p['metadata'] as Map) : null,
    );
  }

  static OpportunityModel opportunityFromJson(Map<String, dynamic> o) {
    final name = tr(o, 'name');
    return OpportunityModel(
      id: '${o['id']}',
      title: name,
      type: OppType.partnership,
      typeLabel: 'فرصة',
      emoji: gateEmoji(name, fallback: '💼'),
      bgColor: '#FFF3D0',
      city: '',
      budget: '',
      deadline: '',
      company: '',
      description: tr(o, 'description'),
      postedAgo: timeAgo(o['created_at'] as String?),
      imageUrl: (o['image_url'] as String?) ?? '',
    );
  }

  // ───────────────────────── helpers ─────────────────────────

  static const _avatarColors = ['#D4A017', '#5563DE', '#22A855', '#E0533D', '#8E44AD', '#16A085'];

  static String _cleanPostText(String t) => t.replaceAll('«', '"').replaceAll('»', '"');

  static String _shortName(String name) {
    final n = name.replaceFirst('الصناعات ', '').replaceFirst('صناعات ', '');
    final words = n.split(' ');
    return words.take(2).join(' ');
  }

  static String gateEmoji(String name, {String fallback = '🏭'}) {
    const rules = <List<String>>[
      ['غذائ', '🌾'], ['زراع', '🌱'], ['محاصيل', '🌱'], ['دوائ', '💊'], ['طبي', '💊'],
      ['كيماو', '⚗️'], ['هندس', '⚙️'], ['ميكانيك', '⚙️'], ['معدن', '🔩'], ['تعدين', '⛏️'],
      ['كهرب', '🔌'], ['إلكترون', '🔌'], ['نسيج', '🧵'], ['ملابس', '🧵'], ['جلود', '🧵'],
      ['بلاستيك', '🧴'], ['تعبئة', '📦'], ['تغليف', '📦'], ['ورق', '📄'], ['طباعة', '🖨️'],
      ['أخشاب', '🪵'], ['خشب', '🪵'], ['أثاث', '🪑'], ['بناء', '🏗️'], ['إنشاء', '🏗️'], ['مقاولات', '🏗️'],
      ['طاقة', '⚡'], ['بيئ', '♻️'], ['معدات', '🛠️'], ['تصدير', '🚢'], ['لوجست', '🚚'],
      ['استشار', '🧭'], ['خدمات', '🧭'], ['خامات', '🧱'],
    ];
    for (final r in rules) {
      if (name.contains(r[0])) return r[1];
    }
    return fallback;
  }

  /// `21/09/2026 00:52` — the website's post timestamp format.
  static String dateTime(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  static String timeAgo(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} دقيقة';
    if (d.inHours < 24) return 'منذ ${d.inHours} ساعة';
    if (d.inDays < 30) return 'منذ ${d.inDays} يوم';
    if (d.inDays < 365) return 'منذ ${d.inDays ~/ 30} شهر';
    return 'منذ ${d.inDays ~/ 365} سنة';
  }
}
