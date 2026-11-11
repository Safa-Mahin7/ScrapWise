import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/auth_components.dart';

enum OtpPurpose {
  phoneVerification,
  passwordRecovery,
  phoneChange,
}

extension OtpPurposeLabel on OtpPurpose {
  static OtpPurpose fromRoute(String? value) {
    return switch (value) {
      'password-recovery' => OtpPurpose.passwordRecovery,
      'phone-change' => OtpPurpose.phoneChange,
      _ => OtpPurpose.phoneVerification,
    };
  }

  String title(AppLocalizations l10n) {
    switch (this) {
      case OtpPurpose.phoneVerification:
        return l10n.otpTitle;
      case OtpPurpose.passwordRecovery:
        return l10n.forgotPasswordTitle;
      case OtpPurpose.phoneChange:
        return l10n.changeMobileTitle;
    }
  }
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.purpose,
    this.phoneNumber,
  });

  final OtpPurpose purpose;
  final String? phoneNumber;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _isVerifying = false;
  bool _isResending = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _isRegistration => widget.purpose == OtpPurpose.phoneVerification;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_isVerifying || _isResending) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Password recovery and mobile change have separate
    // backend workflows that are not integrated yet.
    if (!_isRegistration) {
      setState(() {
        _errorMessage = 'This verification workflow is not connected yet.';
      });
      return;
    }

    final mobile = widget.phoneNumber?.trim();

    if (mobile == null || mobile.isEmpty) {
      setState(() {
        _errorMessage = 'Mobile number is missing. Please register again.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.verifyOtp(
        mobile: mobile,
        purpose: 'registration',
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mobile number verified successfully. Please sign in.',
          ),
        ),
      );

      context.go(AppConstants.routeLogin);
    } on DioException catch (error) {
      if (!mounted) return;

      String message;

      switch (error.response?.statusCode) {
        case 400:
          message = 'Invalid, expired, or already used verification code.';
          break;

        case 409:
          message = 'Account status changed. Please try again.';
          break;

        case 429:
          message = 'Too many attempts. Please try again later.';
          break;

        case 503:
          message = 'Verification service is temporarily unavailable.';
          break;

        default:
          message = error.response == null
              ? 'Cannot connect to FastAPI. Check your server.'
              : 'Verification failed. Please try again.';
      }

      setState(() {
        _errorMessage = message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'An unexpected verification error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_isResending || _isVerifying) return;

    if (!_isRegistration) {
      setState(() {
        _errorMessage = 'Resending is not connected for this workflow yet.';
      });
      return;
    }

    final mobile = widget.phoneNumber?.trim();

    if (mobile == null || mobile.isEmpty) {
      setState(() {
        _errorMessage = 'Mobile number is missing. Please register again.';
      });
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.resendOtp(mobile: mobile);

      if (!mounted) return;

      setState(() {
        _successMessage =
            'If eligible, a new verification code has been requested.';
      });
    } on DioException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          429 => 'Please wait before requesting another code.',
          503 => 'OTP delivery is currently unavailable.',
          _ => 'Could not request a new code. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'An unexpected error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final isRecovery = widget.purpose == OtpPurpose.passwordRecovery;

    final isBusy = _isVerifying || _isResending;

    return AuthScreenShell(
      title: widget.purpose.title(l10n),
      subtitle: switch (widget.purpose) {
        OtpPurpose.passwordRecovery => l10n.forgotPasswordHelp,
        OtpPurpose.phoneChange => l10n.changeMobileHelp,
        OtpPurpose.phoneVerification => l10n.otpCodeHint,
      },
      onBack: () => context.go(
        isRecovery ? AppConstants.routeForgotPassword : AppConstants.routeLogin,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.phoneNumber != null) ...[
              Text(
                '${l10n.mobileNumber}: ${widget.phoneNumber}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (!_isRegistration) ...[
              const AuthNotice(
                message: 'This verification workflow is not integrated yet.',
              ),
              const SizedBox(height: 20),
            ],
            SwTextField(
              controller: _codeController,
              label: l10n.otpCode,
              hint: l10n.otpCodeHint,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.verified_user_outlined,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verify(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) {
                if (value == null || value.length != 6) {
                  return l10n.otpCodeRequired;
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(
                message: _errorMessage!,
                isError: true,
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _successMessage!),
            ],
            const SizedBox(height: 20),
            SwButton(
              label: l10n.verifyCode,
              onPressed: isBusy ? null : _verify,
              isLoading: _isVerifying,
            ),
            TextButton(
              onPressed: isBusy ? null : _resend,
              child: Text(
                _isResending ? 'Requesting code...' : l10n.resendCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
