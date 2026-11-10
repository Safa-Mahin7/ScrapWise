import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _savePassword() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage = AppLocalizations.of(context).passwordResetUnavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.newPasswordTitle,
      subtitle: l10n.newPasswordHelp,
      onBack: () => context.go(AppConstants.routeLogin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthNotice(message: l10n.newPasswordHelp),
            const SizedBox(height: 20),
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
                if (value.length < 6) return l10n.passwordTooShort;
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
            SwButton(label: l10n.newPasswordTitle, onPressed: _savePassword),
          ],
        ),
      ),
    );
  }
}
