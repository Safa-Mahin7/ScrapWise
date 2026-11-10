import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_te.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
    Locale('te'),
    Locale('ur')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ScrapWise'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Smart Scrap. Cleaner Future.'**
  String get tagline;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Your Language'**
  String get selectLanguage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @authPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Pending'**
  String get authPendingTitle;

  /// No description provided for @authPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Backend authentication integration is in progress. Sign-in functionality will be available once the FastAPI service is connected.'**
  String get authPendingMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get hindi;

  /// No description provided for @kannada.
  ///
  /// In en, this message translates to:
  /// **'ಕನ್ನಡ'**
  String get kannada;

  /// No description provided for @telugu.
  ///
  /// In en, this message translates to:
  /// **'తెలుగు'**
  String get telugu;

  /// No description provided for @urdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get urdu;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @welcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTo;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Connecting households, collectors and traders for a smarter, greener tomorrow.'**
  String get appDescription;

  /// No description provided for @mobileHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get mobileHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @signInToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Create one'**
  String get dontHaveAccount;

  /// No description provided for @selfRegisterNote.
  ///
  /// In en, this message translates to:
  /// **'Only Household users can self-register. Collector and Trader accounts are activated through controlled onboarding.'**
  String get selfRegisterNote;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @locality.
  ///
  /// In en, this message translates to:
  /// **'Locality'**
  String get locality;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get nameHint;

  /// No description provided for @localityHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your locality'**
  String get localityHint;

  /// No description provided for @passwordCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get passwordCreateHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get nameRequired;

  /// No description provided for @localityRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your locality'**
  String get localityRequired;

  /// No description provided for @mobileRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number'**
  String get mobileRequired;

  /// No description provided for @mobileInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit number'**
  String get mobileInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @authUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn\'t available until the authentication service is connected. No account session was created.'**
  String get authUnavailable;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the mobile number for your account. Code delivery is not available yet.'**
  String get forgotPasswordHelp;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sendCode;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get otpTitle;

  /// No description provided for @otpCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpCode;

  /// No description provided for @otpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get otpCodeHint;

  /// No description provided for @otpCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get otpCodeRequired;

  /// No description provided for @otpNotSentMessage.
  ///
  /// In en, this message translates to:
  /// **'This screen is ready for phone verification, but no code has been sent or verified because the authentication backend is not connected.'**
  String get otpNotSentMessage;

  /// No description provided for @verificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Verification isn\'t available until the authentication backend is connected. Nothing has been verified.'**
  String get verificationUnavailable;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get verifyCode;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'This form is a UI scaffold. A verified recovery session is required to reset a password.'**
  String get newPasswordHelp;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @changeMobileTitle.
  ///
  /// In en, this message translates to:
  /// **'Change mobile number'**
  String get changeMobileTitle;

  /// No description provided for @changeMobileHelp.
  ///
  /// In en, this message translates to:
  /// **'This account setting is available to signed-in users after authentication is integrated.'**
  String get changeMobileHelp;

  /// No description provided for @currentMobile.
  ///
  /// In en, this message translates to:
  /// **'Current mobile number'**
  String get currentMobile;

  /// No description provided for @newMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'New mobile number'**
  String get newMobileNumber;

  /// No description provided for @collectorInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate collector invitation'**
  String get collectorInvitationTitle;

  /// No description provided for @collectorInvitationHelp.
  ///
  /// In en, this message translates to:
  /// **'Collector access requires a valid invitation. This form does not create public collector accounts.'**
  String get collectorInvitationHelp;

  /// No description provided for @invitationCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get invitationCode;

  /// No description provided for @invitationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your invitation code'**
  String get invitationCodeRequired;

  /// No description provided for @activateInvitation.
  ///
  /// In en, this message translates to:
  /// **'Activate invitation'**
  String get activateInvitation;

  /// No description provided for @collectorInvitationRequiredNote.
  ///
  /// In en, this message translates to:
  /// **'Collector activation requires server-side invitation verification. No invitation has been checked.'**
  String get collectorInvitationRequiredNote;

  /// No description provided for @traderApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Trader business application'**
  String get traderApplicationTitle;

  /// No description provided for @traderApplicationHelp.
  ///
  /// In en, this message translates to:
  /// **'Submit a business application for review. Trader privileges are not granted automatically.'**
  String get traderApplicationHelp;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @businessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your business name'**
  String get businessNameRequired;

  /// No description provided for @submitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get submitApplication;

  /// No description provided for @pendingApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Trader approval review'**
  String get pendingApprovalTitle;

  /// No description provided for @pendingApprovalHelp.
  ///
  /// In en, this message translates to:
  /// **'Trader access is granted only after an application is reviewed. No application has been submitted from this screen.'**
  String get pendingApprovalHelp;

  /// No description provided for @illustrativeStatus.
  ///
  /// In en, this message translates to:
  /// **'Example status: Pending review. No application is linked to this device.'**
  String get illustrativeStatus;

  /// No description provided for @approvalInfo.
  ///
  /// In en, this message translates to:
  /// **'View approval information'**
  String get approvalInfo;

  /// No description provided for @collectorInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Have a collector invitation?'**
  String get collectorInviteLink;

  /// No description provided for @traderApplicationLink.
  ///
  /// In en, this message translates to:
  /// **'Apply as a trader'**
  String get traderApplicationLink;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @phoneChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Continue to phone verification'**
  String get phoneChangeAction;

  /// No description provided for @previewNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Preview new password form'**
  String get previewNewPassword;

  /// No description provided for @accountCreationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account creation isn\'t available until the authentication service is connected. No account was created.'**
  String get accountCreationUnavailable;

  /// No description provided for @applicationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Application submission is unavailable until the backend is connected. No application was submitted.'**
  String get applicationUnavailable;

  /// No description provided for @passwordResetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Password reset is unavailable until the authentication backend is connected. No password was changed.'**
  String get passwordResetUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'kn', 'te', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'te':
      return AppLocalizationsTe();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
