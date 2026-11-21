import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/ewaste_model.dart';

/// E-Waste Intelligence Screen.
/// Form for device photography, optional specs, and AI recommendations.
/// Respects strict safety rule: Never generate fictional AI predictions.
class EWasteTab extends StatefulWidget {
  const EWasteTab({
    super.key,
    required this.onOpenGuide,
  });

  final VoidCallback onOpenGuide;

  @override
  State<EWasteTab> createState() => _EWasteTabState();
}

class _EWasteTabState extends State<EWasteTab> {
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _issuesController = TextEditingController();
  int? _ageYears = 3;

  bool _imageSelected = false;
  String? _selectedImageName;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _issuesController.dispose();
    super.dispose();
  }

  void _simulateImagePick() {
    setState(() {
      _imageSelected = true;
      _selectedImageName = 'device_photo_sample.jpg';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceVariant,
              child: Icon(Icons.memory_rounded, color: AppColors.primary, size: 22),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('E-Waste Intelligence', style: AppTextStyles.headlineMedium),
                  SizedBox(height: 2),
                  Text(
                    'Assess discarded electronics with AI assistance',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Service Availability Alert Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.secondaryDark.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.construction_rounded, color: AppColors.secondaryDark, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Service Under Integration',
                      style: TextStyle(
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'The FastAPI E-waste endpoint (/api/e-waste/assessments) is currently in development by the ML team. '
                      'ScrapWise does not display fabricated AI scores or invented predictions.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Image Selection Container
        const Text('Device Photograph', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: _simulateImagePick,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _imageSelected ? AppColors.primary : AppColors.grey300,
                width: _imageSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _imageSelected ? Icons.check_circle_outline_rounded : Icons.camera_alt_outlined,
                    size: 44,
                    color: _imageSelected ? AppColors.primary : AppColors.grey600,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _imageSelected
                        ? 'Image Attached: $_selectedImageName'
                        : 'Tap to select or capture device image',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: _imageSelected ? AppColors.primaryDark : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Clear photos of the front and back ensure accurate classification.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Optional Device Information Form
        const Text('Optional Device Details', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'e.g. Samsung, HP',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g. Galaxy S10',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _ageYears,
          decoration: const InputDecoration(labelText: 'Approximate Age (Years)'),
          items: [1, 2, 3, 4, 5, 7, 10].map((years) {
            return DropdownMenuItem(
              value: years,
              child: Text('$years ${years == 1 ? "year" : "years"} old'),
            );
          }).toList(),
          onChanged: (val) => setState(() => _ageYears = val),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _issuesController,
          decoration: const InputDecoration(
            labelText: 'Observed Issues / Symptoms',
            hintText: 'e.g. Broken screen, power fault, water damage',
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 20),

        // Assessment Submission Button (Disabled / Honest State)
        FilledButton.icon(
          onPressed: null, // Disabled until backend assessment endpoint is deployed
          icon: const Icon(Icons.psychology_outlined),
          label: const Text('Submit for AI Assessment (Endpoint Pending)'),
        ),

        const SizedBox(height: 28),

        // Recommendation Tiers Explanation
        const Text('Assessment Action Categories', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        _buildActionTierCard(
          action: RecommendedAction.repair,
          description: 'Device exhibits minor or modular issues suitable for local repair or battery replacement.',
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        _buildActionTierCard(
          action: RecommendedAction.resale,
          description: 'Fully functioning or refurbished equipment suitable for donation or second-hand marketplace.',
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 8),
        _buildActionTierCard(
          action: RecommendedAction.recycle,
          description: 'Non-repairable or severely damaged items routed to authorized e-waste recovery centers.',
          color: AppColors.secondaryDark,
        ),
        const SizedBox(height: 8),
        _buildActionTierCard(
          action: RecommendedAction.manualInspection,
          description: 'Complex or unclassified electronics requiring physical inspection by an authorized specialist.',
          color: Colors.purple.shade700,
        ),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: widget.onOpenGuide,
          icon: const Icon(Icons.health_and_safety_outlined),
          label: const Text('Read Safe E-Waste Handling Guide'),
        ),
      ],
    );
  }

  Widget _buildActionTierCard({
    required RecommendedAction action,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              action.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
