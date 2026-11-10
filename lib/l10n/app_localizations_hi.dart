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
  String get passwordTooShort => 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';

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
      'अपने खाते का मोबाइल नंबर दर्ज करें। कोड भेजने की सुविधा अभी उपलब्ध नहीं है।';

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
      'यह केवल UI स्क्रीन है। पासवर्ड रीसेट के लिए सत्यापित रिकवरी सत्र आवश्यक है।';

  @override
  String get newPassword => 'नया पासवर्ड';

  @override
  String get confirmNewPassword => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get changeMobileTitle => 'मोबाइल नंबर बदलें';

  @override
  String get changeMobileHelp =>
      'प्रमाणीकरण एकीकरण के बाद यह खाता सुविधा साइन-इन उपयोगकर्ताओं के लिए उपलब्ध होगी।';

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
  String get phoneChangeAction => 'फोन सत्यापन जारी रखें';

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
      'प्रमाणीकरण बैकएंड जुड़ने तक पासवर्ड रीसेट उपलब्ध नहीं है। पासवर्ड नहीं बदला गया।';
}
