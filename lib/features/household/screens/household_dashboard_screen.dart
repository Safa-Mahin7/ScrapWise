import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/session_controller.dart';
import '../services/household_api_service.dart';
import '../widgets/notifications_sheet.dart';
import 'booking/book_pickup_sheet.dart';
import 'guide/safe_recovery_guide_sheet.dart';
import 'prices/scrap_price_board_sheet.dart';
import 'tabs/ewaste_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/my_pickups_tab.dart';
import 'tabs/profile_tab.dart';

/// The Household Dashboard Screen with 4 primary bottom navigation tabs:
/// 0: Home, 1: My Pickups, 2: E-Waste, 3: Profile.
/// Scrap Prices, Safe Recovery Guide, and Booking are accessible via Home shortcuts.
class HouseholdDashboardScreen extends StatefulWidget {
  const HouseholdDashboardScreen({
    super.key,
    this.sessionController,
    this.apiService,
  });

  /// Optional injection keeps widget tests isolated from platform secure storage.
  final SessionController? sessionController;
  final HouseholdApiService? apiService;

  @override
  State<HouseholdDashboardScreen> createState() =>
      _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends State<HouseholdDashboardScreen> {
  late final SessionController _session;
  late final HouseholdApiService _apiService;
  int _selectedTab = 0;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionController ?? SessionController.instance;
    _apiService = widget.apiService ?? HouseholdApiService();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await _session.signOut();
    } catch (_) {
      // Local credentials cleared even if remote server revocation fails.
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _openBookingSheet() {
    BookPickupSheet.show(
      context,
      apiService: _apiService,
      sessionController: _session,
    );
  }

  void _openPriceBoard() {
    ScrapPriceBoardSheet.show(context, apiService: _apiService);
  }

  void _openRecoveryGuide() {
    SafeRecoveryGuideSheet.show(context);
  }

  void _openNotifications() {
    NotificationsSheet.show(context);
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
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'View profile',
            onPressed: () => setState(() => _selectedTab = 3),
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
                  0 => HomeTab(
                      firstName: firstName,
                      onRequestPickup: _openBookingSheet,
                      onOpenEWaste: () => setState(() => _selectedTab = 2),
                      onOpenPrices: _openPriceBoard,
                      onOpenGuide: _openRecoveryGuide,
                      onViewPickups: () => setState(() => _selectedTab = 1),
                    ),
                  1 => MyPickupsTab(onRequestPickup: _openBookingSheet),
                  2 => EWasteTab(onOpenGuide: _openRecoveryGuide),
                  _ => ProfileTab(
                      user: user,
                      onSignOut: _signOut,
                      signingOut: _signingOut,
                    ),
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
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'My Pickups',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory_rounded),
            label: 'E-Waste',
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
}
