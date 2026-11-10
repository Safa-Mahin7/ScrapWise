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

  @override
  String get fullName => 'Full Name';

  @override
  String get locality => 'Locality';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get nameHint => 'Enter your full name';

  @override
  String get localityHint => 'Enter your locality';

  @override
  String get passwordCreateHint => 'Create a password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get nameRequired => 'Please enter your full name';

  @override
  String get localityRequired => 'Please enter your locality';

  @override
  String get mobileRequired => 'Please enter your mobile number';

  @override
  String get mobileInvalid => 'Enter a valid 10-digit number';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get authUnavailable =>
      'Sign-in isn\'t available until the authentication service is connected. No account session was created.';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordHelp =>
      'Enter the mobile number for your account. Code delivery is not available yet.';

  @override
  String get sendCode => 'Continue';

  @override
  String get otpTitle => 'Verify your phone';

  @override
  String get otpCode => 'Verification code';

  @override
  String get otpCodeHint => 'Enter the 6-digit code';

  @override
  String get otpCodeRequired => 'Enter the 6-digit code';

  @override
  String get otpNotSentMessage =>
      'This screen is ready for phone verification, but no code has been sent or verified because the authentication backend is not connected.';

  @override
  String get verificationUnavailable =>
      'Verification isn\'t available until the authentication backend is connected. Nothing has been verified.';

  @override
  String get resendCode => 'Resend code';

  @override
  String get verifyCode => 'Verify code';

  @override
  String get newPasswordTitle => 'Create a new password';

  @override
  String get newPasswordHelp =>
      'This form is a UI scaffold. A verified recovery session is required to reset a password.';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get changeMobileTitle => 'Change mobile number';

  @override
  String get changeMobileHelp =>
      'This account setting is available to signed-in users after authentication is integrated.';

  @override
  String get currentMobile => 'Current mobile number';

  @override
  String get newMobileNumber => 'New mobile number';

  @override
  String get collectorInvitationTitle => 'Activate collector invitation';

  @override
  String get collectorInvitationHelp =>
      'Collector access requires a valid invitation. This form does not create public collector accounts.';

  @override
  String get invitationCode => 'Invitation code';

  @override
  String get invitationCodeRequired => 'Enter your invitation code';

  @override
  String get activateInvitation => 'Activate invitation';

  @override
  String get collectorInvitationRequiredNote =>
      'Collector activation requires server-side invitation verification. No invitation has been checked.';

  @override
  String get traderApplicationTitle => 'Trader business application';

  @override
  String get traderApplicationHelp =>
      'Submit a business application for review. Trader privileges are not granted automatically.';

  @override
  String get businessName => 'Business name';

  @override
  String get businessNameRequired => 'Please enter your business name';

  @override
  String get submitApplication => 'Submit application';

  @override
  String get pendingApprovalTitle => 'Trader approval review';

  @override
  String get pendingApprovalHelp =>
      'Trader access is granted only after an application is reviewed. No application has been submitted from this screen.';

  @override
  String get illustrativeStatus =>
      'Example status: Pending review. No application is linked to this device.';

  @override
  String get approvalInfo => 'View approval information';

  @override
  String get collectorInviteLink => 'Have a collector invitation?';

  @override
  String get traderApplicationLink => 'Apply as a trader';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get phoneChangeAction => 'Continue to phone verification';

  @override
  String get previewNewPassword => 'Preview new password form';

  @override
  String get accountCreationUnavailable =>
      'Account creation isn\'t available until the authentication service is connected. No account was created.';

  @override
  String get applicationUnavailable =>
      'Application submission is unavailable until the backend is connected. No application was submitted.';

  @override
  String get passwordResetUnavailable =>
      'Password reset is unavailable until the authentication backend is connected. No password was changed.';
}
