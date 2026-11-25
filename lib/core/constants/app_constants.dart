/// App constants
class AppConstants {
  static const String appName = 'PRGS';
  static const String appVersion = '1.0.0';
  
  // Subscription plans for trainers
  static const List<int> subscriptionPlans = [5, 25, 50, 100];
  
  // User roles
  static const String roleAdmin = 'admin';
  static const String roleTrainer = 'trainer';
  static const String roleStudent = 'student';

  // Base URL for student invite links.
  // Points to the Cloudflare-deployed web app's /register route.
  // Custom domain: prgs.app.
  static const String inviteBaseUrl = 'https://prgs.app/register';

  // Base URL for trainer first-login links (invitation token flow).
  static const String firstLoginBaseUrl = 'https://prgs.app/first-login';

  /// Where password-recovery email links land (must be in the Supabase Auth
  /// "Redirect URLs" allow-list; otherwise Supabase falls back to the Site URL).
  static const String resetPasswordUrl = 'https://prgs.app/reset-password';

  // WhatsApp CTA for brands/marketing inquiries.
  // TODO: set real PRGS WhatsApp number.
  static const String prgsBrandsWhatsappUrl = 'https://wa.me/000000000';

  // Support contacts shown in the trainer "Ayuda" screen.
  // TODO: set the real PRGS support WhatsApp number and email.
  static const String prgsSupportWhatsappUrl = 'https://wa.me/000000000';
  static const String prgsSupportEmail = 'soporte@prgs.app';
}

/// Supabase configuration
class SupabaseConfig {
  static const String url = 'https://wtvjpxvcarclkxstmefr.supabase.co';
  static const String anonKey = 'sb_publishable_mSOhgz8JnAbgQccXdH6a6A_U_fRAB4b';
}
