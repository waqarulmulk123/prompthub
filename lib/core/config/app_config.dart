abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const catalogUrl = String.fromEnvironment('CATALOG_BASE_URL');
  static const androidPurchaseKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_PUBLIC_KEY',
  );
  static const iosPurchaseKey = String.fromEnvironment(
    'REVENUECAT_IOS_PUBLIC_KEY',
  );
  static const checkoutUrl = String.fromEnvironment('WEB_CHECKOUT_URL');
  static const googleAuthEnabled = bool.fromEnvironment('GOOGLE_AUTH_ENABLED');
  static const appleAuthEnabled = bool.fromEnvironment('APPLE_AUTH_ENABLED');
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
