import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).userProfile;
    _phoneController = TextEditingController(text: user?.telephone);
    _addressController = TextEditingController(text: user?.adresse);
  }

  void _submitUpdate() async {
    final user = Provider.of<UserProvider>(context, listen: false).userProfile;
    if (user == null) return;

    final updates = {
      'telephone': _phoneController.text,
      'adresse': _addressController.text,
    };

    await DatabaseService().updateMember(user.id, {
      'pendingModifications': updates,
    });

    setState(() => _isEditing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande de modification envoyée au Secrétaire.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).userProfile;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: isDark ? AppTheme.gold : AppTheme.darkBlue,
              child: Icon(
                Icons.person, 
                size: 50, 
                color: isDark ? AppTheme.deepNavy : Colors.white
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoTile('Nom', '${user.prenom} ${user.nom}', isDark),
          _buildInfoTile('Email', user.email, isDark),
          _buildInfoTile('Date de naissance', DateFormat('dd/MM/yyyy').format(user.dateNaissance), isDark),
          
          const Divider(height: 40),
          
          Text('PRÉFÉRENCES D\'AFFICHAGE', 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: isDark ? AppTheme.gold : AppTheme.darkBlue,
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text('Mode Sombre', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(isDark ? 'Activé' : 'Désactivé'),
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: isDark ? AppTheme.gold : AppTheme.darkBlue,
              ),
              value: isDark,
              onChanged: (bool value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          const Divider(height: 40),

          if (_isEditing) ...[
            TextField(
              controller: _phoneController, 
              decoration: const InputDecoration(labelText: 'Téléphone')
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController, 
              decoration: const InputDecoration(labelText: 'Adresse')
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submitUpdate, child: const Text('Soumettre pour validation')),
            TextButton(onPressed: () => setState(() => _isEditing = false), child: const Text('Annuler')),
          ] else ...[
            _buildInfoTile('Téléphone', user.telephone, isDark),
            _buildInfoTile('Adresse', user.adresse, isDark),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => setState(() => _isEditing = true), child: const Text('Modifier mes infos')),
          ],
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => AuthService().signOut(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1), 
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }
}
