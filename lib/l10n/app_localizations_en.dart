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
  String get passwordTooShort => 'Password must be at least 10 characters';

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
      'Enter the mobile number for your account. If it has a password, a verification code will be requested. Google-only accounts should use Continue with Google.';

  @override
  String get recoveryDeliveryNotice =>
      'For privacy, this message is the same for every number. If you do not receive a code, sign in with Google if your account uses Google.';

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
      'Choose a password with at least 10 characters. Your other sessions will be signed out.';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get changeMobileTitle => 'Change mobile number';

  @override
  String get changeMobileHelp =>
      'Confirm your identity with your current password or Google, then verify the new number by SMS. You will need to sign in again.';

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
  String get phoneChangeAction => 'Send verification code';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get changeMobileAction => 'Change Mobile Number';

  @override
  String get mobileChangeReauth =>
      'Re-enter your password or continue with Google to confirm it is you.';

  @override
  String get mobileChangeConflict =>
      'This number is already in use or another mobile change is pending.';

  @override
  String get mobileChangeSuccess =>
      'Mobile number changed. Sign in again with the new number.';

  @override
  String get passwordResetSuccess =>
      'Password changed. Sign in with your new password.';

  @override
  String get sessionExpired =>
      'Your session expired. Sign in again to continue.';

  @override
  String get smsDeliveryUnavailable =>
      'The SMS service is temporarily unavailable. No verification code was sent.';

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
      'Password reset could not be completed. Request a new verification code and try again.';

  @override
  String get mobileAlreadyRegistered =>
      'This mobile number is already registered.';

  @override
  String get registrationDetailsInvalid =>
      'Please check your details and try again.';

  @override
  String get smsUnavailable =>
      'SMS verification is temporarily unavailable. No account was activated. Please try again later.';

  @override
  String get authNetworkUnavailable =>
      'Cannot connect to the authentication service. Check your connection.';

  @override
  String get otpInvalid => 'The code is invalid, expired, or already used.';

  @override
  String get otpRateLimited =>
      'Too many requests or attempts. Please wait and try again.';

  @override
  String get verificationWorkflowUnavailable =>
      'This verification workflow is not connected yet.';

  @override
  String get verificationWorkflowNotice =>
      'This verification workflow is not integrated yet.';

  @override
  String get otpRequestAccepted =>
      'If eligible, your code request was accepted by the SMS provider. Delivery may take a moment.';

  @override
  String get mobileVerified => 'Mobile number verified. Please sign in.';

  @override
  String get mobileMissing =>
      'Mobile number is missing. Please register again.';

  @override
  String get accountStatusChanged =>
      'Account status changed. Please try again.';

  @override
  String get verificationFailed => 'Verification failed. Please try again.';

  @override
  String get requestingCode => 'Requesting code...';

  @override
  String resendCodeCountdown(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get orContinueWithGoogle => 'Or continue with Google';

  @override
  String get orContinueWithMobile =>
      'Or create an account with mobile and password';

  @override
  String get googleSignupHelp =>
      'A verified mobile number is required to activate your Household account.';

  @override
  String get useMobilePasswordInstead => 'Use mobile and password instead';

  @override
  String get googleAccountNotLinked =>
      'This Google account is not linked to ScrapWise. Sign up or link it to an existing account.';

  @override
  String get googleAccountUnavailable =>
      'This account is not active or its mobile number is not verified.';

  @override
  String get googleSignInFailed =>
      'Google sign-in could not be completed. Please try again.';

  @override
  String get googleConfigurationMissing =>
      'Google sign-in is not configured for this app. Contact support.';

  @override
  String get googleIdentityInvalid =>
      'Google sign-in expired or could not be verified. Please try again.';

  @override
  String get googleVerificationUnavailable =>
      'Google verification is temporarily unavailable. Please try again later.';

  @override
  String get googleAccountConflict =>
      'This mobile number or Google identity already belongs to an account. Sign in with your existing method.';

  @override
  String get linkGoogleTitle => 'Link your Google account';

  @override
  String get linkGoogleHelp =>
      'Enter your mobile number and password to confirm ownership before linking Google.';

  @override
  String get linkGoogleAccount => 'Link Google to an existing account';

  @override
  String get googleLinkSuccess =>
      'Google account linked. You can now sign in with Google.';

  @override
  String get reauthenticationFailed =>
      'The password is incorrect. Google was not linked.';

  @override
  String get loginInvalid => 'Invalid mobile number or password.';

  @override
  String get accountAwaitingVerification =>
      'Your account is awaiting verification or approval.';

  @override
  String get loginDetailsInvalid =>
      'Invalid login details. Please check your input.';

  @override
  String get authRateLimited => 'Too many attempts. Please try again later.';

  @override
  String get authServiceUnavailable =>
      'Authentication is temporarily unavailable. Please try again later.';
}
