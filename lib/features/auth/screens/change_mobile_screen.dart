import 'package:flutter/material.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class ChangeMobileScreen extends StatefulWidget {
  const ChangeMobileScreen({super.key});

  @override
  State<ChangeMobileScreen> createState() => _ChangeMobileScreenState();
}

class _ChangeMobileScreenState extends State<ChangeMobileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.changeMobileTitle,
      subtitle: l10n.changeMobileHelp,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwTextField(
              controller: _currentController,
              label: l10n.currentMobile,
              keyboardType: TextInputType.phone,
              inputFormatters: mobileInputFormatters,
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _newController,
              label: l10n.newMobileNumber,
              keyboardType: TextInputType.phone,
              inputFormatters: mobileInputFormatters,
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _message!, isError: true),
            ],
            const SizedBox(height: 20),
            SwButton(
              label: l10n.phoneChangeAction,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                setState(
                  () => _message = l10n.verificationUnavailable,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
