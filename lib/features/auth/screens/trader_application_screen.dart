import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class TraderApplicationScreen extends StatefulWidget {
  const TraderApplicationScreen({super.key});

  @override
  State<TraderApplicationScreen> createState() =>
      _TraderApplicationScreenState();
}

class _TraderApplicationScreenState extends State<TraderApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _localityController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _businessController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage = AppLocalizations.of(context).applicationUnavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.traderApplicationTitle,
      subtitle: l10n.traderApplicationHelp,
      onBack: () => context.go(AppConstants.routeLogin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwTextField(
              controller: _businessController,
              label: l10n.businessName,
              hint: l10n.businessName,
              prefixIcon: Icons.storefront_outlined,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.businessNameRequired
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
              controller: _localityController,
              label: l10n.locality,
              hint: l10n.localityHint,
              prefixIcon: Icons.location_on_outlined,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.localityRequired
                  : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 20),
            SwButton(label: l10n.submitApplication, onPressed: _submit),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  context.go(AppConstants.routeTraderApplicationStatus),
              child: Text(l10n.approvalInfo),
            ),
          ],
        ),
      ),
    );
  }
}
