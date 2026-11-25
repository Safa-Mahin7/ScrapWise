import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/auth_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  late final AuthService _authService;
  String? _errorMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.shared;
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSending || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final mobile = _mobileController.text.trim();
      await _authService.requestPasswordReset(mobile: mobile);
      if (!mounted) return;
      context.go(
        '/otp/password-recovery',
        extra: mobile,
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
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
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordHelp,
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
              textInputAction: TextInputAction.done,
              inputFormatters: mobileInputFormatters,
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            const SizedBox(height: 20),
            AuthNotice(message: l10n.recoveryDeliveryNotice),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 20),
            SwButton(
              label: l10n.sendCode,
              onPressed: _isSending ? null : _sendCode,
              isLoading: _isSending,
            ),
          ],
        ),
      ),
    );
  }
}
