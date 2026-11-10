// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ScrapWise';

  @override
  String get tagline => 'Smart Scrap. Cleaner Future.';

  @override
  String get selectLanguage => 'Select Your Language';

  @override
  String get continueButton => 'Continue';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get authPendingTitle => 'Authentication Pending';

  @override
  String get authPendingMessage =>
      'Backend authentication integration is in progress. Sign-in functionality will be available once the FastAPI service is connected.';

  @override
  String get ok => 'OK';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get kannada => 'ಕನ್ನಡ';

  @override
  String get telugu => 'తెలుగు';

  @override
  String get urdu => 'اردو';

  @override
  String get loading => 'Loading…';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get retryButton => 'Retry';

  @override
  String get welcomeTo => 'Welcome to';

  @override
  String get appDescription =>
      'Connecting households, collectors and traders for a smarter, greener tomorrow.';

  @override
  String get mobileHint => 'Enter your mobile number';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get signInToAccount => 'Sign in to your account';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Create one';

  @override
  String get selfRegisterNote =>
      'Only Household users can self-register. Collector and Trader accounts are activated through controlled onboarding.';
}
