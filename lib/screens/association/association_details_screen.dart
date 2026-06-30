import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class AssociationDetailsScreen extends StatelessWidget {
  const AssociationDetailsScreen({super.key});

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    // Add protocol if missing
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    final Uri uri = Uri.parse(finalUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $finalUrl');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(' ', ''),
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('Error making phone call: $e');
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('Error sending email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infos de l\'Association'),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: dbService.getAssociationSettings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snapshot.data ?? {};
          final name = settings['name'] ?? 'Swee';
          final slogan = settings['slogan'] ?? '';
          final logoUrl = settings['logoUrl'];
          final email = settings['email'] ?? '';
          final phone = settings['phone'] ?? '';
          final address = settings['address'] ?? '';
          final website = settings['website'] ?? '';
          final facebook = settings['facebook'] ?? '';
          final whatsapp = settings['whatsapp'] ?? '';
          final youtube = settings['youtube'] ?? '';
          final tiktok = settings['tiktok'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    color: Colors.white10,
                  ),
                  child: ClipOval(
                    child: logoUrl != null
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                          )
                        : Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.gold),
                  textAlign: TextAlign.center,
                ),
                if (slogan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    slogan,
                    style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 10),
                _buildInfoTile(Icons.email, 'Email', email, () => _sendEmail(email)),
                _buildInfoTile(Icons.phone, 'Téléphone', phone, () => _makePhoneCall(phone)),
                _buildInfoTile(Icons.location_on, 'Adresse', address, null),
                _buildInfoTile(Icons.language, 'Site Web', website, () => _launchUrl(website)),
                const SizedBox(height: 30),
                if (facebook.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || tiktok.isNotEmpty) ...[
                  const Text('Suivez-nous', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    children: [
                      if (facebook.isNotEmpty) _buildSocialIcon(Icons.facebook, () => _launchUrl(facebook)),
                      if (whatsapp.isNotEmpty) _buildSocialIcon(Icons.chat_bubble, () => _launchUrl(whatsapp)),
                      if (youtube.isNotEmpty) _buildSocialIcon(Icons.play_circle_fill, () => _launchUrl(youtube)),
                      if (tiktok.isNotEmpty) _buildSocialIcon(Icons.music_note, () => _launchUrl(tiktok)),
                    ],
                  ),
                ],
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Swee App v1.0.7',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  '© ${DateTime.now().year} - Canal d\'information de l\'association',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, VoidCallback? onTap) {
    if (value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.gold, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 28, color: AppTheme.gold),
      ),
    );
  }
}
