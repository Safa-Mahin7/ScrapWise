import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/session_controller.dart';
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
    this.authService,
    this.sessionController,
  });

  final OtpPurpose purpose;
  final String? phoneNumber;
  final AuthService? authService;
  final SessionController? sessionController;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _resendCooldown = Duration(seconds: 60);

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  late final AuthService _authService;
  late final SessionController _sessionController;

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  String? _errorMessage;
  String? _successMessage;

  bool get _isRegistration => widget.purpose == OtpPurpose.phoneVerification;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.shared;
    _sessionController = widget.sessionController ?? SessionController.instance;
    _resendCooldownSeconds = _resendCooldown.inSeconds;
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      _tickResendCooldown,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = _resendCooldown.inSeconds;
    });
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      _tickResendCooldown,
    );
  }

  void _tickResendCooldown(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    if (_resendCooldownSeconds <= 1) {
      timer.cancel();
      setState(() {
        _resendCooldownSeconds = 0;
      });
      return;
    }
    setState(() {
      _resendCooldownSeconds--;
    });
  }

  Future<void> _verify() async {
    if (_isVerifying || _isResending) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final mobile = widget.phoneNumber?.trim();

    if (mobile == null || mobile.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).mobileMissing;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final code = _codeController.text.trim();
      switch (widget.purpose) {
        case OtpPurpose.phoneVerification:
          await _authService.verifyOtp(
            mobile: mobile,
            purpose: 'registration',
            code: code,
          );
          break;
        case OtpPurpose.passwordRecovery:
          final resetToken = await _authService.verifyPasswordRecoveryOtp(
            mobile: mobile,
            code: code,
          );
          if (!mounted) return;
          context.go(
            AppConstants.routeNewPassword,
            extra: {'mobile': mobile, 'reset_token': resetToken},
          );
          return;
        case OtpPurpose.phoneChange:
          await _authService.confirmMobileChange(
            newMobile: mobile,
            code: code,
          );
          await _sessionController.expireLocalSession();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).mobileChangeSuccess,
              ),
            ),
          );
          context.go(AppConstants.routeLogin);
          return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).mobileVerified,
          ),
        ),
      );

      context.go(AppConstants.routeLogin);
    } on DioException catch (error) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      String message;

      switch (error.response?.statusCode) {
        case 400:
          message = l10n.otpInvalid;
          break;

        case 409:
          message = widget.purpose == OtpPurpose.phoneChange
              ? l10n.mobileChangeConflict
              : l10n.accountStatusChanged;
          break;

        case 429:
          message = l10n.otpRateLimited;
          break;

        case 503:
          message = l10n.smsDeliveryUnavailable;
          break;

        default:
          message = error.response == null
              ? l10n.authNetworkUnavailable
              : l10n.verificationFailed;
      }

      if (widget.purpose == OtpPurpose.phoneChange &&
          error.response?.statusCode == 401) {
        await _sessionController.expireLocalSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionExpired)),
        );
        context.go(AppConstants.routeLogin);
        return;
      }

      setState(() {
        _errorMessage = message;
        _successMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppLocalizations.of(context).errorGeneric;
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
    if (_isResending || _isVerifying || _resendCooldownSeconds > 0) return;

    final mobile = widget.phoneNumber?.trim();

    if (mobile == null || mobile.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).mobileMissing;
      });
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      switch (widget.purpose) {
        case OtpPurpose.phoneVerification:
          await _authService.resendOtp(mobile: mobile);
          break;
        case OtpPurpose.passwordRecovery:
          await _authService.requestPasswordReset(mobile: mobile);
          break;
        case OtpPurpose.phoneChange:
          await _authService.resendMobileChange();
          break;
      }

      if (!mounted) return;

      setState(() {
        _successMessage = AppLocalizations.of(context).otpRequestAccepted;
      });
      _startResendCooldown();
    } on DioException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);

      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          429 => l10n.otpRateLimited,
          503 => l10n.smsDeliveryUnavailable,
          401 when widget.purpose == OtpPurpose.phoneChange =>
            l10n.sessionExpired,
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
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final isRecovery = widget.purpose == OtpPurpose.passwordRecovery;
    final isPhoneChange = widget.purpose == OtpPurpose.phoneChange;

    final isBusy = _isVerifying || _isResending;
    final resendLabel = _isResending
        ? l10n.requestingCode
        : _resendCooldownSeconds > 0
            ? l10n.resendCodeCountdown(_resendCooldownSeconds)
            : l10n.resendCode;

    return AuthScreenShell(
      title: widget.purpose.title(l10n),
      subtitle: switch (widget.purpose) {
        OtpPurpose.passwordRecovery => l10n.forgotPasswordHelp,
        OtpPurpose.phoneChange => l10n.changeMobileHelp,
        OtpPurpose.phoneVerification => l10n.otpCodeHint,
      },
      onBack: () => context.go(
        isRecovery
            ? AppConstants.routeForgotPassword
            : isPhoneChange
                ? AppConstants.routeChangeMobile
                : AppConstants.routeLogin,
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
            if (isRecovery) ...[
              AuthNotice(message: l10n.recoveryDeliveryNotice),
              const SizedBox(height: 20),
            ],
            if (isPhoneChange) ...[
              AuthNotice(message: l10n.changeMobileHelp),
              const SizedBox(height: 20),
            ],
            if (_isRegistration) ...[
              AuthNotice(message: l10n.otpRequestAccepted),
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
              onPressed: isBusy || _resendCooldownSeconds > 0 ? null : _resend,
              child: Text(resendLabel),
            ),
          ],
        ),
      ),
    );
  }
}
