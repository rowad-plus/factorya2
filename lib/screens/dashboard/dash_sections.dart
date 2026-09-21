import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/app_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/net_image.dart';
import '../../widgets/shell_widgets.dart';
import '../opportunities/opportunities_screen.dart' show tri;
import '../../widgets/chat_ad.dart';
import '../chat/chat_screen.dart' show ChatScreen;
import 'dash_kit.dart';
import 'dash_gates.dart';
import 'dash_media.dart';

String _s(dynamic v) => v == null ? '' : '$v';
String _tr(Map<String, dynamic> m, String k) => AppData.tr(m, k);

// ═════════════════════════════════ CRUD sections ═════════════════════════════════

Widget productsSection() => DashList(
      title: td('products.product_management'),
      path: '/products',
      emptyText: td('products.no_products'),
      addLabel: td('products.add_product'),
      editLabel: td('products.edit_product'),
      confirmDelete: td('products.confirm_delete'),
      savedMessage: td('products.product_created'),
      deletedMessage: td('products.product_deleted'),
      toggle: true,
      titleOf: (p) => _tr(p, 'name'),
      subtitleOf: (p) => [if (p['price'] != null) '${p['price']} ${_s(p['currency'])}', '${td('products.stock_quantity')}: ${_s(p['stock_quantity'])}'].join(' · '),
      imageOf: (p) => p['images'] is List && (p['images'] as List).isNotEmpty ? '${(p['images'] as List).first}' : '',
      statusOf: (p) => _s(p['status']),
      fields: [
        DField('name', td('products.product_name'), required: true, translated: true),
        DField('description', td('products.description'), type: FT.multiline, translated: true),
        DField('price', td('products.price'), type: FT.number),
        DField('currency', td('products.currency'), hint: 'SAR / USD / EGP'),
        DField('stock_quantity', td('products.stock_quantity'), type: FT.number, required: true),
        DField('color', td('products.color')),
        DField('material', td('products.material')),
        DField('warranty', td('products.warranty')),
        DField('manufacturing', td('products.manufacturing')),
        DField('status', td('products.status'), type: FT.select, options: [('active', 'products.active'), ('inactive', 'products.inactive')]),
        DField('images', td('products.product_images'), type: FT.images),
      ],
    );

Widget clientsSection() => DashList(
      title: td('clients.clients'),
      path: '/clients',
      emptyText: td('clients.no_clients'),
      addLabel: td('clients.add_client'),
      editLabel: td('clients.edit_client'),
      confirmDelete: td('clients.confirm_delete'),
      savedMessage: td('clients.client_created'),
      deletedMessage: td('clients.client_deleted'),
      titleOf: (c) => _tr(c, 'name'),
      subtitleOf: (c) => _tr(c, 'activity_type'),
      imageOf: (c) => _s(c['image_url']),
      statusOf: (c) => _s(c['status']),
      fields: [
        DField('name', td('clients.client_name'), required: true, translated: true),
        DField('activity_type', td('clients.activity_type'), required: true, translated: true),
        const DField('country_id', '', type: FT.country),
        DField('contact_number', td('clients.contact_number')),
        DField('status', td('clients.status'), type: FT.select, options: [('active', 'clients.active'), ('inactive', 'clients.inactive')]),
        DField('image', td('clients.client_image'), type: FT.image),
      ],
    );

