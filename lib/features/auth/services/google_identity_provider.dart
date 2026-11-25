import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../widgets/google_sign_in_web_button.dart';

abstract interface class GoogleIdentityProvider {
  Future<void> initialize();
  Future<String?> authenticate();
  Stream<String> get idTokens;
  Stream<Object> get errors;
  Widget renderWebButton();
}

class GoogleIdentityConfigurationException implements Exception {
  const GoogleIdentityConfigurationException();
}

class OfficialGoogleIdentityProvider implements GoogleIdentityProvider {
  OfficialGoogleIdentityProvider({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  final StreamController<String> _idTokenController =
      StreamController<String>.broadcast();
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  Future<void>? _initialization;

  @override
  Stream<String> get idTokens => _idTokenController.stream;

  @override
  Stream<Object> get errors => _errorController.stream;

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (clientId.isEmpty) {
      throw const GoogleIdentityConfigurationException();
    }

    await _googleSignIn.initialize(
      clientId: kIsWeb ? clientId : null,
      serverClientId: kIsWeb ? null : clientId,
    );
    _googleSignIn.authenticationEvents.listen(
      _handleAuthenticationEvent,
      onError: (Object error, StackTrace stackTrace) {
        _errorController.add(error);
      },
    );
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final token = event.user.authentication.idToken;
    if (token == null || token.isEmpty) {
      _errorController.add(const GoogleIdentityConfigurationException());
      return;
    }
    _idTokenController.add(token);
  }

  @override
  Future<String?> authenticate() async {
    await initialize();
    try {
      final account = await _googleSignIn.authenticate();
      final token = account.authentication.idToken;
      if (!kIsWeb) await _googleSignIn.signOut();
      if (token == null || token.isEmpty) {
        throw const GoogleIdentityConfigurationException();
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Widget renderWebButton() => renderGoogleSignInWebButton();
}

final GoogleIdentityProvider googleIdentityProvider =
    OfficialGoogleIdentityProvider();
