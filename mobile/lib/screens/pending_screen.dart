import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';

class PendingScreen extends StatelessWidget {
  const PendingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isPaused = authService.isPaused;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          SystemNavigator.pop();
        },
        child: Stack(
          children: [
          // Ambient lighting
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isPaused ? Colors.red : Colors.indigo)
                    .withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isPaused ? Colors.red : Colors.indigo)
                    .withOpacity(0.06),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: GlassContainer(
                borderColor: (isPaused ? Colors.redAccent : Colors.indigoAccent)
                    .withOpacity(0.15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon banner
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (isPaused ? Colors.redAccent : Colors.indigoAccent)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isPaused ? Colors.redAccent : Colors.indigoAccent)
                              .withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        isPaused ? LucideIcons.shieldAlert : LucideIcons.loader,
                        color: isPaused ? Colors.redAccent : Colors.indigoAccent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isPaused ? 'Account Paused' : 'Approval Pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPaused
                          ? 'Your access has been temporarily suspended by the administrator. Your files and data remain secure.'
                          : 'Your request has been submitted. Registration becomes active once approved by an administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isPaused ? Colors.redAccent : Colors.indigoAccent)
                            .withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isPaused ? Colors.redAccent : Colors.indigoAccent)
                              .withOpacity(0.1),
                        ),
                      ),
                      child: const Text(
                        'Please contact developer support.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sign Out Button
                     ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Logout Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            content: const Text(
                              'Are you sure you want to sign out of your session?',
                              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close dialog
                                  authService.signOut();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(LucideIcons.logOut, size: 16),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
