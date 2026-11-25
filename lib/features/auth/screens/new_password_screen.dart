import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/session_controller.dart';
import '../widgets/auth_components.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    this.mobile,
    this.resetToken,
    this.authService,
    this.sessionController,
  });

  final String? mobile;
  final String? resetToken;
  final AuthService? authService;
  final SessionController? sessionController;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final AuthService _authService;
  late final SessionController _sessionController;
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _completed = false;

  bool get _hasResetGrant => widget.mobile != null && widget.resetToken != null;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.shared;
    _sessionController = widget.sessionController ?? SessionController.instance;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    final mobile = widget.mobile;
    final resetToken = widget.resetToken;
    if (mobile == null || resetToken == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).otpInvalid;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _authService.resetPassword(
        mobile: mobile,
        resetToken: resetToken,
        newPassword: _passwordController.text,
      );
      await _sessionController.expireLocalSession();
      if (mounted) setState(() => _completed = true);
    } on DioException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          400 => l10n.otpInvalid,
          429 => l10n.otpRateLimited,
          _ => error.response == null
              ? l10n.authNetworkUnavailable
              : l10n.passwordResetUnavailable,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.newPasswordTitle,
      subtitle: l10n.newPasswordHelp,
      onBack: () => context.go(AppConstants.routeLogin),
      child: _completed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthNotice(message: l10n.passwordResetSuccess),
                const SizedBox(height: 20),
                SwButton(
                  label: l10n.signIn,
                  onPressed: () => context.go(AppConstants.routeLogin),
                ),
              ],
            )
          : !_hasResetGrant
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthNotice(message: l10n.otpInvalid, isError: true),
                    const SizedBox(height: 20),
                    SwButton(
                      label: l10n.sendCode,
                      onPressed: () => context.go(
                        AppConstants.routeForgotPassword,
                      ),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwTextField(
                        controller: _passwordController,
                        label: l10n.newPassword,
                        hint: l10n.passwordCreateHint,
                        obscureText: true,
                        showPasswordLabel: l10n.showPassword,
                        hidePasswordLabel: l10n.hidePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.passwordRequired;
                          }
                          if (value.length < 10) return l10n.passwordTooShort;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SwTextField(
                        controller: _confirmController,
                        label: l10n.confirmNewPassword,
                        hint: l10n.confirmPasswordHint,
                        obscureText: true,
                        showPasswordLabel: l10n.showPassword,
                        hidePasswordLabel: l10n.hidePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.confirmPasswordRequired;
                          }
                          if (value != _passwordController.text) {
                            return l10n.passwordsDoNotMatch;
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        AuthNotice(message: _errorMessage!, isError: true),
                      ],
                      const SizedBox(height: 20),
                      SwButton(
                        label: l10n.newPasswordTitle,
                        onPressed: _isSubmitting ? null : _savePassword,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
                ),
    );
  }
}
