import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import 'notification_sheet.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight ? const Color(0xFF334155) : Colors.white;
    final badgeBorderColor = isLight ? Colors.white : const Color(0xFF0F172A);

    return Consumer<NotificationService>(
      builder: (context, notifService, _) {
        final unreadCount = notifService.unreadCount;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, size: 20),
              color: unreadCount > 0 ? (isLight ? const Color(0xFF4F46E5) : Colors.white) : iconColor,
              tooltip: 'Notifications',
              onPressed: () => NotificationSheet.show(context),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeBorderColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
