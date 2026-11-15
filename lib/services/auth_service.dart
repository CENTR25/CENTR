import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';
import 'workout_draft_service.dart';

/// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// Auth state class
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final bool isFirstLogin;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isFirstLogin = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? isFirstLogin,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
    );
  }
}

/// "A password-recovery link was verified but no new password set yet."
///
/// Static (not per-[AuthNotifier]) because verifying the link swaps the
/// session user, which re-keys the root ProviderScope and builds a brand-new
/// AuthNotifier; and persisted (SharedPreferences = localStorage on web) so a
/// reload mid-flow can't escape the reset screen into the app with the
/// password-less recovery session. [load] must run before `runApp` so the
/// router's synchronous redirect can read [pending].
class PasswordRecoveryFlag {
  static const _key = 'pw_recovery_pending';
  static bool _pending = false;
  static bool get pending => _pending;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pending = prefs.getBool(_key) ?? false;
    } catch (e) {
      debugPrint('PasswordRecoveryFlag.load: $e');
    }
  }

  /// Updates the in-memory value synchronously, then persists it.
  static Future<void> set(bool value) async {
    if (_pending == value) return;
    _pending = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(_key, true);
      } else {
        await prefs.remove(_key);
      }
    } catch (e) {
      debugPrint('PasswordRecoveryFlag.set: $e');
    }
  }
}

/// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _client;
  final SupabaseService _supabaseService;

  AuthNotifier(this._client, this._supabaseService) : super(const AuthState()) {
    _initialize();
  }

  /// True after a password-recovery link was verified and no new password has
  /// been set yet. The router pins such a session to the reset-password screen
  /// so the recovery link can't be used as a password-less login into the app.
  bool get isPasswordRecovery => PasswordRecoveryFlag.pending;

  void _initialize() {
    // Listen to auth state changes.
    // Skip a full profile reload on TOKEN_REFRESHED when we already have a
    // hydrated authenticated state — a token refresh does not change the user
    // profile and the reload would briefly set AuthStatus.loading, which (with
    // GoRouter's refreshListenable) used to flash the loading screen on every
    // background session renewal and on iOS swipe-back navigation.
    _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        PasswordRecoveryFlag.set(true);
      }
      if (session != null) {
        final alreadyAuthenticated =
            state.status == AuthStatus.authenticated && state.user != null;
        final isTokenRefresh =
            data.event == AuthChangeEvent.tokenRefreshed;
        if (alreadyAuthenticated && isTokenRefresh) return;
        await _loadUserProfile(session.user.id);
      } else {
        PasswordRecoveryFlag.set(false);
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }, onError: (Object e) {
      // e.g. an invalid auth callback in the URL is pushed on this stream as
      // an AuthException; without a handler it surfaces as an uncaught error.
      debugPrint('Auth stream error: $e');
    });

    // Check for existing session
    final session = _client.auth.currentSession;
    if (session != null) {
      _loadUserProfile(session.user.id);
    } else {
      // No session: a leftover recovery flag (e.g. session expired) is moot.
      PasswordRecoveryFlag.set(false);
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      debugPrint('👤 LoadProfile: Cargando perfil para $userId');
      state = state.copyWith(status: AuthStatus.loading);

      final authUser = _client.auth.currentUser;
      final profile = await _supabaseService.getProfile(userId);
      debugPrint('👤 LoadProfile: Perfil obtenido: $profile');

      if (profile != null) {
        final enrichedProfile = _enrichProfile(profile, authUser);
        final user = UserModel.fromJson(enrichedProfile);
        debugPrint(
          '👤 LoadProfile: Usuario parseado: ${user.email}, rol: ${user.role}',
        );
        final isFirstLogin = user.firstLoginAt == null;

        // Record first login if applicable
        if (isFirstLogin) {
          debugPrint('👤 LoadProfile: Es primer login, registrando...');
          await _supabaseService.recordFirstLogin(userId);
        } else {
          await _supabaseService.updateLastLogin(userId);
        }

        // Reload profile after updates
        final updatedProfile = await _supabaseService.getProfile(userId);
        final updatedUser = updatedProfile != null
            ? UserModel.fromJson(_enrichProfile(updatedProfile, authUser))
            : user;

        debugPrint('✅ LoadProfile: Autenticado como ${updatedUser.role}');
        state = AuthState(
          status: AuthStatus.authenticated,
          user: updatedUser,
          isFirstLogin: isFirstLogin,
        );
      } else {
        debugPrint('⚠️ LoadProfile: Perfil no existe, creando...');
        // Profile doesn't exist yet, create it
        final authUser = _client.auth.currentUser!;
        await _supabaseService.upsertProfile({
          'id': userId,
          'email': authUser.email,
          'name': UserModel.resolveName({
            'user_metadata': authUser.userMetadata,
          }),
          'role': 'student', // Default role
          'is_active': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        final newProfile = await _supabaseService.getProfile(userId);
        if (newProfile != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: UserModel.fromJson(_enrichProfile(newProfile, authUser)),
            isFirstLogin: true,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('💥 LoadProfile: Error: $e');
      debugPrint('💥 LoadProfile: Stack: $stack');

      // A valid Auth session should not be sent back to /login only because
      // the profile query failed temporarily or an old profile row is
      // missing. Keep the user in the app with the Auth metadata as a
      // temporary profile and let the next refresh hydrate the database data.
      final authUser = _client.auth.currentUser;
      if (authUser != null && authUser.id == userId) {
        final fallbackProfile = _enrichProfile({
          'id': userId,
          'email': authUser.email ?? '',
          'role': authUser.userMetadata?['role'] ?? 'student',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        }, authUser);

        state = AuthState(
          status: AuthStatus.authenticated,
          user: UserModel.fromJson(fallbackProfile),
        );
        return;
      }

      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    try {
      debugPrint('🔑 AuthService: Iniciando login...');
      state = state.copyWith(status: AuthStatus.loading);

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ AuthService: Login exitoso, user: ${response.user?.email}');
      debugPrint('📦 AuthService: Session: ${response.session != null}');

      // Profile loading is handled by auth state listener
    } on AuthException catch (e) {
      debugPrint('❌ AuthService: AuthException: ${e.message}');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _getAuthErrorMessage(e),
      );
    } catch (e) {
      debugPrint('💥 AuthService: Exception: $e');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Error al iniciar sesión. Intenta de nuevo.',
      );
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? invitationId,
  }) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user != null) {
        // If there's an invitation, update its status
        if (invitationId != null) {
          await _supabaseService.updateInvitationStatus(
            invitationId,
            'accepted',
          );
        }
      }
      // Profile creation is handled by auth state listener
    } on AuthException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _getAuthErrorMessage(e),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Error al registrarse. Intenta de nuevo.',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // gotrue clears the local session and emits `signedOut` BEFORE it fires
    // the network `/logout` request. On web that request can fail with a
    // non-AuthException (e.g. a CORS/network `ClientException`) which gotrue
    // does not catch and rethrows — but by then the user is already signed out
    // locally. So a failed logout call must never keep us authenticated:
    // swallow any error and always force the unauthenticated state so the
    // router redirects to /login.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('signOut: ignoring error from auth.signOut: $e');
    }
    // Drop any local workout drafts so they can't surface for the next
    // account on a shared device.
    try {
      await WorkoutDraftService().clearAll();
    } catch (e) {
      debugPrint('signOut: ignoring error clearing drafts: $e');
    }
    await PasswordRecoveryFlag.set(false);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Change password for the signed-in user.
  ///
  /// Verifies [currentPassword] by re-authenticating first (Supabase
  /// `updateUser` does not require the old password, so this is our own guard),
  /// then updates to [newPassword]. Returns `null` on success, or a
  /// user-facing Spanish error message on failure. The session stays active.
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) return 'No hay una sesión activa.';

    // 1. Verify the current password by re-authenticating.
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      return 'La contraseña actual no es correcta.';
    } catch (_) {
      return 'No se pudo verificar la contraseña actual.';
    }

    // 2. Update to the new password.
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return _getAuthErrorMessage(e);
    } catch (_) {
      return 'No se pudo actualizar la contraseña. Intenta de nuevo.';
    }
  }

  /// Send the password-recovery email.
  ///
  /// The email template links to `/reset-password?token_hash=…&type=recovery`
  /// on the web app (on mobile too: the native apps have no deep-link scheme,
  /// so the reset is done in the browser and the user then signs in on the
  /// app with the new password). `redirectTo` is pinned to the production URL
  /// so preview `*.pages.dev` origins never end up in the email.
  ///
  /// Returns a user-facing error ONLY for a network failure (the request never
  /// reached Supabase). Every server response — success, unknown email, 429 /
  /// per-address rate limit, SMTP error — is reported as success so the UI
  /// never reveals whether an email is registered.
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: AppConstants.resetPasswordUrl,
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint('resetPassword: ${e.statusCode} ${e.message}');
      // statusCode == null: fetch itself failed (offline / DNS / CORS).
      if (e.statusCode == null) {
        return 'No se pudo conectar. Revisá tu conexión e intentá de nuevo.';
      }
    } catch (e) {
      debugPrint('resetPassword: $e');
    }
    return null;
  }

  /// Verify a recovery link's `token_hash` (a client-side POST, so email link
  /// scanners that prefetch the GET link can't consume it). On success the
  /// client holds a recovery session and the recovery flag is set; returns
  /// false for an invalid / expired / already-used link.
  Future<bool> verifyRecoveryToken(String tokenHash) async {
    // Set the flag BEFORE the session appears: verifyOTP emits the auth events
    // (which re-key the app and re-run the router) before it returns.
    await PasswordRecoveryFlag.set(true);
    try {
      await _client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.recovery,
      );
      return true;
    } catch (e) {
      debugPrint('verifyRecoveryToken: $e');
      await PasswordRecoveryFlag.set(false);
      return false;
    }
  }

  /// Set the new password for a session opened from a recovery link.
  /// Returns `null` on success or a Spanish error message.
  Future<String?> completePasswordRecovery(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      if (e.message.contains('different from the old password')) {
        return 'La nueva contraseña debe ser distinta de la anterior.';
      }
      if (e.message.contains('Password should be')) {
        return 'La contraseña debe tener al menos 6 caracteres.';
      }
      return _getAuthErrorMessage(e);
    } catch (_) {
      return 'No se pudo actualizar la contraseña. Intenta de nuevo.';
    }
    await PasswordRecoveryFlag.set(false);
    // Emit a new state so the router re-runs its redirect and leaves the
    // reset screen for the user's dashboard.
    state = state.copyWith();
    return null;
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Refresh user profile from database
  Future<void> refreshProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await _supabaseService.getProfile(userId);
      if (profile != null) {
        final user = UserModel.fromJson(
          _enrichProfile(profile, _client.auth.currentUser),
        );
        state = state.copyWith(user: user);
        debugPrint(
          '🔄 RefreshProfile: Perfil actualizado, hasCompletedOnboarding: ${user.hasCompletedOnboarding}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ RefreshProfile: Error: $e');
    }
  }

  Map<String, dynamic> _enrichProfile(
    Map<String, dynamic> profile,
    User? authUser,
  ) {
    final enriched = Map<String, dynamic>.from(profile);
    final metadata = authUser?.userMetadata;

    if (metadata != null && metadata.isNotEmpty) {
      enriched['user_metadata'] = metadata;
    }
    if ((enriched['email'] as String?)?.trim().isEmpty != false) {
      enriched['email'] = authUser?.email ?? '';
    }
    if (UserModel.resolveName(enriched) == null && metadata != null) {
      final metadataName = UserModel.resolveName({'user_metadata': metadata});
      if (metadataName != null) enriched['name'] = metadataName;
    }
    if ((enriched['role'] as String?)?.trim().isEmpty != false &&
        metadata?['role'] != null) {
      enriched['role'] = metadata!['role'];
    }

    return enriched;
  }

  /// Get localized auth error message
  String _getAuthErrorMessage(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'Credenciales inválidas. Verifica tu email y contraseña.';
      case 'User already registered':
        return 'Este correo ya está registrado.';
      case 'Email not confirmed':
        return 'Por favor confirma tu correo electrónico.';
      default:
        return e.message;
    }
  }
}

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthNotifier(client, supabaseService);
});

/// Provider for current user
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

/// Provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
