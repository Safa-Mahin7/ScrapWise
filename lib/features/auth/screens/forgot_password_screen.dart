import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
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
            AuthNotice(message: l10n.otpNotSentMessage),
            const SizedBox(height: 20),
            SwButton(
              label: l10n.sendCode,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                context.go(
                  '/otp/password-recovery',
                  extra: _mobileController.text,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
