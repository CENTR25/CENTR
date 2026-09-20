/// App constants
class AppConstants {
  static const String appName = 'Progress';
  static const String appVersion = '1.0.0';
  
  // Subscription plans for trainers
  static const List<int> subscriptionPlans = [5, 25, 50, 100];
  
  // User roles
  static const String roleAdmin = 'admin';
  static const String roleTrainer = 'trainer';
  static const String roleStudent = 'student';

  // Base URL for student invite links.
  // Points to the Cloudflare-deployed web app's /register route.
  // Update when the app gets its own domain.
  static const String inviteBaseUrl = 'https://centr.xavierbenavidesm.workers.dev/register';

  // Base URL for trainer first-login links (invitation token flow).
  static const String firstLoginBaseUrl = 'https://centr.xavierbenavidesm.workers.dev/first-login';
}

/// Supabase configuration
class SupabaseConfig {
  static const String url = 'https://wtvjpxvcarclkxstmefr.supabase.co';
  static const String anonKey = 'sb_publishable_mSOhgz8JnAbgQccXdH6a6A_U_fRAB4b';
}
