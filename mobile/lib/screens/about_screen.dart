import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'v1.0.3';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted && packageInfo.version.isNotEmpty) {
        setState(() {
          _version = 'v${packageInfo.version}';
        });
      }
    } catch (_) {
      // Keep default version
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleUpiPayment() async {
    const upiId = 'expensetracker@ybl';
    final upiUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=Rupam%20Bairagya&cu=INR&tn=Support%20NeoFiles%20Transfer',
    );

    bool launched = false;
    try {
      if (await canLaunchUrl(upiUri)) {
        launched = await launchUrl(
          upiUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          upiUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      // Fallback: Copy UPI ID to clipboard
      await Clipboard.setData(const ClipboardData(text: upiId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(LucideIcons.copy, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('No UPI app found. UPI ID copied: $upiId'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF070B14);
    final cardBg = isLight ? Colors.white : const Color(0xFF0F172A).withOpacity(0.7);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06);
    final titleTextColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subtitleTextColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final sectionHeaderColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About',
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero App Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: cardBorder),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Column(
                children: [
                  // App Logo Container with Glow Effect
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF02101B), Color(0xFF0B1E33)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          LucideIcons.fileSpreadsheet,
                          color: Color(0xFF00E5FF),
                          size: 36,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // App Title
                  Text(
                    'NEO FILES TRANSFER',
                    style: TextStyle(
                      color: titleTextColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline with Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Fast',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text(
                        'Secure',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text(
                        'Cloud File Transfer',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Badges (Version & Release Build)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          _version,
                          style: TextStyle(
                            color: isLight ? const Color(0xFF475569) : Colors.grey.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          'RELEASE BUILD',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF475569) : Colors.grey.shade300,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Official Website
            _buildSectionHeader('Official Website', sectionHeaderColor),
            const SizedBox(height: 10),
            _buildCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              isLight: isLight,
              child: _buildItemTile(
                icon: LucideIcons.globe,
                iconBg: const Color(0xFF10B981).withOpacity(0.12),
                iconColor: const Color(0xFF10B981),
                title: 'Official App Website',
                subtitle: 'neofilestransfer.site • Tap to visit',
                titleTextColor: titleTextColor,
                subtitleTextColor: subtitleTextColor,
                isLight: isLight,
                onTap: () => _launchExternalUrl('https://neofilestransfer.site'),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Developer
            _buildSectionHeader('Developer', sectionHeaderColor),
            const SizedBox(height: 10),
            _buildCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              isLight: isLight,
              child: Column(
                children: [
                  _buildItemTile(
                    icon: LucideIcons.globe,
                    iconBg: const Color(0xFF3B82F6).withOpacity(0.12),
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Website',
                    subtitle: 'link-flow-program.vercel.app/rupam-bairagya',
                    titleTextColor: titleTextColor,
                    subtitleTextColor: subtitleTextColor,
                    isLight: isLight,
                    onTap: () => _launchExternalUrl('https://link-flow-program.vercel.app/rupam-bairagya'),
                  ),
                  _buildDivider(cardBorder),
                  _buildItemTile(
                    icon: LucideIcons.code2,
                    iconBg: const Color(0xFF6366F1).withOpacity(0.12),
                    iconColor: const Color(0xFF6366F1),
                    title: 'GitHub',
                    subtitle: 'github.com/Rupam852',
                    titleTextColor: titleTextColor,
                    subtitleTextColor: subtitleTextColor,
                    isLight: isLight,
                    onTap: () => _launchExternalUrl('https://github.com/Rupam852'),
                  ),
                  _buildDivider(cardBorder),
                  _buildItemTile(
                    icon: LucideIcons.camera,
                    iconBg: const Color(0xFFEC4899).withOpacity(0.12),
                    iconColor: const Color(0xFFEC4899),
                    title: 'Instagram',
                    subtitle: '@_rupambairagya_',
                    titleTextColor: titleTextColor,
                    subtitleTextColor: subtitleTextColor,
                    isLight: isLight,
                    onTap: () => _launchExternalUrl('https://instagram.com/_rupambairagya_'),
                  ),
                  _buildDivider(cardBorder),
                  _buildItemTile(
                    icon: LucideIcons.briefcase,
                    iconBg: const Color(0xFF0284C7).withOpacity(0.12),
                    iconColor: const Color(0xFF0284C7),
                    title: 'LinkedIn',
                    subtitle: 'rupam-bairagya',
                    titleTextColor: titleTextColor,
                    subtitleTextColor: subtitleTextColor,
                    isLight: isLight,
                    onTap: () => _launchExternalUrl('https://linkedin.com/in/rupam-bairagya'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Contact & Support
            _buildSectionHeader('Contact & Support', sectionHeaderColor),
            const SizedBox(height: 10),
            _buildCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              isLight: isLight,
              child: Column(
                children: [
                  _buildItemTile(
                    icon: LucideIcons.mail,
                    iconBg: const Color(0xFFF59E0B).withOpacity(0.12),
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Email Support',
                    subtitle: 'rupambairagya08@gmail.com',
                    titleTextColor: titleTextColor,
                    subtitleTextColor: subtitleTextColor,
                    isLight: isLight,
                    onTap: () => _launchExternalUrl('mailto:rupambairagya08@gmail.com'),
                  ),
                  _buildDivider(cardBorder),
                  _buildItemTile(
                    icon: LucideIcons.heartHandshake,
                    iconBg: const Color(0xFF10B981).withOpacity(0.12),
                    iconColor: const Color(0xFF10B981),
                    title: 'Support & Donate (UPI)',
                    subtitle: 'expensetracker@ybl • Tap to Pay',
                    titleTextColor: titleTextColor,
                    subtitleTextColor: subtitleTextColor,
                    isLight: isLight,
                    onTap: _handleUpiPayment,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Footer
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Proudly Made in India ',
                    style: TextStyle(
                      color: subtitleTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    '🇮🇳',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCard({
    required Color cardBg,
    required Color cardBorder,
    required bool isLight,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: cardBorder),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _buildDivider(Color cardBorder) {
    return Divider(
      height: 1,
      thickness: 1,
      color: cardBorder,
      indent: 64,
      endIndent: 16,
    );
  }

  Widget _buildItemTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color titleTextColor,
    required Color subtitleTextColor,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleTextColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: isLight ? const Color(0xFF94A3B8) : Colors.white30,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
