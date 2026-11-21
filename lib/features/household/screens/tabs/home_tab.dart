import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../widgets/journey_card.dart';
import '../../widgets/quick_feature_card.dart';
import '../../widgets/info_banner.dart';

/// Household Home Tab overview with hero action, quick shortcuts, and how-it-works guidance.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.firstName,
    required this.onRequestPickup,
    required this.onOpenEWaste,
    required this.onOpenPrices,
    required this.onOpenGuide,
    required this.onViewPickups,
  });

  final String firstName;
  final VoidCallback onRequestPickup;
  final VoidCallback onOpenEWaste;
  final VoidCallback onOpenPrices;
  final VoidCallback onOpenGuide;
  final VoidCallback onViewPickups;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Personalized Greeting
        Text('Hello, $firstName', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        const Text(
          'Welcome to your household space.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),

        // Primary Hero Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.eco_outlined, size: 38, color: Colors.white),
              const SizedBox(height: 14),
              Text(
                'Give your scrap a new purpose',
                style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Plan a doorstep collection and keep useful materials out of the waste stream.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: onRequestPickup,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Request Pickup'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Four Prominent Feature Shortcuts
        const Text('Explore Services', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        QuickFeatureCard(
          title: 'Scrap Collection',
          subtitle: 'Schedule a doorstep collection. Collector weighs on site.',
          icon: Icons.calendar_today_outlined,
          onTap: onRequestPickup,
        ),
        const SizedBox(height: 10),
        QuickFeatureCard(
          title: 'E-Waste Intelligence',
          subtitle: 'Assess discarded electronics for repair, resale or recycling.',
          icon: Icons.memory_rounded,
          accentColor: AppColors.secondaryDark,
          badgeText: 'AI Powered',
          onTap: onOpenEWaste,
        ),
        const SizedBox(height: 10),
        QuickFeatureCard(
          title: 'Local Scrap Prices',
          subtitle: 'View indicative reference rates for Ballari markets.',
          icon: Icons.currency_rupee_rounded,
          onTap: onOpenPrices,
        ),
        const SizedBox(height: 10),
        QuickFeatureCard(
          title: 'Safe Recovery Guide',
          subtitle: 'Segregation best practices, e-waste hazards, and reuse tips.',
          icon: Icons.menu_book_outlined,
          onTap: onOpenGuide,
        ),

        const SizedBox(height: 26),

        // Active Pickup Overview (Truthful State)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Pickup Status', style: AppTextStyles.titleLarge),
            TextButton(
              onPressed: onViewPickups,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No collections currently active',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Once your requested pickup is assigned to a collector, arrival time and collection updates will appear here.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // How It Works Guide
        const Text('How it works', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        const JourneyCard(
          number: '01',
          icon: Icons.event_note_outlined,
          title: 'Request a collection',
          description: 'Choose materials, a date and your pickup location. No weight entry required.',
        ),
        const SizedBox(height: 10),
        const JourneyCard(
          number: '02',
          icon: Icons.scale_outlined,
          title: 'Collector weighs your scrap',
          description: 'Actual weight and mutually agreed rates are recorded on site by the collector.',
        ),
        const SizedBox(height: 10),
        const JourneyCard(
          number: '03',
          icon: Icons.verified_outlined,
          title: 'Confirm the collection',
          description: 'Review the final transaction details or raise a dispute if weights differ.',
        ),

        const SizedBox(height: 24),
        const InfoBanner(
          icon: Icons.shield_outlined,
          title: 'Transparent & Accountable',
          message:
              'ScrapWise ensures fair weighing and direct collector verification. Never pay advance fees for scrap collection.',
        ),
      ],
    );
  }
}
