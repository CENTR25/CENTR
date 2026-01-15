import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Supabase service for database operations
class SupabaseService {
  final SupabaseClient _client;
  
  SupabaseService(this._client);
  
  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;
  
  /// Get current session
  Session? get currentSession => _client.auth.currentSession;
  
  // ==================== PROFILES ====================
  
  /// Get user profile by ID
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }
  
  /// Create or update profile
  Future<void> upsertProfile(Map<String, dynamic> profile) async {
    await _client.from('profiles').upsert(profile);
  }
  
  /// Update profile field
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }
  
  /// Record first login and notify admin
  Future<void> recordFirstLogin(String userId) async {
    final now = DateTime.now().toIso8601String();
    
    // Update user's first login time
    await _client.from('profiles').update({
      'first_login_at': now,
      'last_login_at': now,
    }).eq('id', userId);
    
    // Get user details for notification
    final profile = await getProfile(userId);
    if (profile != null) {
      final trainerId = profile['trainer_id'] as String?;
      if (trainerId != null) {
        // Notify the trainer about student's first login
        await createNotification(
          userId: trainerId,
          type: 'firstLogin',
          title: '¡Nuevo alumno activo!',
          message: '${profile['name'] ?? profile['email']} ha iniciado sesión por primera vez.',
          data: {'student_id': userId},
        );
      }
      
      // Also notify admins
      final admins = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'admin');
      
      for (final admin in admins) {
        await createNotification(
          userId: admin['id'] as String,
          type: 'firstLogin',
          title: 'Usuario activo',
          message: '${profile['name'] ?? profile['email']} ha ingresado por primera vez.',
          data: {'user_id': userId},
        );
      }
    }
  }
  
  /// Update last login time
  Future<void> updateLastLogin(String userId) async {
    await _client.from('profiles').update({
      'last_login_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
  
  // ==================== TRAINERS ====================
  
  /// Get all trainers
  Future<List<Map<String, dynamic>>> getTrainers() async {
    final response = await _client
        .from('trainers')
        .select('*, profiles(*), subscriptions(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get trainer by ID
  Future<Map<String, dynamic>?> getTrainer(String trainerId) async {
    final response = await _client
        .from('trainers')
        .select('*, profiles(*), subscriptions(*)')
        .eq('id', trainerId)
        .maybeSingle();
    return response;
  }
  
  /// Create trainer
  Future<void> createTrainer(Map<String, dynamic> trainer) async {
    await _client.from('trainers').insert(trainer);
  }
  
  /// Update trainer
  Future<void> updateTrainer(String trainerId, Map<String, dynamic> updates) async {
    await _client.from('trainers').update(updates).eq('id', trainerId);
  }
  
  /// Delete trainer
  Future<void> deleteTrainer(String trainerId) async {
    await _client.from('trainers').delete().eq('id', trainerId);
  }
  
  /// Get students count for trainer
  Future<int> getStudentCount(String trainerId) async {
    final response = await _client
        .from('profiles')
        .select('id')
        .eq('trainer_id', trainerId)
        .eq('role', 'student');
    return response.length;
  }
  
  // ==================== SUBSCRIPTIONS ====================
  
  /// Get subscription for trainer
  Future<Map<String, dynamic>?> getSubscription(String trainerId) async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('trainer_id', trainerId)
        .eq('status', 'active')
        .maybeSingle();
    return response;
  }
  
  /// Create subscription
  Future<void> createSubscription(Map<String, dynamic> subscription) async {
    await _client.from('subscriptions').insert(subscription);
  }
  
  /// Update subscription status
  Future<void> updateSubscriptionStatus(String subscriptionId, String status) async {
    await _client.from('subscriptions').update({
      'status': status,
    }).eq('id', subscriptionId);
  }
  
  // ==================== NOTIFICATIONS ====================
  
  /// Create notification
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Get notifications for user
  Future<List<Map<String, dynamic>>> getNotifications(String userId, {int limit = 50}) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get unread notifications count
  Future<int> getUnreadNotificationCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return response.length;
  }
  
  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _client.from('notifications').update({
      'is_read': true,
    }).eq('id', notificationId);
  }
  
  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    await _client.from('notifications').update({
      'is_read': true,
    }).eq('user_id', userId);
  }
  
  // ==================== INVITATIONS ====================
  
  /// Create invitation link for a user
  Future<Map<String, dynamic>> createInvitation({
    required String email,
    required String role,
    String? trainerId,
  }) async {
    final response = await _client.from('invitations').insert({
      'email': email,
      'role': role,
      'trainer_id': trainerId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    }).select().single();
    return response;
  }
  
  /// Get pending invitations
  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    final response = await _client
        .from('invitations')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Update invitation status
  Future<void> updateInvitationStatus(String invitationId, String status) async {
    await _client.from('invitations').update({
      'status': status,
    }).eq('id', invitationId);
  }
}

/// Provider for SupabaseService
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});
