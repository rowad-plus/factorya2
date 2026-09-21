import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'widgets/country_gate.dart';
import 'widgets/shell_widgets.dart';
import 'services/l10n.dart';
import 'widgets/common_widgets.dart';
import 'screens/home/home_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/gate/gate_screen.dart';
import 'screens/companies/companies_screen.dart';
import 'screens/factory_profile/factory_profile_screen.dart';
import 'screens/product_detail/product_detail_screen.dart';
import 'screens/opportunities/opportunities_screen.dart';
import 'screens/opportunities/opportunity_detail_screen.dart';
import 'screens/opportunities/request_detail_screen.dart';
import 'screens/content/site_pages.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/factory_profile/add_factory_screen.dart';
import 'screens/content/site_lists.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/subscription/subscription_screen.dart';
import 'screens/timeline/create_post_screen.dart';
import 'screens/opportunities/create_opportunity_screen.dart';
import 'data/app_data.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'widgets/async_loader.dart';
import 'screens/auth/login_modal.dart';
import 'models/factory_model.dart';
import 'models/product_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0E0E0E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await L10n.i.load();
  // Open immediately; screens rebuild when AppData.revision changes.
  AuthService.i.restore().then((_) {
    if (AuthService.i.isLoggedIn) AppData.loadUserData();
  });
  AppData.load();
  AuthService.i.addListener(() {
    if (AuthService.i.isLoggedIn) {
      AppData.loadUserData();
    } else {
      AppData.clearUserData();
    }
  });
  runApp(const FactoryaApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
        GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
    GoRoute(
      path: '/gate/:id',
      builder: (_, s) {
        final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
        if (AppData.doors.isEmpty) return const _NotFound('لا توجد أقسام متاحة حالياً');
        final door = AppData.doors[id.clamp(0, AppData.doors.length - 1)];
        return GateScreen(door: door);
      },
    ),
    GoRoute(
      path: '/companies',
      builder: (_, s) => CompaniesScreen(
        initialSearch: s.uri.queryParameters['search'],
        opportunityId: int.tryParse(s.uri.queryParameters['opportunity_id'] ?? ''),
        title: s.uri.queryParameters['title'],
      ),
    ),
    GoRoute(path: '/factory/create', builder: (_, __) => const AddFactoryScreen()),
    GoRoute(
      path: '/factory/:id',
      builder: (_, s) {
        final id = s.pathParameters['id'] ?? '0';
        final cached = AppData.factories.where((f) => f.id == id);
        if (cached.isNotEmpty) return FactoryProfileScreen(factory: cached.first);
        return AsyncLoader<FactoryModel>(
          load: () => AppData.fetchFactory(id),
          builder: (_, f) => FactoryProfileScreen(factory: f),
        );
      },
    ),
    GoRoute(
      path: '/product/:id',
      builder: (_, s) {
        final id = s.pathParameters['id'] ?? '0';
        return _withProduct(id, (p) => ProductDetailScreen(product: p));
      },
    ),
    GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
    GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
    GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
    GoRoute(path: '/prices', builder: (_, __) => const PricesScreen()),
    GoRoute(path: '/opportunities', builder: (_, __) => const OpportunitiesScreen()),
    GoRoute(path: '/opportunity-requests', builder: (_, __) => const OpportunitiesScreen()),
    GoRoute(path: '/opportunity-requests/:id', builder: (_, s) => RequestDetailScreen(id: s.pathParameters['id'] ?? '0')),
    GoRoute(
      path: '/opportunity/:id',
      builder: (_, s) {
        final id = s.pathParameters['id'] ?? '0';
        final found = AppData.opportunities.where((o) => o.id == id);
        if (found.isEmpty) return const _NotFound('الفرصة غير متاحة');
        return OpportunityDetailScreen(opp: found.first);
      },
    ),
    GoRoute(path: '/chat', builder: (_, __) => const ChatListScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/profile/orders', builder: (_, __) => const OrdersScreen()),
    GoRoute(path: '/profile/my-requests', builder: (_, __) => const MyRequestsScreen()),
    GoRoute(path: '/profile/activity-log', builder: (_, __) => const ActivityLogScreen()),
    GoRoute(path: '/profile/:id', builder: (_, s) => ProfileScreen(userId: s.pathParameters['id'])),
    GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
    GoRoute(path: '/sponsors', builder: (_, __) => const SponsorsScreen()),
    GoRoute(path: '/exhibitions', builder: (_, __) => const ExhibitionsScreen()),
    GoRoute(path: '/blog', builder: (_, __) => const BlogScreen()),
    GoRoute(path: '/blog/:id', builder: (_, s) => BlogDetailScreen(id: s.pathParameters['id'] ?? '0')),
    GoRoute(path: '/jobs', builder: (_, __) => const JobsScreen()),
    GoRoute(path: '/cvs', builder: (_, __) => const CvsScreen()),
    GoRoute(path: '/create-post', builder: (_, __) => const CreatePostScreen()),
    GoRoute(path: '/create-opportunity', builder: (_, __) => const CreateOpportunityScreen()),
      ],
    ),
  ],
);

/// Resolves a product from the loaded list, or fetches it by id.
Widget _withProduct(String id, Widget Function(ProductModel) build) {
  final cached = AppData.products.where((p) => p.id == id);
  if (cached.isNotEmpty) return build(cached.first);
  return AsyncLoader<ProductModel>(
    load: () async {
      final res = await ApiClient.i.get('/products/$id');
      return AppData.productFromJson(Map<String, dynamic>.from(res['data'] as Map));
    },
    builder: (_, p) => build(p),
  );
}

class _NotFound extends StatelessWidget {
  final String message;
  const _NotFound(this.message);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.dark, foregroundColor: Colors.white, elevation: 0),
        body: Center(child: Text(message, style: GoogleFonts.tajawal(fontSize: 14, color: AppColors.muted))),
      );
}

class FactoryaApp extends StatelessWidget {
  const FactoryaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.i,
      builder: (context, _) {
        final dir = L10n.i.isRtl ? TextDirection.rtl : TextDirection.ltr;
        return Directionality(
          textDirection: dir,
          child: MaterialApp.router(
            title: 'فاكتوريا',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            routerConfig: _router,
            locale: Locale(L10n.i.lang),
            // Allow mouse/trackpad drag scrolling (web and desktop previews).
            scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus}),
            builder: (context, child) => Directionality(
              textDirection: dir,
              // Phone-sized column on wide screens (web/desktop).
              child: ColoredBox(
                color: const Color(0xFF0E0E0E),
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Widget get child => widget.child;

  @override
  void initState() {
    super.initState();
    AppData.revision.addListener(_maybeAskCountry);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskCountry());
  }

  @override
  void dispose() {
    AppData.revision.removeListener(_maybeAskCountry);
    super.dispose();
  }

  void _maybeAskCountry() {
    if (mounted && AppData.loaded && AppData.needsCountry) CountryGate.showIfNeeded(context);
  }

  static const _routes = ['/', '/categories', '/chat'];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = loc == '/' ? 0 : (loc == '/categories' ? 1 : (loc == '/chat' ? 2 : -1));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const AppHeader(),
          // The header and bottom bar already cover the system insets: pages inside must not add them again.
          Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, child: child)),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) {
          if (i == 3) {
            MoreSheet.show(context);
          } else {
            context.go(_routes[i]);
          }
        },
      ),
    );
  }
}
