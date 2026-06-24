// app_routes.dart
// Central route constants — always import this instead of raw strings.

class AppRoutes {
  AppRoutes._();

  // ── Auth ──────────────────────────────────────────────────────
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forget_password';

  // ── Main tabs ─────────────────────────────────────────────────
  static const home = '/home';
  static const homeTranslateLegacy = '/home/translate';
  static const services = '/services';
  static const profile = '/profile';

  // ── Services sub-routes ───────────────────────────────────────
  static const servicesTranslate = '/services/translate';
  static const servicesTranslateHistory = '/services/translate/history';
  static const servicesAnalytics = '/services/analytics';
  static const servicesSos = '/services/sos';
  static const servicesSmartHome = '/services/smart-home';
  static const servicesMorse = '/services/morse'; // kept but hidden
  static const servicesGuide = '/services/guide';
  static const servicesHealth = '/services/health';
  static const servicesPractice = '/services/practice';

  // ── Devices (shared — opened from Home or Profile) ───────────
  /// Navigates to the Devices overview page (not inside the shell branch).

  // ── Profile sub-routes ────────────────────────────────────────
  static const profileEdit = '/profile/edit';
  static const profileAppearance = '/profile/appearance';
  static const profileDevices = '/profile/devices';
  static const profileDevicePairing = '/profile/devices/pairing';
  static const profileDeviceUpdates = '/profile/devices/updates';
  static const profileFaq = '/profile/faq';
  static const profilePrivacySecurity = '/profile/privacy-security';
  static const profileHelpFeedback = '/profile/help-feedback';
}