Widget branchesSection() => DashList(
      title: td('branches.branches'),
      path: '/branches',
      emptyText: td('branches.no_branches'),
      addLabel: td('branches.add_branch'),
      editLabel: td('branches.edit_branch'),
      confirmDelete: td('branches.confirm_delete'),
      savedMessage: td('branches.branch_created'),
      deletedMessage: td('branches.branch_deleted'),
      titleOf: (b) => _tr(b, 'name'),
      subtitleOf: (b) => _tr(b, 'address'),
      statusOf: (b) => _s(b['status']),
      fields: [
        DField('name', td('branches.branch_name'), required: true, translated: true),
        DField('address', td('branches.detailed_address'), required: true, translated: true),
        DField('manager_name', td('branches.manager_name'), translated: true),
        DField('working_hours', td('branches.working_hours'), translated: true, hint: td('branches.working_hours_placeholder')),
        const DField('country_id', '', type: FT.country),
        DField('phone', td('branches.phone')),
        DField('email', td('branches.email'), type: FT.email),
        DField('map_url', td('branches.map_url'), type: FT.url),
        DField('status', td('branches.status'), type: FT.select, options: [('active', 'branches.active'), ('inactive', 'branches.inactive')]),
      ],
    );

Widget jobsSection() => DashList(
      title: td('dashboard.jobs'),
      path: '/jobs',
      emptyText: t('jobs.no_jobs', 'لا توجد وظائف'),
      addLabel: td('dashboard.jobs'),
      editLabel: td('dashboard.jobs'),
      confirmDelete: '?',
      savedMessage: '✓',
      deletedMessage: '✓',
      toggle: true,
      titleOf: (j) => _tr(j, 'title'),
      subtitleOf: (j) => [_s(j['type']), if (j['salary_min'] != null) '${j['salary_min']}${j['salary_max'] != null ? '-${j['salary_max']}' : ''} ${_s(j['salary_currency'])}', if (j['deadline'] != null) _s(j['deadline'])].where((e) => e.isNotEmpty).join(' · '),
      statusOf: (j) => j['is_active'] == true ? 'active' : 'inactive',
      fields: [
        DField('title', td('dashboard.name'), required: true, translated: true),
        DField('description', td('products.description'), type: FT.multiline, translated: true),
        DField('location', td('branches.location'), translated: true),
        DField('type', 'Type', type: FT.select, options: const [('full_time', 'Full time'), ('part_time', 'Part time'), ('internship', 'Internship'), ('apprenticeship', 'Apprenticeship')]),
        DField('salary_min', 'Min', type: FT.number),
        DField('salary_max', 'Max', type: FT.number),
        DField('salary_currency', td('products.currency'), hint: 'SAR'),
        DField('deadline', tri('آخر موعد', 'Son tarih', 'Deadline'), type: FT.date),
        DField('status', td('products.status'), type: FT.select, options: [('active', 'products.active'), ('closed', 'closed')]),
      ],
    );

Widget jobApplicationsSection() => DashList(
      title: td('dashboard.job_applications'),
      path: '/job-applications',
      emptyText: td('dashboard.no_results'),
      titleOf: (a) => _s(a['full_name']),
      subtitleOf: (a) => [_s(a['job_title']), _s(a['email']), _s(a['phone'])].where((e) => e.isNotEmpty).join(' · '),
    );

Widget videosSection() => DashList(
      title: td('videos.video_management'),
      path: '/videos',
      emptyText: td('videos.no_videos'),
      addLabel: td('videos.add_video'),
      editLabel: td('videos.edit_video'),
      confirmDelete: td('videos.confirm_delete'),
      savedMessage: td('videos.video_created'),
      deletedMessage: td('videos.video_deleted'),
      toggle: true,
      titleOf: (v) => _tr(v, 'name'),
      imageOf: (v) => _s(v['thumbnail_url']),
      statusOf: (v) => v['is_active'] == true ? 'active' : 'inactive',
      fields: [
        DField('name', td('videos.video_name'), required: true, translated: true),
        DField('video', td('videos.video_file'), type: FT.video, required: true),
        DField('thumbnail', td('videos.thumbnail'), type: FT.image, required: true),
        DField('status', td('videos.status'), type: FT.select, options: [('active', 'videos.active'), ('inactive', 'videos.inactive')]),
      ],
    );

