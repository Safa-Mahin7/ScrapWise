import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/scrap_price_model.dart';
import '../../services/household_api_service.dart';

/// Modal sheet or embedded view for the Local Scrap Price Board.
/// Respects strict rule: Never hardcode fabricated live rates.
class ScrapPriceBoardSheet extends StatefulWidget {
  const ScrapPriceBoardSheet({
    super.key,
    this.apiService,
  });

  final HouseholdApiService? apiService;

  static Future<void> show(BuildContext context, {HouseholdApiService? apiService}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ScrapPriceBoardSheet(apiService: apiService),
    );
  }

  @override
  State<ScrapPriceBoardSheet> createState() => _ScrapPriceBoardSheetState();
}

class _ScrapPriceBoardSheetState extends State<ScrapPriceBoardSheet> {
  late final HouseholdApiService _apiService;
  bool _isLoading = true;
  List<ScrapPriceItem> _prices = [];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? HouseholdApiService();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      final items = await _apiService.fetchPriceBoard();
      if (mounted) {
        setState(() {
          _prices = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
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
                    child: Icon(Icons.price_change_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Local Scrap Price Board', style: AppTextStyles.titleLarge),
                        Text(
                          'Indicative market references for Ballari',
                          style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Disclaimer Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Important: All posted prices are indicative references based on trader observations. '
                        'The final transaction rate is mutually agreed on-site with the collector during physical weighing.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : _prices.isEmpty
                        ? _buildEmptyState()
                        : _buildPriceList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 54, color: AppColors.grey600),
            const SizedBox(height: 16),
            const Text(
              'No Verified Price Feeds Available',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Verified local scrap prices will be published once trader rate observations are integrated. '
              'ScrapWise does not invent fake or simulated market rates.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadPrices();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check for Updates'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceList() {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _prices.length,
      separatorBuilder: (_, __) => const Divider(height: 12),
      itemBuilder: (context, index) {
        final item = _prices[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.currency_rupee_rounded, color: AppColors.primary, size: 20),
          ),
          title: Text(item.materialName, style: AppTextStyles.titleMedium),
          subtitle: Text(
            '${item.locality} • ${item.priceSource}',
            style: AppTextStyles.caption,
          ),
          trailing: Text(
            '₹${item.indicativeRatePerKg.toStringAsFixed(1)} / kg',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
