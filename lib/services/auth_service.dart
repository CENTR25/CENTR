import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

/// Auth state
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

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

/// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _client;
  final SupabaseService _supabaseService;
  
  AuthNotifier(this._client, this._supabaseService) : super(const AuthState()) {
    _initialize();
  }
  
  void _initialize() {
    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _loadUserProfile(session.user.id);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
    
    // Check for existing session
    final session = _client.auth.currentSession;
    if (session != null) {
      _loadUserProfile(session.user.id);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
  
  Future<void> _loadUserProfile(String userId) async {
    try {
      debugPrint('👤 LoadProfile: Cargando perfil para $userId');
      state = state.copyWith(status: AuthStatus.loading);
      
      final profile = await _supabaseService.getProfile(userId);
      debugPrint('👤 LoadProfile: Perfil obtenido: $profile');
      
      if (profile != null) {
        final user = UserModel.fromJson(profile);
        debugPrint('👤 LoadProfile: Usuario parseado: ${user.email}, rol: ${user.role}');
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
            ? UserModel.fromJson(updatedProfile) 
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
          'role': 'athlete', // Default role
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        final newProfile = await _supabaseService.getProfile(userId);
        if (newProfile != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: UserModel.fromJson(newProfile),
            isFirstLogin: true,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('💥 LoadProfile: Error: $e');
      debugPrint('💥 LoadProfile: Stack: $stack');
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
          await _supabaseService.updateInvitationStatus(invitationId, 'accepted');
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
    try {
      await _client.auth.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error al cerrar sesión');
    }
  }
  
  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
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
