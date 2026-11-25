import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/google_identity_provider.dart';
import '../services/session_controller.dart';
import '../widgets/auth_components.dart';
import '../widgets/google_sign_in_action_button.dart';

class ChangeMobileScreen extends StatefulWidget {
  const ChangeMobileScreen({
    super.key,
    this.authService,
    this.sessionController,
    this.googleIdentityProvider,
  });

  final AuthService? authService;
  final SessionController? sessionController;
  final GoogleIdentityProvider? googleIdentityProvider;

  @override
  State<ChangeMobileScreen> createState() => _ChangeMobileScreenState();
}

class _ChangeMobileScreenState extends State<ChangeMobileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newController = TextEditingController();
  late final AuthService _authService;
  late final SessionController _sessionController;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.shared;
    _sessionController = widget.sessionController ?? SessionController.instance;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _requestChange({
    String? currentPassword,
    String? googleIdToken,
  }) async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    if ((currentPassword == null) == (googleIdToken == null)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final newMobile = _newController.text.trim();
      await _authService.requestMobileChange(
        newMobile: newMobile,
        currentPassword: currentPassword,
        googleIdToken: googleIdToken,
      );
      if (!mounted) return;
      context.go(
        '/otp/phone-change',
        extra: newMobile,
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          401 => l10n.verificationFailed,
          409 => l10n.mobileChangeConflict,
          429 => l10n.otpRateLimited,
          503 => l10n.smsDeliveryUnavailable,
          _ => error.response == null
              ? l10n.authNetworkUnavailable
              : l10n.verificationFailed,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).errorGeneric;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _requestWithPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).passwordRequired;
      });
      return;
    }
    await _requestChange(currentPassword: _passwordController.text);
  }

  Future<void> _requestWithGoogle(String idToken) {
    return _requestChange(googleIdToken: idToken);
  }

  void _handleGoogleError(Object error) {
    if (!mounted) return;
    setState(() {
      _errorMessage = AppLocalizations.of(context).googleSignInFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentMobile = _sessionController.user?['mobile'] as String?;
    return AuthScreenShell(
      title: l10n.changeMobileTitle,
      subtitle: l10n.changeMobileHelp,
      onBack: () => context.go(
        _sessionController.dashboardPath ?? AppConstants.routeLogin,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.currentMobile}: ${currentMobile ?? l10n.mobileMissing}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _newController,
              label: l10n.newMobileNumber,
              keyboardType: TextInputType.phone,
              inputFormatters: mobileInputFormatters,
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            const SizedBox(height: 20),
            AuthNotice(message: l10n.mobileChangeReauth),
            const SizedBox(height: 16),
            SwTextField(
              controller: _passwordController,
              label: l10n.password,
              obscureText: true,
              showPasswordLabel: l10n.showPassword,
              hidePasswordLabel: l10n.hidePassword,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 16),
            SwButton(
              label: l10n.phoneChangeAction,
              onPressed: _isSubmitting ? null : _requestWithPassword,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 12),
            GoogleSignInActionButton(
              label: l10n.continueWithGoogle,
              provider: widget.googleIdentityProvider,
              disabled: _isSubmitting,
              onIdToken: _requestWithGoogle,
              onError: _handleGoogleError,
            ),
          ],
        ),
      ),
    );
  }
}
