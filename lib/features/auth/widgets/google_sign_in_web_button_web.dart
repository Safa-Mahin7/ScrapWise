import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_sign_in_web;

Widget renderGoogleSignInWebButton() => google_sign_in_web.renderButton(
      configuration: google_sign_in_web.GSIButtonConfiguration(
        text: google_sign_in_web.GSIButtonText.continueWith,
      ),
    );
