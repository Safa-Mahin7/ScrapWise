import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/providers/locale_provider.dart';

/// Profile & Settings Tab for Household users.
/// Displays authenticated session details, in-app language switching, and secure sign-out.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.signingOut,
  });

  final Map<String, dynamic>? user;
  final VoidCallback onSignOut;
  final bool signingOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullName = (user?['full_name'] as String?)?.trim();
    final mobile = (user?['mobile'] as String?)?.trim();
    final verified = user?['phone_verified'] == true;
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text('Your profile', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Account details from your verified session.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 24),

        // User Account Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.grey100),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.surfaceVariant,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              _ProfileField(label: 'Full name', value: fullName ?? 'Not set'),
              const Divider(),
              _ProfileField(label: 'Mobile', value: mobile ?? 'Not available'),
              const Divider(),
              const _ProfileField(label: 'Account type', value: 'Household'),
              const Divider(),
              _ProfileField(
                label: 'Mobile verification',
                value: verified ? 'Verified' : 'Not verified',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(l10n.accountSettings, style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.grey100),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.phone_android_rounded,
              color: AppColors.primary,
            ),
            title: Text(l10n.changeMobileAction),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go(AppConstants.routeChangeMobile),
          ),
        ),

        const SizedBox(height: 24),

        // Language Selection Section
        const Text('Preferences & Language', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.translate_rounded,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Text('App Display Language',
                      style: AppTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLanguageChip(
                      ref, 'English', const Locale('en'), currentLocale),
                  _buildLanguageChip(ref, 'ಕನ್ನಡ (Kannada)', const Locale('kn'),
                      currentLocale),
                  _buildLanguageChip(
                      ref, 'हिन्दी (Hindi)', const Locale('hi'), currentLocale),
                  _buildLanguageChip(ref, 'తెలుగు (Telugu)', const Locale('te'),
                      currentLocale),
                  _buildLanguageChip(
                      ref, 'اردو (Urdu)', const Locale('ur'), currentLocale),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Sign Out Button
        OutlinedButton.icon(
          onPressed: signingOut ? null : onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(signingOut ? 'Signing out...' : 'Sign Out'),
        ),
      ],
    );
  }

  Widget _buildLanguageChip(
    WidgetRef ref,
    String label,
    Locale locale,
    Locale? activeLocale,
  ) {
    final isSelected = activeLocale?.languageCode == locale.languageCode ||
        (activeLocale == null && locale.languageCode == 'en');

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(localeProvider.notifier).setLocale(locale);
        }
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: AppTextStyles.titleMedium,
              ),
            ),
          ],
        ),
      );
}
