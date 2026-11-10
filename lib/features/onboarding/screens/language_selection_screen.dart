import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sw_button.dart';
import '../providers/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Language selection screen shown on first launch.
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String? _selectedLocale;

  static const List<_LanguageOption> _languages = [
    _LanguageOption(code: 'en', name: 'English', nativeName: 'English'),
    _LanguageOption(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    _LanguageOption(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    _LanguageOption(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    _LanguageOption(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
  ];

  Future<void> _onContinue() async {
    if (_selectedLocale == null) return;
    await ref.read(localeProvider.notifier).setLocale(Locale(_selectedLocale!));
    if (mounted) context.go(AppConstants.routeLanding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const Icon(Icons.language_rounded,
                    size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Select Your Language',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'अपनी भाषा चुनें • ನಿಮ್ಮ ಭಾಷೆ ಆಯ್ಕೆ ಮಾಡಿ',
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 36),
                Expanded(
                  child: ListView.separated(
                    itemCount: _languages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final lang = _languages[index];
                      final isSelected = _selectedLocale == lang.code;
                      return _LanguageTile(
                        language: lang,
                        isSelected: isSelected,
                        onTap: () =>
                            setState(() => _selectedLocale = lang.code),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SwButton(
                  label: 'Continue',
                  onPressed: _selectedLocale != null ? _onContinue : null,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final _LanguageOption language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryLight
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.nativeName,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isSelected ? AppColors.primaryDark : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    language.name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color:
                          isSelected ? AppColors.textSecondary : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  final String code;
  final String name;
  final String nativeName;
}
