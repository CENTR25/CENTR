/// App constants
class AppConstants {
  static const String appName = 'North Star';
  static const String appVersion = '1.0.0';
  
  // Subscription plans for trainers
  static const List<int> subscriptionPlans = [5, 25, 50, 100];
  
  // User roles
  static const String roleAdmin = 'admin';
  static const String roleTrainer = 'trainer';
  static const String roleStudent = 'student';
}

/// Supabase configuration
class SupabaseConfig {
  static const String url = 'https://wtvjpxvcarclkxstmefr.supabase.co';
  static const String anonKey = 'sb_publishable_mSOhgz8JnAbgQccXdH6a6A_U_fRAB4b';
}
