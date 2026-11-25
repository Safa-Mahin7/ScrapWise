// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'ScrapWise';

  @override
  String get tagline => 'स्मार्ट स्क्रैप। स्वच्छ भविष्य।';

  @override
  String get selectLanguage => 'अपनी भाषा चुनें';

  @override
  String get continueButton => 'जारी रखें';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get createAccount => 'खाता बनाएं';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get password => 'पासवर्ड';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get noAccount => 'खाता नहीं है?';

  @override
  String get alreadyHaveAccount => 'पहले से खाता है?';

  @override
  String get authPendingTitle => 'प्रमाणीकरण लंबित';

  @override
  String get authPendingMessage =>
      'बैकएंड प्रमाणीकरण एकीकरण प्रगति में है। साइन-इन कार्यक्षमता FastAPI सेवा कनेक्ट होने के बाद उपलब्ध होगी।';

  @override
  String get ok => 'ठीक है';

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
  String get loading => 'लोड हो रहा है…';

  @override
  String get errorGeneric => 'कुछ गलत हुआ। कृपया पुनः प्रयास करें।';

  @override
  String get retryButton => 'पुनः प्रयास';

  @override
  String get welcomeTo => 'स्वागत है';

  @override
  String get appDescription =>
      'घरों, कलेक्टरों और व्यापारियों को एक स्मार्ट, हरे कल के लिए जोड़ना।';

  @override
  String get mobileHint => 'अपना मोबाइल नंबर दर्ज करें';

  @override
  String get passwordHint => 'अपना पासवर्ड दर्ज करें';

  @override
  String get signInToAccount => 'अपने खाते में साइन इन करें';

  @override
  String get dontHaveAccount => 'खाता नहीं है? एक बनाएं';

  @override
  String get selfRegisterNote =>
      'केवल घरेलू उपयोगकर्ता स्व-पंजीकरण कर सकते हैं।';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get locality => 'इलाका';

  @override
  String get confirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get nameHint => 'अपना पूरा नाम दर्ज करें';

  @override
  String get localityHint => 'अपना इलाका दर्ज करें';

  @override
  String get passwordCreateHint => 'पासवर्ड बनाएं';

  @override
  String get confirmPasswordHint => 'पासवर्ड फिर से दर्ज करें';

  @override
  String get nameRequired => 'कृपया अपना पूरा नाम दर्ज करें';

  @override
  String get localityRequired => 'कृपया अपना इलाका दर्ज करें';

  @override
  String get mobileRequired => 'कृपया मोबाइल नंबर दर्ज करें';

  @override
  String get mobileInvalid => 'मान्य 10-अंकों का नंबर दर्ज करें';

  @override
  String get passwordRequired => 'कृपया पासवर्ड दर्ज करें';

  @override
  String get passwordTooShort => 'पासवर्ड कम से कम 10 अक्षरों का होना चाहिए';

  @override
  String get confirmPasswordRequired => 'कृपया पासवर्ड की पुष्टि करें';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get authUnavailable =>
      'प्रमाणीकरण सेवा जुड़ने तक साइन-इन उपलब्ध नहीं है। कोई खाता सत्र नहीं बनाया गया।';

  @override
  String get forgotPasswordTitle => 'पासवर्ड रीसेट करें';

  @override
  String get forgotPasswordHelp =>
      'अपने खाते का मोबाइल नंबर दर्ज करें। यदि खाते में पासवर्ड है, तो सत्यापन कोड भेजा जाएगा। केवल Google वाले खाते के लिए Google से साइन इन करें।';

  @override
  String get recoveryDeliveryNotice =>
      'गोपनीयता के लिए यह संदेश हर नंबर के लिए समान है। कोड न मिले तो Google वाले खाते में Google से साइन इन करें।';

  @override
  String get sendCode => 'जारी रखें';

  @override
  String get otpTitle => 'अपने फोन की पुष्टि करें';

  @override
  String get otpCode => 'सत्यापन कोड';

  @override
  String get otpCodeHint => '6-अंकों का कोड दर्ज करें';

  @override
  String get otpCodeRequired => '6-अंकों का कोड दर्ज करें';

  @override
  String get otpNotSentMessage =>
      'यह फोन सत्यापन स्क्रीन है, लेकिन प्रमाणीकरण बैकएंड जुड़ा न होने के कारण कोई कोड भेजा या सत्यापित नहीं हुआ है।';

  @override
  String get verificationUnavailable =>
      'प्रमाणीकरण बैकएंड जुड़ने तक सत्यापन उपलब्ध नहीं है। कुछ भी सत्यापित नहीं हुआ है।';

  @override
  String get resendCode => 'कोड फिर भेजें';

  @override
  String get verifyCode => 'कोड सत्यापित करें';

  @override
  String get newPasswordTitle => 'नया पासवर्ड बनाएं';

  @override
  String get newPasswordHelp =>
      'कम से कम 10 अक्षरों का नया पासवर्ड चुनें। आपके अन्य सत्र बंद कर दिए जाएंगे।';

  @override
  String get newPassword => 'नया पासवर्ड';

  @override
  String get confirmNewPassword => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get changeMobileTitle => 'मोबाइल नंबर बदलें';

  @override
  String get changeMobileHelp =>
      'अपने वर्तमान पासवर्ड या Google से पहचान की पुष्टि करें, फिर नए नंबर को SMS से सत्यापित करें। इसके बाद फिर से साइन इन करना होगा।';

  @override
  String get currentMobile => 'वर्तमान मोबाइल नंबर';

  @override
  String get newMobileNumber => 'नया मोबाइल नंबर';

  @override
  String get collectorInvitationTitle => 'कलेक्टर आमंत्रण सक्रिय करें';

  @override
  String get collectorInvitationHelp =>
      'कलेक्टर पहुंच के लिए मान्य आमंत्रण आवश्यक है। यह फॉर्म सार्वजनिक कलेक्टर खाते नहीं बनाता।';

  @override
  String get invitationCode => 'आमंत्रण कोड';

  @override
  String get invitationCodeRequired => 'आमंत्रण कोड दर्ज करें';

  @override
  String get activateInvitation => 'आमंत्रण सक्रिय करें';

  @override
  String get collectorInvitationRequiredNote =>
      'कलेक्टर सक्रियण के लिए सर्वर पर आमंत्रण सत्यापन आवश्यक है। कोई आमंत्रण जांचा नहीं गया।';

  @override
  String get traderApplicationTitle => 'व्यापारी व्यवसाय आवेदन';

  @override
  String get traderApplicationHelp =>
      'समीक्षा के लिए व्यवसाय आवेदन दें। व्यापारी अधिकार स्वतः नहीं दिए जाते।';

  @override
  String get businessName => 'व्यवसाय का नाम';

  @override
  String get businessNameRequired => 'कृपया व्यवसाय का नाम दर्ज करें';

  @override
  String get submitApplication => 'आवेदन जमा करें';

  @override
  String get pendingApprovalTitle => 'व्यापारी अनुमोदन समीक्षा';

  @override
  String get pendingApprovalHelp =>
      'व्यापारी पहुंच आवेदन की समीक्षा के बाद ही मिलती है। इस स्क्रीन से कोई आवेदन जमा नहीं हुआ है।';

  @override
  String get illustrativeStatus =>
      'उदाहरण स्थिति: समीक्षा लंबित। इस डिवाइस से कोई आवेदन जुड़ा नहीं है।';

  @override
  String get approvalInfo => 'अनुमोदन जानकारी देखें';

  @override
  String get collectorInviteLink => 'क्या आपके पास कलेक्टर आमंत्रण है?';

  @override
  String get traderApplicationLink => 'व्यापारी के रूप में आवेदन करें';

  @override
  String get showPassword => 'पासवर्ड दिखाएं';

  @override
  String get hidePassword => 'पासवर्ड छिपाएं';

  @override
  String get phoneChangeAction => 'सत्यापन कोड भेजें';

  @override
  String get accountSettings => 'खाता सेटिंग';

  @override
  String get changeMobileAction => 'मोबाइल नंबर बदलें';

  @override
  String get mobileChangeReauth =>
      'पुष्टि के लिए अपना पासवर्ड फिर से दर्ज करें या Google से जारी रखें।';

  @override
  String get mobileChangeConflict =>
      'यह नंबर पहले से उपयोग में है या मोबाइल बदलने का दूसरा अनुरोध लंबित है।';

  @override
  String get mobileChangeSuccess =>
      'मोबाइल नंबर बदल गया। नए नंबर से फिर साइन इन करें।';

  @override
  String get passwordResetSuccess =>
      'पासवर्ड बदल गया। नए पासवर्ड से साइन इन करें।';

  @override
  String get sessionExpired =>
      'आपका सत्र समाप्त हो गया। जारी रखने के लिए फिर साइन इन करें।';

  @override
  String get smsDeliveryUnavailable =>
      'SMS सेवा अस्थायी रूप से उपलब्ध नहीं है। सत्यापन कोड नहीं भेजा गया।';

  @override
  String get previewNewPassword => 'नए पासवर्ड फॉर्म का पूर्वावलोकन';

  @override
  String get accountCreationUnavailable =>
      'प्रमाणीकरण सेवा जुड़ने तक खाता बनाना उपलब्ध नहीं है। कोई खाता नहीं बनाया गया।';

  @override
  String get applicationUnavailable =>
      'बैकएंड जुड़ने तक आवेदन जमा करना उपलब्ध नहीं है। कोई आवेदन जमा नहीं हुआ।';

  @override
  String get passwordResetUnavailable =>
      'पासवर्ड रीसेट नहीं हो सका। नया सत्यापन कोड माँगकर फिर प्रयास करें।';

  @override
  String get mobileAlreadyRegistered => 'यह मोबाइल नंबर पहले से पंजीकृत है।';

  @override
  String get registrationDetailsInvalid =>
      'कृपया अपनी जानकारी जाँचें और फिर प्रयास करें।';

  @override
  String get smsUnavailable =>
      'SMS सत्यापन अस्थायी रूप से उपलब्ध नहीं है। खाता सक्रिय नहीं हुआ। कृपया बाद में पुनः प्रयास करें।';

  @override
  String get authNetworkUnavailable =>
      'प्रमाणीकरण सेवा से कनेक्ट नहीं हो पा रहा। अपना कनेक्शन जाँचें।';

  @override
  String get otpInvalid =>
      'कोड अमान्य है, समाप्त हो चुका है या पहले ही उपयोग किया जा चुका है।';

  @override
  String get otpRateLimited =>
      'बहुत अधिक अनुरोध या प्रयास हुए हैं। कृपया प्रतीक्षा करें और फिर प्रयास करें।';

  @override
  String get verificationWorkflowUnavailable =>
      'यह सत्यापन प्रक्रिया अभी जुड़ी नहीं है।';

  @override
  String get verificationWorkflowNotice =>
      'यह सत्यापन प्रक्रिया अभी एकीकृत नहीं है।';

  @override
  String get otpRequestAccepted =>
      'यदि यह नंबर पात्र है, तो SMS प्रदाता ने कोड अनुरोध स्वीकार किया है। संदेश आने में थोड़ा समय लग सकता है।';

  @override
  String get mobileVerified =>
      'मोबाइल नंबर सत्यापित हो गया। कृपया साइन इन करें।';

  @override
  String get mobileMissing =>
      'मोबाइल नंबर नहीं मिला। कृपया फिर से पंजीकरण करें।';

  @override
  String get accountStatusChanged =>
      'खाते की स्थिति बदल गई है। कृपया फिर प्रयास करें।';

  @override
  String get verificationFailed => 'सत्यापन विफल हुआ। कृपया फिर प्रयास करें।';

  @override
  String get requestingCode => 'कोड का अनुरोध हो रहा है...';

  @override
  String resendCodeCountdown(int seconds) {
    return '$seconds सेकंड में फिर भेजें';
  }

  @override
  String get continueWithGoogle => 'Google के साथ जारी रखें';

  @override
  String get orContinueWithGoogle => 'या Google के साथ जारी रखें';

  @override
  String get orContinueWithMobile => 'या मोबाइल और पासवर्ड से खाता बनाएँ';

  @override
  String get googleSignupHelp =>
      'आपका घरेलू खाता सक्रिय करने के लिए सत्यापित मोबाइल नंबर आवश्यक है।';

  @override
  String get useMobilePasswordInstead =>
      'इसके बजाय मोबाइल और पासवर्ड इस्तेमाल करें';

  @override
  String get googleAccountNotLinked =>
      'यह Google खाता ScrapWise से जुड़ा नहीं है। साइन अप करें या इसे मौजूदा खाते से जोड़ें।';

  @override
  String get googleAccountUnavailable =>
      'यह खाता सक्रिय नहीं है या इसका मोबाइल नंबर सत्यापित नहीं है।';

  @override
  String get googleSignInFailed =>
      'Google साइन-इन पूरा नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String get googleConfigurationMissing =>
      'इस ऐप में Google साइन-इन कॉन्फ़िगर नहीं है। सहायता से संपर्क करें।';

  @override
  String get googleIdentityInvalid =>
      'Google साइन-इन समाप्त हो गया या सत्यापित नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String get googleVerificationUnavailable =>
      'Google सत्यापन अभी उपलब्ध नहीं है। कृपया बाद में फिर कोशिश करें।';

  @override
  String get googleAccountConflict =>
      'यह मोबाइल नंबर या Google पहचान पहले से किसी खाते से जुड़ी है। अपने मौजूदा तरीके से साइन इन करें।';

  @override
  String get linkGoogleTitle => 'अपना Google खाता जोड़ें';

  @override
  String get linkGoogleHelp =>
      'Google जोड़ने से पहले स्वामित्व की पुष्टि के लिए अपना मोबाइल नंबर और पासवर्ड दर्ज करें।';

  @override
  String get linkGoogleAccount => 'Google को मौजूदा खाते से जोड़ें';

  @override
  String get googleLinkSuccess =>
      'Google खाता जुड़ गया। अब आप Google से साइन इन कर सकते हैं।';

  @override
  String get reauthenticationFailed =>
      'पासवर्ड गलत है। Google खाता नहीं जोड़ा गया।';

  @override
  String get loginInvalid => 'मोबाइल नंबर या पासवर्ड गलत है।';

  @override
  String get accountAwaitingVerification =>
      'आपका खाता सत्यापन या अनुमोदन की प्रतीक्षा में है।';

  @override
  String get loginDetailsInvalid => 'लॉगिन विवरण गलत हैं। कृपया जाँचें।';

  @override
  String get authRateLimited =>
      'बहुत अधिक प्रयास हुए। कृपया बाद में फिर कोशिश करें।';

  @override
  String get authServiceUnavailable =>
      'प्रमाणीकरण सेवा अभी उपलब्ध नहीं है। कृपया बाद में फिर कोशिश करें।';
}
