import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.isLoading = false});

  final bool isLoading;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  String? _errorMessage;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onSignIn() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _errorMessage = l10n.authUnavailable);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.info_outline,
            color: Theme.of(context).colorScheme.error),
        title: Text(l10n.authPendingTitle),
        content: Text(l10n.authPendingMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.signInToAccount,
      subtitle: AppConstants.appName,
      onBack: () => context.go(AppConstants.routeLanding),
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
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _onSignIn(),
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.passwordRequired;
                }
                if (value.length < 6) return l10n.passwordTooShort;
                return null;
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.go(AppConstants.routeForgotPassword),
                child: Text(l10n.forgotPassword),
              ),
            ),
            if (_errorMessage != null) ...[
              AuthNotice(message: _errorMessage!, isError: true),
              const SizedBox(height: 16),
            ],
            SwButton(
              label: l10n.signIn,
              onPressed: _onSignIn,
              isLoading: widget.isLoading,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.noAccount, style: AppTextStyles.bodySmall),
                TextButton(
                  onPressed: () => context.go(AppConstants.routeRegister),
                  child: Text(l10n.createAccount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
