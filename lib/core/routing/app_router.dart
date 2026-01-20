import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:north_star/services/auth_service.dart';
import 'package:north_star/models/user_model.dart';
import 'package:north_star/features/auth/presentation/login_screen.dart';
import 'package:north_star/features/auth/presentation/first_login_screen.dart';
import 'package:north_star/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:north_star/features/trainer/trainer_dashboard_screen.dart';
import 'package:north_star/features/student/student_dashboard_screen.dart';
import 'package:north_star/features/student/student_onboarding_screen.dart';
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
  static const String studentRoutine = '/student/routine';
  static const String studentProgress = '/student/progress';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  // Use read instead of watch to avoid rebuilding GoRouter on auth changes
  final authNotifier = ref.read(authProvider.notifier);
  
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    // Use refreshListenable to trigger redirects on auth state changes
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      // Read current state from provider directly
      // We rely on refreshListenable to trigger this callback
      final authState = ref.read(authProvider);
      
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isLoading = authState.status == AuthStatus.loading || 
                        authState.status == AuthStatus.initial;
      final isLoginRoute = state.matchedLocation == AppRoutes.login ||
                           state.matchedLocation == AppRoutes.register ||
                           state.matchedLocation == AppRoutes.forgotPassword;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      
      // Show loading/splash while checking auth
      if (isLoading) {
        if (isSplash) return null;
        // If we are already on a loading screen or acceptable initial screen, stay there
        return null;
      }
      
      // Not authenticated
      if (!isAuthenticated) {
        if (isLoginRoute) {
          return null;
        }
        return AppRoutes.login;
      }
      
      // Authenticated - redirect to role-based dashboard if on auth/splash pages
      if (isLoginRoute || isSplash) {
        if (authState.user?.role == UserRole.student && authState.user?.hasCompletedOnboarding == false) {
          return AppRoutes.studentOnboarding;
        }
        return _getDashboardRoute(authState.user?.role);
      }
      
      // Enforce onboarding for students
      if (isAuthenticated && authState.user?.role == UserRole.student && 
          authState.user?.hasCompletedOnboarding == false && 
          state.matchedLocation != AppRoutes.studentOnboarding) {
        return AppRoutes.studentOnboarding;
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
        builder: (context, state) => const LoginScreen(), // Or RegisterScreen if separate
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const LoginScreen(), // Or ForgotPasswordScreen
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
