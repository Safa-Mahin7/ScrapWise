/// Application-wide constants for ScrapWise.
class AppConstants {
  AppConstants._();

  static const String appName = 'ScrapWise';
  static const String appVersion = '1.0.0';

  // Supported locale tags
  static const List<String> supportedLocales = ['en', 'hi', 'kn', 'te', 'ur'];

  // SharedPreferences keys
  static const String prefLocale = 'selected_locale';

  // Route names
  static const String routeSplash = '/';
  static const String routeLanguage = '/language';
  static const String routeLanding = '/landing';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeLinkGoogle = '/link-google';
  static const String routeChangeMobile = '/account/change-mobile';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeOtpVerification = '/otp/:purpose';
  static const String routeNewPassword = '/new-password';
  static const String routeCollectorInvitation = '/collector-invitation';
  static const String routeTraderApplication = '/trader-application';
  static const String routeTraderApplicationStatus =
      '/trader-application/status';
  // Protected role landing routes.
  static const String routeHouseholdDashboard = '/dashboard/household';
  static const String routeCollectorDashboard = '/dashboard/collector';
  static const String routeTraderDashboard = '/dashboard/trader';
  static const String routeAdminDashboard = '/dashboard/admin';
}
