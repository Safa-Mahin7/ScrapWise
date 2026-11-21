import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    this.isUnread = false,
    this.icon = Icons.notifications_none_rounded,
  });

  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final bool isUnread;
  final IconData icon;
}

/// Modal sheet displaying household notifications and operational alerts.
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Demonstration system notifications; personal notification stream requires websocket/push backend.
    final notifications = <NotificationItem>[
      const NotificationItem(
        id: 'notif-welcome',
        title: 'Welcome to ScrapWise Household!',
        message: 'Book door-step scrap pickups, check indicative prices, and access our Safe Recovery Guide.',
        timeAgo: 'Just now',
        isUnread: true,
        icon: Icons.eco_rounded,
      ),
      const NotificationItem(
        id: 'notif-safe',
        title: 'Safe Segregation Reminder',
        message: 'Keep paper dry and separate batteries before scrap collection visits.',
        timeAgo: '1d ago',
        isUnread: false,
        icon: Icons.health_and_safety_outlined,
      ),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 16),
              if (notifications.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No notifications yet.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ),
              ] else ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: AppTextStyles.titleMedium.copyWith(
                                          fontWeight: item.isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(item.timeAgo, style: AppTextStyles.caption),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item.message, style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