Widget imagesSection() => DashList(
      title: td('factory_images.image_management'),
      path: '/images',
      emptyText: td('factory_images.no_images'),
      addLabel: td('factory_images.add_image'),
      editLabel: td('factory_images.edit_image'),
      confirmDelete: td('factory_images.confirm_delete'),
      savedMessage: td('factory_images.image_created'),
      deletedMessage: td('factory_images.image_deleted'),
      toggle: true,
      titleOf: (v) => _tr(v, 'name').isNotEmpty ? _tr(v, 'name') : _s(v['file_name']),
      subtitleOf: (v) => _s(v['formatted_file_size']),
      imageOf: (v) => _s(v['file_url']),
      statusOf: (v) => v['is_active'] == true ? 'active' : 'inactive',
      fields: [
        DField('name', td('factory_images.image_name'), required: true, translated: true),
        DField('image', td('factory_images.image_file'), type: FT.image, required: true),
        DField('status', td('factory_images.status'), type: FT.select, options: [('active', 'factory_images.active'), ('inactive', 'factory_images.inactive')]),
      ],
    );

Widget bannersSection() => DashList(
      title: td('dashboard.banners'),
      path: '/banners',
      emptyText: td('dashboard.no_results'),
      addLabel: td('dashboard.banners'),
      editLabel: td('dashboard.banners'),
      confirmDelete: '?',
      savedMessage: '✓',
      deletedMessage: '✓',
      titleOf: (b) => _s(b['header']).isNotEmpty ? _s(b['header']) : 'Banner #${b['id']}',
      subtitleOf: (b) => '${_s(b['location'])} ${_s(b['locale'])}',
      imageOf: (b) => _s(b['mobile_image_url']).isNotEmpty ? _s(b['mobile_image_url']) : _s(b['website_image_url']),
      statusOf: (b) => b['is_active'] == true ? 'active' : 'inactive',
      fields: [
        const DField('locale', 'Locale', type: FT.select, options: [('ar', 'العربية'), ('en', 'English'), ('tr', 'Türkçe')]),
        const DField('type', 'Type', type: FT.select, options: [('image', 'Image')]),
        const DField('website_image_url', 'Website image', type: FT.image, fileField: 'website_image_url'),
        const DField('mobile_image_url', 'Mobile image', type: FT.image, fileField: 'mobile_image_url'),
        const DField('link_url', 'URL', type: FT.url),
        const DField('header', 'Header'),
        const DField('description', 'Description', type: FT.multiline),
        const DField('is_active', 'Active', type: FT.bool),
      ],
    );

Widget quoteRequestsSection() => DashList(
      title: td('dashboard.quote_requests'),
      path: '/quote-requests',
      emptyText: td('dashboard.no_quote_requests'),
      titleOf: (q) => _s(q['name']),
      subtitleOf: (q) => '${_s(q['phone'])} · ${_s(q['email'])}\n${_s(q['details'])}',
    );

Widget joinRequestsSection() => DashList(
      title: td('dashboard.customer_join_requests'),
      path: '/customer-join-requests',
      emptyText: td('dashboard.no_customer_join_requests'),
      titleOf: (q) => _s(q['name']),
      subtitleOf: (q) => '${_s(q['full_phone'])} · ${_s(q['email'])}\n${_s(q['message'])}',
    );

// ═════════════════════════════════ My factory ═════════════════════════════════

class MyFactorySection extends StatefulWidget {
  const MyFactorySection({super.key});

  @override
  State<MyFactorySection> createState() => _MyFactorySectionState();
}

class _MyFactorySectionState extends State<MyFactorySection> {
  Map<String, dynamic>? _f;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/my-factory'), allLocales: true);
      if (mounted) setState(() => _f = Map<String, dynamic>.from(r['data'] as Map));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  List<String> _ids(String key) => _f?[key] is List ? (_f![key] as List).map((e) => e is Map ? '${e['id']}' : '$e').toList() : [];

