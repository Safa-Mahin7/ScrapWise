import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/google_identity_provider.dart';
import '../services/session_controller.dart';
import '../widgets/auth_components.dart';
import '../widgets/google_sign_in_action_button.dart';

class LinkGoogleScreen extends StatefulWidget {
  const LinkGoogleScreen({
    super.key,
    this.sessionController,
    this.googleIdentityProvider,
  });

  final SessionController? sessionController;
  final GoogleIdentityProvider? googleIdentityProvider;

  @override
  State<LinkGoogleScreen> createState() => _LinkGoogleScreenState();
}

class _LinkGoogleScreenState extends State<LinkGoogleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  late final SessionController _session;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionController ?? SessionController.instance;
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onGoogleToken(String idToken) async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    var reauthenticated = false;
    try {
      await _session.signIn(
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
      );
      reauthenticated = true;
      await _session.linkGoogleIdentity(
        idToken: idToken,
        password: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).googleLinkSuccess)),
      );
      final dashboard = _session.dashboardPath;
      context.go(dashboard ?? AppConstants.routeLogin);
    } on DioException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          401 => reauthenticated
              ? l10n.googleIdentityInvalid
              : l10n.reauthenticationFailed,
          403 => l10n.googleAccountUnavailable,
          409 => l10n.googleAccountConflict,
          429 => l10n.authRateLimited,
          503 => l10n.googleVerificationUnavailable,
          _ => error.response == null
              ? l10n.authNetworkUnavailable
              : l10n.googleSignInFailed,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).googleSignInFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _onGoogleError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _errorMessage = error is GoogleIdentityConfigurationException
          ? l10n.googleConfigurationMissing
          : l10n.googleSignInFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.linkGoogleTitle,
      subtitle: l10n.linkGoogleHelp,
      onBack: () => context.go(AppConstants.routeLogin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwTextField(
              controller: _mobileController,
              label: l10n.mobileNumber,
              hint: l10n.mobileHint,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _passwordController,
              label: l10n.password,
              hint: l10n.passwordHint,
              obscureText: true,
              showPasswordLabel: l10n.showPassword,
              hidePasswordLabel: l10n.hidePassword,
              prefixIcon: Icons.lock_outline_rounded,
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.passwordRequired;
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 20),
            GoogleSignInActionButton(
              label: l10n.continueWithGoogle,
              provider: widget.googleIdentityProvider,
              disabled: _isSubmitting,
              onIdToken: _onGoogleToken,
              onError: _onGoogleError,
            ),
          ],
        ),
      ),
    );
  }
}
