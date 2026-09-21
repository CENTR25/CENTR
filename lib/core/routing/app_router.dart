import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:north_star/services/auth_service.dart';
import 'package:north_star/models/user_model.dart';
import 'package:north_star/features/auth/presentation/login_screen.dart';
import 'package:north_star/features/auth/presentation/first_login_screen.dart';
import 'package:north_star/features/auth/presentation/student_register_screen.dart';
import 'package:north_star/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:north_star/features/trainer/trainer_dashboard_screen.dart';
import 'package:north_star/features/student/student_dashboard_screen.dart';
import 'package:north_star/features/student/student_onboarding_screen.dart';
import 'package:north_star/features/student/student_intake_screen.dart';
import 'package:north_star/features/shared/widgets/loading_screen.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String firstLogin = '/first-login';

  // Admin routes
  static const String adminDashboard = '/admin';
  static const String adminTrainers = '/admin/trainers';
  static const String adminTrainerDetail = '/admin/trainers/:id';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminNotifications = '/admin/notifications';

  // Trainer routes
  static const String trainerDashboard = '/trainer';
  static const String trainerStudents = '/trainer/students';
  static const String trainerRoutines = '/trainer/routines';

  // Student routes
  static const String studentDashboard = '/student';
  static const String studentOnboarding = '/student/onboarding';
  static const String studentIntake = '/student/intake';
  static const String studentRoutine = '/student/routine';
  static const String studentProgress = '/student/progress';
}

/// Root navigator key — used by the web swipe-back handler to pop
/// Navigator.push'd screens when the browser back gesture is trapped.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  // Use read instead of watch to avoid rebuilding GoRouter on auth changes
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // Replace (never push) browser history entries on web. Auth-flow
    // redirects were pushing stale splash/login entries; iOS swipe-back then
    // revealed their Safari snapshots — seen as a loading-screen flash.
    routerNeglect: true,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    // Use refreshListenable to trigger redirects on auth state changes
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      // Read current state from provider directly
      // We rely on refreshListenable to trigger this callback
      final authState = ref.read(authProvider);

      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isLoading =
          authState.status == AuthStatus.loading ||
          authState.status == AuthStatus.initial;
      final isProfileLoading = isAuthenticated && authState.user == null;
      final isLoginRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.firstLogin;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      // While auth is resolving (initial load, sign-in, or Supabase background
      // token refresh) stay on the current route. On first launch the initial
      // location is '/' (splash) so the user naturally waits there. If auth
      // resolves while the user is already inside the app we must not redirect
      // them away — doing so causes the swipe-back loading-screen flash.
      if (isLoading || isProfileLoading) return null;

      // Not authenticated
      if (!isAuthenticated) {
        if (isLoginRoute) {
          return null;
        }
        return AppRoutes.login;
      }

      // Authenticated - redirect to role-based dashboard if on auth/splash pages
      if (isLoginRoute || isSplash) {
        final studentSetup = _studentSetupRoute(authState.user);
        if (studentSetup != null) return studentSetup;
        return _getDashboardRoute(authState.user?.role);
      }

      // Enforce the student setup flow (onboarding, then the intake form)
      // before letting students into the rest of the app.
      final studentSetup = _studentSetupRoute(authState.user);
      if (studentSetup != null &&
          state.matchedLocation != studentSetup) {
        return studentSetup;
      }

      return null;
    },
    routes: [
      // Splash/Loading
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const LoadingScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) {
          final trainerId = state.uri.queryParameters['trainer'];
          return StudentRegisterScreen(trainerId: trainerId);
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) =>
            const LoginScreen(), // ForgotPasswordScreen not yet implemented
      ),

      // First login (invitation)
      GoRoute(
        path: AppRoutes.firstLogin,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return FirstLoginScreen(token: token);
        },
      ),

      // Admin routes
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Trainer routes
      GoRoute(
        path: AppRoutes.trainerDashboard,
        builder: (context, state) => const TrainerDashboardScreen(),
      ),

      // Student routes
      GoRoute(
        path: AppRoutes.studentDashboard,
        builder: (context, state) => const StudentDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentOnboarding,
        builder: (context, state) => const StudentOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentIntake,
        builder: (context, state) => const StudentIntakeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Página no encontrada: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// A class that converts a stream to a Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// The required setup step a student must complete before entering the app:
/// first the onboarding, then the intake questionnaire. Returns null when the
/// user is not a student or has finished both (or is unresolved).
String? _studentSetupRoute(UserModel? user) {
  if (user == null || user.role != UserRole.student) return null;
  if (!user.hasCompletedOnboarding) return AppRoutes.studentOnboarding;
  if (!user.hasCompletedIntake) return AppRoutes.studentIntake;
  return null;
}

/// Get dashboard route based on user role
String _getDashboardRoute(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return AppRoutes.adminDashboard;
    case UserRole.trainer:
      return AppRoutes.trainerDashboard;
    case UserRole.student:
      return AppRoutes.studentDashboard;
    default:
      return AppRoutes.login;
  }
}
