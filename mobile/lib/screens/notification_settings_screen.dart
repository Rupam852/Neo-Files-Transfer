import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final notifService = Provider.of<NotificationService>(context);

    final bgColor = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712);
    final cardBg = isLight ? Colors.white : const Color(0xFF0B1329).withValues(alpha: 0.6);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.06);
    final titleTextColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subtitleTextColor = isLight ? const Color(0xFF64748B) : Colors.white60;
    final sectionHeaderColor = isLight ? const Color(0xFF94A3B8) : Colors.white38;

    final isAllEnabled = notifService.allNotificationsEnabled;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isLight ? Colors.white : Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(
            color: titleTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            fontFamily: 'Space_Grotesk',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Master Toggle Card
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isAllEnabled
                      ? const Color(0xFF6366F1).withValues(alpha: isLight ? 0.3 : 0.4)
                      : cardBorder,
                  width: isAllEnabled ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isAllEnabled
                        ? const Color(0xFF6366F1).withValues(alpha: isLight ? 0.08 : 0.18)
                        : Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAllEnabled
                          ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                          : (isLight ? const Color(0xFFF1F5F9) : Colors.white10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isAllEnabled ? LucideIcons.bellRing : LucideIcons.bellOff,
                      color: isAllEnabled
                          ? const Color(0xFF6366F1)
                          : (isLight ? const Color(0xFF94A3B8) : Colors.white38),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow All Notifications',
                          style: TextStyle(
                            color: titleTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isAllEnabled
                              ? 'Notifications are currently active'
                              : 'All app notifications are muted',
                          style: TextStyle(
                            color: isAllEnabled
                                ? (isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8))
                                : subtitleTextColor,
                            fontSize: 12,
                            fontWeight: isAllEnabled ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAllEnabled,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => notifService.setAllNotifications(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Notification Categories Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NOTIFICATION CATEGORIES',
                  style: TextStyle(
                    color: sectionHeaderColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                if (!isAllEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MUTED',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Sub-Toggles with Animated Opacity
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              opacity: isAllEnabled ? 1.0 : 0.38,
              child: IgnorePointer(
                ignoring: !isAllEnabled,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildCategoryRow(
                        context: context,
                        icon: LucideIcons.download,
                        iconColor: const Color(0xFF10B981),
                        title: 'Download Alerts',
                        subtitle: 'Notify when visitors download your shared files via link',
                        value: notifService.downloadAlertsEnabled,
                        onChanged: (val) => notifService.setDownloadAlerts(val),
                        isLight: isLight,
                      ),
                      const Divider(height: 20),
                      _buildCategoryRow(
                        context: context,
                        icon: LucideIcons.cloudUpload,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Upload Alerts',
                        subtitle: 'Alerts when background file uploads are complete',
                        value: notifService.uploadAlertsEnabled,
                        onChanged: (val) => notifService.setUploadAlerts(val),
                        isLight: isLight,
                      ),
                      const Divider(height: 20),
                      _buildCategoryRow(
                        context: context,
                        icon: LucideIcons.shieldCheck,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Security & Login Alerts',
                        subtitle: 'Notifications for new logins and permission changes',
                        value: notifService.securityAlertsEnabled,
                        onChanged: (val) => notifService.setSecurityAlerts(val),
                        isLight: isLight,
                      ),
                      const Divider(height: 20),
                      _buildCategoryRow(
                        context: context,
                        icon: LucideIcons.sparkles,
                        iconColor: const Color(0xFFA855F7),
                        title: 'App Updates & Releases',
                        subtitle: 'Notices when new features or app updates are available',
                        value: notifService.updateAlertsEnabled,
                        onChanged: (val) => notifService.setUpdateAlerts(val),
                        isLight: isLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!isAllEnabled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: isLight ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, color: Colors.amber, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Master toggle is OFF. All notification categories are muted until enabled.',
                        style: TextStyle(
                          color: isLight ? Colors.amber.shade900 : Colors.amber.shade200,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLight,
  }) {
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.white60;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: subColor,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: const Color(0xFF6366F1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