  /// One wizard step of the website's "Edit factory" page, shown as a tab.
  Widget _stepForm(int step, List<DField> fields, {Map<String, String> extra = const {}}) => DashForm(
        key: ValueKey('step$step-${_f.hashCode}'),
        title: '',
        path: '/my-factory',
        single: true,
        item: _f,
        fields: fields,
        savedMessage: td('factories.factory_updated'),
        extra: {'save_step': '$step', ...extra},
        multipart: true,
        embedded: true,
        onSaved: _load,
      );

  @override
  Widget build(BuildContext context) {
    final f = _f;
    final gateIds = _ids('gate_ids').isNotEmpty ? _ids('gate_ids') : _ids('gates');
    final catIds = _ids('category_ids').isNotEmpty ? _ids('category_ids') : _ids('categories');
    final oppIds = _ids('opportunity_ids').isNotEmpty ? _ids('opportunity_ids') : _ids('opportunities');
    final keep = <String, String>{
      for (var i = 0; i < gateIds.length; i++) 'gate_ids[$i]': gateIds[i],
      for (var i = 0; i < catIds.length; i++) 'category_ids[$i]': catIds[i],
      for (var i = 0; i < oppIds.length; i++) 'opportunity_ids[$i]': oppIds[i],
      // Other languages of the basic info are re-sent untouched (only the UI language is edited).
      for (final l in ['ar', 'en', 'tr'])
        if (l != L10n.i.lang)
          for (final k in ['name', 'short_description'])
            if (f?['${k}_$l'] is String && (f!['${k}_$l'] as String).isNotEmpty) '${k}_$l': f['${k}_$l'] as String,
    };
    final tabs = [
      '1. ${td('factories.info')}',
      '2. ${td('factories.about_us')}',
      '3. ${td('factories.factory_activities')}',
      '4. ${td('factories.address_details')}',
      '5. ${td('factories.catalog')}',
      '6. ${td('factories.team')}',
    ];
    return DashPage(
      title: td('factories.my_factory'),
      child: f == null
          ? (_error != null ? emptyState(_error!) : emptyState('', loading: true))
          : DefaultTabController(
              length: tabs.length,
              child: Column(children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.text,
                    unselectedLabelColor: AppColors.muted,
                    indicatorColor: AppColors.gold,
                    labelStyle: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 13.5, fontWeight: FontWeight.w600),
                    tabs: [for (final t in tabs) Tab(text: t)],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(children: [
                    // 1. Factory information (+ gates / categories / opportunities)
                    Column(children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GatesCategoriesSection())).then((_) => _load()),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            const Icon(Icons.account_tree_outlined, color: AppColors.gold),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${t('add_factory.gates_label', 'الأبواب')} / ${t('add_factory.categories_label', 'التصنيفات')}', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700))),
                            Icon(L10n.i.isRtl ? Icons.chevron_left : Icons.chevron_right, color: AppColors.muted),
                          ]),
                        ),
                      ),
                      Expanded(
                        child: _stepForm(1, [
                          DField('name', td('factories.factory_name'), required: true, translated: true),
                          DField('founded_year', td('factories.founded_year'), type: FT.number),
                          DField('country', td('factories.country'), type: FT.country),
                          DField('employees_count', td('factories.employees_count'), type: FT.number),
                          DField('nickname', td('factories.nickname')),
                          DField('short_description', td('factories.short_description'), type: FT.multiline, translated: true, maxLength: 90),
                          DField('logo', td('factories.logo'), type: FT.image),
                        ], extra: keep),
                      ),
                    ]),
                    // 2. About us
                    _stepForm(2, [DField('about', td('factories.about_us'), type: FT.multiline, required: true, translated: true)]),
                    // 3. Activities
                    _stepForm(3, [DField('activities', td('factories.factory_activities'), type: FT.lines, required: true)]),
                    // 4. Address / contact details
                    _stepForm(4, [
                      DField('working_hours_from', td('factories.working_hours_from'), hint: '09:00'),
                      DField('working_hours_to', td('factories.working_hours_to'), hint: '17:00'),
                      DField('phone', td('factories.phone')),
                      DField('email', td('factories.email'), type: FT.email),
                      DField('full_address', td('factories.full_address'), type: FT.multiline, translated: true),
                      DField('governorate', td('factories.address_details'), translated: true),
                    ]),
                    // 5. Catalog  /  6. Team
                    Column(children: [
                      if ((f['subscription_type'] ?? 'free') == 'free')
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFE082))),
                          child: Row(children: [
                            const Icon(Icons.lock_outline, size: 18, color: Color(0xFF7A5600)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(tri('يمكنك رفع الكتالوج الآن، لكنه لن يظهر في صفحة مصنعك إلا بعد ترقية الباقة.', 'Kataloğu şimdi yükleyebilirsiniz, ancak fabrika sayfanızda yalnızca planınızı yükselttikten sonra görünür.', 'You can upload the catalog now, but it will only appear on your factory page after you upgrade your plan.'), style: GoogleFonts.tajawal(fontSize: 12.5, color: const Color(0xFF7A5600), height: 1.6))),
                          ]),
                        ),
                      const Expanded(child: MediaStepSection(team: false, embedded: true)),
                    ]),
                    const MediaStepSection(team: true, embedded: true),
                  ]),
                ),
              ]),
            ),
    );
  }
}

