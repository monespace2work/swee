import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class AssociationSettingsScreen extends StatefulWidget {
  const AssociationSettingsScreen({super.key});

  @override
  State<AssociationSettingsScreen> createState() => _AssociationSettingsScreenState();
}

class _AssociationSettingsScreenState extends State<AssociationSettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  
  final _nameController = TextEditingController();
  final _sloganController = TextEditingController();
  
  XFile? _newLogoFile;
  String? _currentLogoUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // On utilise un get unique au lieu du stream pour initialiser les controllers
      final doc = await _dbService.getAssociationSettings().first;
      _nameController.text = doc['name'] ?? 'Swee';
      _sloganController.text = doc['slogan'] ?? '';
      _currentLogoUrl = doc['logoUrl'];
    } catch (e) {
      if (kDebugMode) print('Error loading settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des paramètres: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    if (img != null) {
      setState(() => _newLogoFile = img);
    }
  }

  void _saveSettings() async {
    if (_dbService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Vous n\'êtes pas authentifié.')),
      );
      return;
    }

    // Demander le mot de passe avant d'enregistrer
    final password = await _showPasswordConfirmationDialog();
    if (password == null) return; // Annulé

    setState(() => _isSaving = true);
    
    try {
      // Re-authentification
      final success = await _authService.reauthenticate(password);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mot de passe incorrect. Action annulée.')),
          );
        }
        return;
      }

      String? finalLogoUrl = _currentLogoUrl;
      
      if (_newLogoFile != null) {
        finalLogoUrl = await _storageService.uploadPostImage(_newLogoFile!);
      }

      await _dbService.updateAssociationSettings({
        'name': _nameController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'logoUrl': finalLogoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres mis à jour avec succès !')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _showPasswordConfirmationDialog() {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation requise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez confirmer votre mot de passe pour modifier les données sensibles de l\'association.'),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            child: const Text('CONFIRMER', style: TextStyle(color: AppTheme.darkBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identité de l\'Association'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickLogo,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.gold, width: 2),
                          image: _newLogoFile != null
                            ? DecorationImage(
                                image: kIsWeb 
                                  ? NetworkImage(_newLogoFile!.path) 
                                  : FileImage(File(_newLogoFile!.path)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : (_currentLogoUrl != null 
                                ? DecorationImage(image: NetworkImage(_currentLogoUrl!), fit: BoxFit.cover)
                                : null),
                        ),
                        child: (_newLogoFile == null && _currentLogoUrl == null)
                          ? const Icon(Icons.business, size: 60, color: AppTheme.gold)
                          : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Logo de l\'Association', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'Association',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _sloganController,
                  decoration: const InputDecoration(
                    labelText: 'Slogan / Devise',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_quote),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 40),
                _isSaving 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.darkBlue,
                      ),
                      child: const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
              ],
            ),
          ),
    );
  }
}
