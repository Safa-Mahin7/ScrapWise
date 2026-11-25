import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class CollectorInvitationScreen extends StatefulWidget {
  const CollectorInvitationScreen({super.key});

  @override
  State<CollectorInvitationScreen> createState() =>
      _CollectorInvitationScreenState();
}

class _CollectorInvitationScreenState extends State<CollectorInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invitationController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _invitationController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _activate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage =
          AppLocalizations.of(context).collectorInvitationRequiredNote;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.collectorInvitationTitle,
      subtitle: l10n.collectorInvitationHelp,
      onBack: () => context.go(AppConstants.routeLogin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwTextField(
              controller: _invitationController,
              label: l10n.invitationCode,
              prefixIcon: Icons.mail_outline_rounded,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.invitationCodeRequired
                  : null,
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _nameController,
              label: l10n.fullName,
              hint: l10n.nameHint,
              prefixIcon: Icons.person_outline_rounded,
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
              inputFormatters: mobileInputFormatters,
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 20),
            SwButton(
              label: l10n.activateInvitation,
              onPressed: _activate,
            ),
          ],
        ),
      ),
    );
  }
}
