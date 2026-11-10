import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_components.dart';

class TraderApplicationStatusScreen extends StatelessWidget {
  const TraderApplicationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenShell(
      title: l10n.pendingApprovalTitle,
      subtitle: l10n.pendingApprovalHelp,
      onBack: () => context.go(AppConstants.routeTraderApplication),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 48,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.illustrativeStatus,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.go(AppConstants.routeLogin),
            child: Text(l10n.signIn),
          ),
        ],
      ),
    );
  }
}
