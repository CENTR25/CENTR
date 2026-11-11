import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/routing/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/swipe_back_handler_stub.dart'
    if (dart.library.html) 'core/swipe_back_handler_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  initSwipeBackHandler(() => rootNavigatorKey.currentState?.maybePop());
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  runApp(const AuthScopedApp());
}

/// Rebuilds the entire Riverpod container whenever the authenticated user
/// changes (login, user switch, or logout).
///
/// Riverpod keeps non-`autoDispose` providers alive for the lifetime of their
/// `ProviderScope`, and resolves all non-overridden providers in the ROOT
/// container — so a nested scope can't reset them. Keying the root scope by the
/// auth user id means that on any user change Flutter disposes the whole
/// container and builds a fresh one, guaranteeing that cached data fetched for
/// the previous user (rosters, finances, routines, PII) can never be shown to
/// the next user who logs in on the same tab/device. This is the cross-user
/// data-leak guard for a client cache that server-side RLS does not cover.
class AuthScopedApp extends StatefulWidget {
  const AuthScopedApp({super.key});

  @override
  State<AuthScopedApp> createState() => _AuthScopedAppState();
}

class _AuthScopedAppState extends State<AuthScopedApp> {
  static const _anon = 'anon';
  late String _scopeKey;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _scopeKey = Supabase.instance.client.auth.currentUser?.id ?? _anon;
    // Listen to auth directly (not via Riverpod) — this widget sits ABOVE the
    // ProviderScope it keys, so it can't read providers. Only re-key on an
    // actual user-identity change; a token refresh keeps the same id (and the
    // same scope), avoiding a needless full-app rebuild.
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final nextKey = data.session?.user.id ?? _anon;
      if (nextKey != _scopeKey && mounted) {
        setState(() => _scopeKey = nextKey);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey(_scopeKey),
      child: const NorthStarApp(),
    );
  }
}

class NorthStarApp extends ConsumerWidget {
  const NorthStarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
