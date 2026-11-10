import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

enum OtpPurpose { phoneVerification, passwordRecovery, phoneChange }

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
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verify() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage = AppLocalizations.of(context).verificationUnavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRecovery = widget.purpose == OtpPurpose.passwordRecovery;
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
            AuthNotice(message: l10n.otpNotSentMessage),
            const SizedBox(height: 20),
            SwTextField(
              controller: _codeController,
              label: l10n.otpCode,
              hint: l10n.otpCodeHint,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.verified_user_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) => value == null || value.length != 6
                  ? l10n.otpCodeRequired
                  : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 20),
            SwButton(label: l10n.verifyCode, onPressed: _verify),
            TextButton(
              onPressed: () => setState(
                () => _errorMessage = l10n.verificationUnavailable,
              ),
              child: Text(l10n.resendCode),
            ),
            if (isRecovery)
              TextButton(
                onPressed: () => context.go(AppConstants.routeNewPassword),
                child: Text(l10n.previewNewPassword),
              ),
          ],
        ),
      ),
    );
  }
}