// ═════════════════════════════════ Contact channels / theme / SEO ═════════════════════════════════

class ContactChannelsSection extends StatefulWidget {
  const ContactChannelsSection({super.key});

  @override
  State<ContactChannelsSection> createState() => _ContactChannelsSectionState();
}

class _ContactChannelsSectionState extends State<ContactChannelsSection> {
  final List<Map<String, dynamic>> _rows = [];
  final List<TextEditingController> _names = [];
  final List<TextEditingController> _urls = [];
  bool _loading = true;
  bool _saving = false;
  String? _capability;

  @override
  void initState() {
    super.initState();
    ApiClient.i.get(dp('/contact-channels')).then((r) {
      final d = r['data'];
      final list = d is Map ? ApiClient.list(d['channels']) : ApiClient.list(d);
      for (final c in list) {
        _add(c);
      }
    }).catchError((e) {
      if (e is ApiException && e.status == 403) _capability = e.capability;
    }).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _add([Map<String, dynamic>? c]) {
    setState(() {
      _rows.add(c ?? {});
      _names.add(TextEditingController(text: _s(c?['platform'] ?? c?['platform_ar'])));
      _urls.add(TextEditingController(text: _s(c?['url'])));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.i.post(dp('/contact-channels'), body: {
        'status': 'active',
        'channels': [
          for (var i = 0; i < _rows.length; i++)
            if (_names[i].text.trim().isNotEmpty) {if (_rows[i]['id'] != null) 'id': _rows[i]['id'], 'platform': _names[i].text.trim(), 'url': _urls[i].text.trim()},
        ],
      });
      if (mounted) showAppToast(context, '✅ ${td('contact_channels.saved_successfully')}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => DashPage(
        title: td('contact_channels.manage_channels'),
        child: _capability != null
            ? UpgradeNotice(capability: _capability)
            : _loading
                ? emptyState('', loading: true)
                : ListView(padding: const EdgeInsets.all(12), children: [
                    if (_rows.isEmpty) emptyState(td('contact_channels.no_channels')),
                    for (var i = 0; i < _rows.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          TextField(controller: _names[i], decoration: InputDecoration(labelText: td('contact_channels.platform_name'))),
                          TextField(controller: _urls[i], textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: td('contact_channels.platform_url'), hintText: td('contact_channels.enter_url'))),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: () async {
                                final id = _rows[i]['id'];
                                if (id != null) {
                                  try {
                                    await ApiClient.i.delete(dp('/contact-channels/$id'));
                                  } catch (_) {}
                                }
                                setState(() {
                                  _rows.removeAt(i);
                                  _names.removeAt(i);
                                  _urls.removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                              label: Text(td('contact_channels.remove'), style: GoogleFonts.tajawal(color: AppColors.red)),
                            ),
                          ),
                        ]),
                      ),
                    OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add, color: AppColors.gold), label: Text(td('contact_channels.add_channel'), style: GoogleFonts.tajawal(color: AppColors.text))),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(td('contact_channels.save'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
                  ]),
      );
}

class ThemeSection extends StatefulWidget {
  const ThemeSection({super.key});

  @override
  State<ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends State<ThemeSection> {
  final _bg = TextEditingController();
  final _title = TextEditingController();
  final _button = TextEditingController();
  List<Map<String, dynamic>> _themes = [];
  int? _theme;
  bool _loading = true;
  bool _saving = false;
  String? _capability;

  @override
  void initState() {
    super.initState();
    ApiClient.i.get(dp('/website-theme')).then((r) {
      final d = Map<String, dynamic>.from(r['data'] as Map);
      final c = Map<String, dynamic>.from(d['colors'] as Map);
      _bg.text = _s(c['background_color']);
      _title.text = _s(c['title_color']);
      _button.text = _s(c['button_color']);
      _themes = ApiClient.list(d['themes']);
      _theme = (d['selected_theme_id'] as num?)?.toInt();
    }).catchError((e) {
      if (e is ApiException && e.status == 403) _capability = e.capability;
    }).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Color _color(String hex) {
    final h = hex.replaceFirst('#', '');
    final n = h.length == 6 ? int.tryParse(h, radix: 16) : null;
    return n == null ? Colors.grey : Color(0xFF000000 | n);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.i.put(dp('/website-theme'), body: {'background_color': _bg.text.trim(), 'title_color': _title.text.trim(), 'button_color': _button.text.trim(), 'factory_theme_id': _theme});
      if (mounted) showAppToast(context, '✅ ${td('dashboard.website_theme_saved')}');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _colorField(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, onChanged: (_) => setState(() {}), textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: label, hintText: '#RRGGBB', suffixIcon: Container(margin: const EdgeInsets.all(10), width: 24, height: 24, decoration: BoxDecoration(color: _color(c.text), shape: BoxShape.circle, border: Border.all(color: AppColors.border))))),
      );

  @override
  Widget build(BuildContext context) => DashPage(
        title: td('dashboard.website_theme'),
        child: _capability != null
            ? UpgradeNotice(capability: _capability)
            : _loading
                ? emptyState('', loading: true)
                : ListView(padding: const EdgeInsets.all(14), children: [
                    Text(td('dashboard.website_colors'), style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    _colorField(td('dashboard.website_background_color'), _bg),
                    _colorField(td('dashboard.website_title_color'), _title),
                    _colorField(td('dashboard.website_button_color'), _button),
                    Text(td('dashboard.website_theme_preset'), style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      GestureDetector(onTap: () => setState(() => _theme = null), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _theme == null ? AppColors.gold : AppColors.border, width: 2)), child: Text(td('dashboard.website_no_theme'), style: GoogleFonts.tajawal(fontSize: 12.5)))),
                      for (final th in _themes)
                        GestureDetector(
                          onTap: () => setState(() => _theme = th['id'] as int),
                          child: Container(
                            width: 96,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _theme == th['id'] ? AppColors.gold : AppColors.border, width: 2)),
                            child: Column(children: [SizedBox(height: 70, width: 88, child: NetImage(url: _s(th['image_url']), fallback: '🎨', width: 88, height: 70)), Text(_s(th['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 11))]),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(td('dashboard.save'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.dark))),
                  ]),
      );
}

class SeoSection extends StatefulWidget {
  const SeoSection({super.key});

  @override
  State<SeoSection> createState() => _SeoSectionState();
}

class _SeoSectionState extends State<SeoSection> {
  Map<String, dynamic>? _seo;
  String? _capability;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiClient.i.get(dp('/seo')).then((r) {
      final d = r['data'];
      _seo = d is Map && d['seo'] is Map ? Map<String, dynamic>.from(d['seo'] as Map) : <String, dynamic>{};
    }).catchError((e) {
      if (e is ApiException && e.status == 403) _capability = e.capability;
    }).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_capability != null) return DashPage(title: td('dashboard.seo'), child: UpgradeNotice(capability: _capability));
    if (_loading) return DashPage(title: td('dashboard.seo'), child: emptyState('', loading: true));
    return DashForm(
      title: td('dashboard.seo'),
      path: '/seo',
      single: true,
      item: _seo,
      savedMessage: td('dashboard.seo_saved'),
      fields: [
        for (final l in ['ar', 'en', 'tr']) ...[
          DField('meta_title_$l', '${td('dashboard.seo_meta_title')} ($l)'),
          DField('meta_description_$l', '${td('dashboard.seo_meta_description')} ($l)', type: FT.multiline),
        ],
      ],
    );
  }
}

// ═════════════════════════════════ Chat ═════════════════════════════════

class DashChatSection extends StatelessWidget {
  const DashChatSection({super.key});

  @override
  Widget build(BuildContext context) => DashPage(title: td('dashboard.chat'), child: const DashChatBody());
}

/// Conversations of the factory's visitors; also used as the "Messages" tab of a factory account.
class DashChatBody extends StatefulWidget {
  const DashChatBody({super.key});

  @override
  State<DashChatBody> createState() => _DashChatSectionState();
}

class _DashChatSectionState extends State<DashChatBody> {
  Timer? _poll;

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _unread = {};
  bool _loading = true;
  String? _capability;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/chat'));
      _items = ApiClient.list(r['data']);
      final m = r['meta'];
      _unread = m is Map && m['unread_counts'] is Map ? Map<String, dynamic>.from(m['unread_counts'] as Map) : {};
    } on ApiException catch (e) {
      if (e.status == 403) _capability = e.capability;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const ChatAd(forFactory: true),
        Expanded(child: _body()),
      ]);

  Widget _body() => _capability != null
            ? UpgradeNotice(capability: _capability)
            : _loading
                ? emptyState('', loading: true)
                : _items.isEmpty
                    ? emptyState(td('dashboard.no_chat_conversations'))
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        for (final m in _items)
                          Builder(builder: (context) {
                            final other = (m['sender'] is Map && (m['sender'] as Map)['id'] != AuthService.i.userId) ? m['sender'] : m['receiver'];
                            final o = other is Map ? Map<String, dynamic>.from(other) : <String, dynamic>{};
                            final uid = _s(o['id']);
                            final n = (_unread[uid] as num?)?.toInt() ?? 0;
                            return GestureDetector(
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(factoryId: '', threadUserId: uid, name: _s(o['name']), avatar: _s(o['name']), color: AppColors.gold, logo: AppData.userImageUrl(o))));
                                _load();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                                child: Row(children: [
                                  netAvatar(AppData.userImageUrl(o), _s(o['name']), size: 42),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(_s(o['name']), style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                    Text(_s(m['message']), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.muted)),
                                  ])),
                                  if (n > 0) CircleAvatar(radius: 11, backgroundColor: AppColors.gold, child: Text('$n', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.dark))),
                                ]),
                              ),
                            );
                          }),
                      ]);
}

