import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class GuideSection {
  const GuideSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;
}

/// Educational modal bottom sheet detailing safe segregation, reuse, and e-waste handling.
/// Strictly avoids hazardous dismantling instructions.
class SafeRecoveryGuideSheet extends StatelessWidget {
  const SafeRecoveryGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SafeRecoveryGuideSheet(),
    );
  }

  static const List<GuideSection> sections = [
    GuideSection(
      title: 'Scrap Segregation at Source',
      icon: Icons.auto_delete_outlined,
      items: [
        'Keep dry recyclable paper, cardboard and plastics separated from organic kitchen waste.',
        'Flatten cardboard boxes and tie newspapers into compact bundles to save space and ease weighing.',
        'Rinse beverage bottles and milk pouches to prevent foul odors and contamination.',
        'Keep ferrous (iron/steel) and non-ferrous metals (aluminium, copper, brass) separated for optimal value.',
      ],
    ),
    GuideSection(
      title: 'Reuse & Repair First',
      icon: Icons.build_circle_outlined,
      items: [
        'Before discarding gadgets, check for software resets or battery replacements by certified technicians.',
        'Functional smartphones, tablets and laptops can be donated or refurbished for students.',
        'Save original power adapters and cables with their devices to increase recovery and reuse viability.',
      ],
    ),
    GuideSection(
      title: 'Safe Handling of Electronic Waste',
      icon: Icons.warning_amber_rounded,
      items: [
        'NEVER puncture, crush, or open lithium-ion batteries; damaged batteries can ignite spontaneously.',
        'Store cracked screens or swollen batteries in a cool, dry place away from flammable materials.',
        'Avoid self-dismantling electronic circuits or monitors: professional recycling uses non-polluting mechanical shredding.',
        'Cover exposed battery terminals with non-conductive electrical tape before handing over.',
      ],
    ),
    GuideSection(
      title: 'Responsible Recycling',
      icon: Icons.recycling_rounded,
      items: [
        'Informal burning of plastic casings or acid-washing of PCBs emits toxic dioxins and heavy metal runoff.',
        'Hand over recyclable scrap to authorized ScrapWise collectors who channel materials directly to verified recycling hubs.',
        'Household scrap collection reduces municipal landfill load and saves raw mining energy.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceVariant,
                    child: Icon(Icons.eco_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Safe Recovery Guide', style: AppTextStyles.titleLarge),
                        Text(
                          'Best practices for responsible household recycling',
                          style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.grey100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(section.icon, color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  section.title,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...section.items.map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: AppColors.primary)),
                                  Expanded(
                                    child: Text(tip, style: AppTextStyles.bodyMedium),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
