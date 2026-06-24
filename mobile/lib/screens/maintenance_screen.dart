import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.18),
                        blurRadius: 48,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.wrench,
                    color: Colors.amber,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 36),

                // Title
                const Text(
                  'Under Maintenance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 14),

                // Subtitle
                const Text(
                  'The service is temporarily unavailable while we perform scheduled maintenance. Please check back soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 48),

                // Sign out button
                TextButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                  },
                  icon: const Icon(LucideIcons.logOut, size: 16, color: Colors.white38),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
