import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/google_identity_provider.dart';

class GoogleSignInActionButton extends StatefulWidget {
  const GoogleSignInActionButton({
    super.key,
    required this.label,
    required this.onIdToken,
    required this.onError,
    this.provider,
    this.disabled = false,
  });

  final String label;
  final Future<void> Function(String idToken) onIdToken;
  final ValueChanged<Object> onError;
  final GoogleIdentityProvider? provider;
  final bool disabled;

  @override
  State<GoogleSignInActionButton> createState() =>
      _GoogleSignInActionButtonState();
}

class _GoogleSignInActionButtonState extends State<GoogleSignInActionButton> {
  late final GoogleIdentityProvider _provider;
  Future<void>? _webInitialization;
  StreamSubscription<String>? _idTokenSubscription;
  StreamSubscription<Object>? _errorSubscription;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? googleIdentityProvider;
    if (kIsWeb) {
      _idTokenSubscription = _provider.idTokens.listen(
        (token) => unawaited(_deliverIdToken(token)),
        onError: (Object error, StackTrace stackTrace) => _reportError(error),
      );
      _errorSubscription = _provider.errors.listen(_reportError);
      _webInitialization = _initializeWeb();
    }
  }

  Future<void> _initializeWeb() async {
    try {
      await _provider.initialize();
    } catch (error) {
      _reportError(error);
      rethrow;
    }
  }

  @override
  void dispose() {
    if (_idTokenSubscription != null) {
      unawaited(_idTokenSubscription!.cancel());
    }
    if (_errorSubscription != null) {
      unawaited(_errorSubscription!.cancel());
    }
    super.dispose();
  }

  void _reportError(Object error) {
    if (mounted) widget.onError(error);
  }

  Future<void> _deliverIdToken(String token) async {
    if (_isWorking || widget.disabled) return;
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.onIdToken(token);
    } catch (error) {
      _reportError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isWorking || widget.disabled) return;
    setState(() {
      _isWorking = true;
    });
    try {
      final token = await _provider.authenticate();
      if (token != null) await widget.onIdToken(token);
    } catch (error) {
      _reportError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      if (_isWorking) {
        return const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return OutlinedButton.icon(
        onPressed: widget.disabled ? null : _authenticate,
        icon: const Icon(Icons.account_circle_outlined),
        label: Text(widget.label),
      );
    }

    return FutureBuilder<void>(
      future: _webInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _isWorking) {
          return SizedBox(
            height: 48,
            child: Center(
              child: snapshot.hasError
                  ? Text(widget.label)
                  : const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 48,
            child: Center(child: Text(widget.label)),
          );
        }

        if (widget.disabled) {
          return SizedBox(
            height: 48,
            child: Center(child: Text(widget.label)),
          );
        }

        return _provider.renderWebButton();
      },
    );
  }
}