class DashThread extends StatefulWidget {
  final String userId;
  final String name;
  const DashThread({super.key, required this.userId, required this.name});

  @override
  State<DashThread> createState() => _DashThreadState();
}

class _DashThreadState extends State<DashThread> {
  List<Map<String, dynamic>> _msgs = [];
  final _ctrl = TextEditingController();
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/chat/${widget.userId}'), query: {'per_page': 100});
      final rows = ApiClient.list(r['data']);
      rows.sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
      _msgs = rows;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    try {
      await ApiClient.i.post(dp('/chat/${widget.userId}/messages'), body: {'message': txt});
      _ctrl.clear();
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) => DashPage(
        title: td('dashboard.chat_with', {'name': widget.name}),
        child: Column(children: [
          const ChatAd(forFactory: true),
          Expanded(
            child: _loading
                ? emptyState('', loading: true)
                : _msgs.isEmpty
                    ? emptyState(td('dashboard.no_chat_messages'))
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        for (final m in _msgs)
                          Align(
                            alignment: m['receiver_id'].toString() == widget.userId ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                              decoration: BoxDecoration(color: m['receiver_id'].toString() == widget.userId ? AppColors.gold : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                              child: m['type'] == 'image' && m['attachment_url'] is String
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${m['attachment_url']}', width: 200, fit: BoxFit.cover))
                                  : GestureDetector(
                                      onTap: m['attachment_url'] is String ? () => launchUrl(Uri.parse('${m['attachment_url']}'), mode: LaunchMode.externalApplication) : null,
                                      child: Text(_s(m['message']), style: GoogleFonts.tajawal(fontSize: 13.5, height: 1.5)),
                                    ),
                            ),
                          ),
                      ]),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(child: TextField(controller: _ctrl, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: td('dashboard.chat_type_message'), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22))))),
              const SizedBox(width: 8),
              GestureDetector(onTap: _send, child: const CircleAvatar(backgroundColor: AppColors.gold, child: Icon(Icons.send_rounded, size: 18, color: AppColors.dark))),
            ]),
          ),
        ]),
      );
}

