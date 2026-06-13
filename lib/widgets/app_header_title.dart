import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../models/member_model.dart';

class AppHeaderTitle extends StatelessWidget {
  final bool showRole;
  const AppHeaderTitle({super.key, this.showRole = false});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userProfile;
    final dbService = DatabaseService();

    return StreamBuilder<Map<String, dynamic>>(
      stream: dbService.getAssociationSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data ?? {};
        final assocName = settings['name'] ?? 'Swee';
        final logoUrl = settings['logoUrl'];

        return Row(
          children: [
            // Miniature Logo
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: ClipOval(
                child: logoUrl != null
                    ? Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildDefaultIcon())
                    : _buildDefaultIcon(),
              ),
            ),
            const SizedBox(width: 10),
            // Name and Username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    assocName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _getSubtitle(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getSubtitle(MemberModel? user) {
    if (user == null) return '';
    
    // Si on n'est pas sur une page admin, on affiche juste le handle
    if (!showRole || user.role == UserRole.membre) {
      return '@${user.username}';
    }
    
    String roleTitle = '';
    switch (user.role) {
      case UserRole.secretaire:
        roleTitle = 'Secrétaire';
        break;
      case UserRole.tresorier:
        roleTitle = 'Trésorier';
        break;
      case UserRole.president:
        roleTitle = 'Président';
        break;
      case UserRole.conseiller:
        roleTitle = 'Conseiller';
        break;
      default:
        return '@${user.username}';
    }
    
    return '$roleTitle @${user.username}';
  }

  Widget _buildDefaultIcon() {
    return Image.asset('assets/images/logo.png', fit: BoxFit.contain, 
      errorBuilder: (c,e,s) => const Icon(Icons.shield, size: 20, color: AppTheme.gold));
  }
}
