import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _localityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _localityController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authPendingTitle),
        content: Text(l10n.accountCreationUnavailable),
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
      title: l10n.createAccount,
      subtitle: l10n.selfRegisterNote,
      onBack: () => context.go(AppConstants.routeLanding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwTextField(
              controller: _nameController,
              label: l10n.fullName,
              hint: l10n.nameHint,
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.nameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _mobileController,
              label: l10n.mobileNumber,
              hint: l10n.mobileHint,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              textInputAction: TextInputAction.next,
              inputFormatters: mobileInputFormatters,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _localityController,
              label: l10n.locality,
              hint: l10n.localityHint,
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.localityRequired
                  : null,
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _passwordController,
              label: l10n.password,
              hint: l10n.passwordCreateHint,
              obscureText: true,
              showPasswordLabel: l10n.showPassword,
              hidePasswordLabel: l10n.hidePassword,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
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
              label: l10n.confirmPassword,
              hint: l10n.confirmPasswordHint,
              obscureText: true,
              showPasswordLabel: l10n.showPassword,
              hidePasswordLabel: l10n.hidePassword,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _onRegister(),
              autofillHints: const [AutofillHints.newPassword],
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
            const SizedBox(height: 24),
            SwButton(label: l10n.createAccount, onPressed: _onRegister),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppConstants.routeLogin),
              child: Text(l10n.signIn),
            ),
          ],
        ),
      ),
    );
  }
}