// ═════════════════════════════════ RFQ offers ═════════════════════════════════

class RfqSection extends StatefulWidget {
  const RfqSection({super.key});

  @override
  State<RfqSection> createState() => _RfqSectionState();
}

class _RfqSectionState extends State<RfqSection> {
  List<Map<String, dynamic>> _open = [];
  List<Map<String, dynamic>> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.i.get(dp('/rfq-offers'));
      final d = r['data'];
      if (d is Map) {
        _open = ApiClient.list(d['open_rfqs']);
        _mine = ApiClient.list(d['my_offers']);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _offer(Map<String, dynamic> rfq) async {
    final price = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(td('dashboard.submit_offer'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: td('dashboard.price'))),
          TextField(controller: desc, maxLines: 3, decoration: InputDecoration(labelText: td('products.description'))),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(td('products.cancel'))), TextButton(onPressed: () => Navigator.pop(c, true), child: Text(td('dashboard.submit_offer')))],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.i.post(dp('/rfqs/${rfq['id']}/offers'), body: {'price': price.text.trim(), 'description_${L10n.i.lang}': desc.text.trim()});
      if (mounted) showAppToast(context, '✅ ${td('dashboard.rfq_offer_submitted')}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, '⚠️ ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) => DashPage(
        title: td('dashboard.rfqs'),
        child: _loading
            ? emptyState('', loading: true)
            : ListView(padding: const EdgeInsets.all(12), children: [
                Text(td('dashboard.open_rfqs'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
                if (_open.isEmpty) emptyState(td('dashboard.no_open_rfqs')),
                for (final r in _open)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_tr(r, 'title').isNotEmpty ? _tr(r, 'title') : '#${r['id']}', style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
                      if (_tr(r, 'description').isNotEmpty) Text(_tr(r, 'description'), style: GoogleFonts.tajawal(fontSize: 12.5, color: AppColors.muted)),
                      TextButton(onPressed: () => _offer(r), child: Text(td('dashboard.submit_offer'), style: GoogleFonts.tajawal(color: AppColors.gold, fontWeight: FontWeight.w800))),
                    ]),
                  ),
                const SizedBox(height: 16),
                Text(td('dashboard.my_rfq_offers'), style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800)),
                if (_mine.isEmpty) emptyState(td('dashboard.no_rfq_offers')),
                for (final o in _mine)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Text('${td('dashboard.price')}: ${_s(o['price'])}  ·  ${_s(o['status'])}', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                  ),
              ]),
      );
}
