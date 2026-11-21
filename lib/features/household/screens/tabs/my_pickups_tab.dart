import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// My Pickups Tab displaying active, pending, and historical requests.
/// Respects strict security rule: Personal pickup data must come from an
/// authenticated server-authorized household endpoint, not client-filtered global queries.
class MyPickupsTab extends StatelessWidget {
  const MyPickupsTab({
    super.key,
    required this.onRequestPickup,
  });

  final VoidCallback onRequestPickup;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Pickups', style: AppTextStyles.headlineMedium),
                SizedBox(height: 4),
                Text(
                  'Your collection requests and history.',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            IconButton(
              tooltip: 'New Pickup',
              onPressed: onRequestPickup,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Truthful State Representation
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.grey100),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 56,
              ),
              const SizedBox(height: 18),
              const Text(
                'Personal pickup history is not connected yet',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'When account-specific pickup history becomes available, '
                'your requests and collection statuses will appear here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security_outlined, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Security Notice: Personal pickup history requires server-side identity verification. '
                        'ScrapWise does not expose or filter global collection records on the client.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRequestPickup,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Book a New Pickup'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // What happens after booking guide
        const Text('What happens next?', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),
        _buildTimelineStep(
          step: '1',
          title: 'Request Placed',
          subtitle: 'Your requested materials and location are registered.',
        ),
        _buildTimelineStep(
          step: '2',
          title: 'Collector Assigned',
          subtitle: 'Nearby authorized collectors in your locality are clustered.',
        ),
        _buildTimelineStep(
          step: '3',
          title: 'Weighing & Payment',
          subtitle: 'Physical weighing at your doorstep, followed by instant confirmation.',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String step,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.surfaceVariant,
              child: Text(
                step,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: AppColors.grey300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
