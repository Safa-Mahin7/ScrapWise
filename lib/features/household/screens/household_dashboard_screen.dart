import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/session_controller.dart';

/// The household's UI-only home. Pickup submission/history require the
/// account-scoped backend APIs planned for a later integration phase.
class HouseholdDashboardScreen extends StatefulWidget {
  const HouseholdDashboardScreen({super.key, this.sessionController});

  /// Optional injection keeps widget tests isolated from platform storage.
  final SessionController? sessionController;

  @override
  State<HouseholdDashboardScreen> createState() =>
      _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends State<HouseholdDashboardScreen> {
  late final SessionController _session;
  int _selectedTab = 0;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionController ?? SessionController.instance;
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await _session.signOut();
    } catch (_) {
      // SignOut clears local credentials even if server revocation fails.
      // We cannot guarantee the server token has been revoked in this case.
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _showPickupPreview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceVariant,
                child: Icon(Icons.event_available_outlined,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Request a scrap pickup',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Booking is not available yet. This preview shows what you '
                'will be able to provide when the secure pickup API is ready.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              const _PreviewStep(
                icon: Icons.category_outlined,
                title: 'Choose materials',
                description: 'Paper, plastic, metal and other scrap',
              ),
              const _PreviewStep(
                icon: Icons.calendar_month_outlined,
                title: 'Choose a date and time',
                description: 'Select your preferred pickup slot',
              ),
              const _PreviewStep(
                icon: Icons.location_on_outlined,
                title: 'Confirm the exact location',
                description: 'A locality alone is not a pickup address',
              ),
              const _PreviewStep(
                icon: Icons.scale_outlined,
                title: 'No weight entry required',
                description: 'The collector weighs scrap during the visit',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _session.user;
    final name = (user?['full_name'] as String?)?.trim() ?? '';
    final firstName = name.isEmpty ? 'there' : name.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.recycling_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('ScrapWise', style: AppTextStyles.titleLarge),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View profile',
            onPressed: () => setState(() => _selectedTab = 2),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_selectedTab),
                child: switch (_selectedTab) {
                  0 => _buildHome(firstName),
                  1 => _buildActivity(),
                  _ => _buildProfile(user),
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHome(String firstName) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Hello, $firstName', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        const Text('Welcome to your household space.',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.eco_outlined, size: 40, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Give your scrap a new purpose',
                style:
                    AppTextStyles.headlineMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Plan a doorstep collection and keep useful materials '
                'out of the waste stream.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                ),
                onPressed: _showPickupPreview,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Request Pickup'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text('How it works', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        const _JourneyCard(
          number: '01',
          icon: Icons.event_note_outlined,
          title: 'Request a collection',
          description: 'Choose materials, a date and a pickup location.',
        ),
        const SizedBox(height: 10),
        const _JourneyCard(
          number: '02',
          icon: Icons.scale_outlined,
          title: 'Collector weighs your scrap',
          description: 'Actual weight and agreed rates are recorded on site.',
        ),
        const SizedBox(height: 10),
        const _JourneyCard(
          number: '03',
          icon: Icons.verified_outlined,
          title: 'Confirm the collection',
          description: 'Review the final transaction or raise a dispute.',
        ),
        const SizedBox(height: 24),
        const _InfoPanel(
          icon: Icons.info_outline,
          title: 'Pickup integration is next',
          message: 'This dashboard is connected to your authenticated '
              'profile. Pickup booking and personal activity will be '
              'connected once the backend enforces account ownership.',
        ),
      ],
    );
  }

  Widget _buildActivity() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
      children: const [
        Text('Pickup activity', style: AppTextStyles.headlineMedium),
        SizedBox(height: 8),
        Text('Your collections, all in one place.',
            style: AppTextStyles.bodyMedium),
        SizedBox(height: 60),
        Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 58),
        SizedBox(height: 20),
        Center(
          child: Text('Personal pickup history is not connected yet',
              textAlign: TextAlign.center, style: AppTextStyles.titleLarge),
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            'When account-specific pickup history becomes available, '
            'your requests and collection statuses will appear here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildProfile(Map<String, dynamic>? user) {
    final fullName = (user?['full_name'] as String?)?.trim();
    final mobile = (user?['mobile'] as String?)?.trim();
    final verified = user?['phone_verified'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
      children: [
        const Text('Your profile', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 6),
        const Text('Account details from your verified session.',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.surfaceVariant,
                child: Icon(Icons.person_outline_rounded,
                    size: 32, color: AppColors.primary),
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
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: _signingOut ? null : _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(_signingOut ? 'Signing out...' : 'Sign Out'),
        ),
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$number  $title', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 5),
                  Text(description, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end, style: AppTextStyles.titleMedium),
          ),
        ],
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 5),
                  Text(message, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
}
