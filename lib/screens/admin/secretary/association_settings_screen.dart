import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _facebookController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _tiktokController = TextEditingController();
  
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
      _emailController.text = doc['email'] ?? '';
      _phoneController.text = doc['phone'] ?? '';
      _addressController.text = doc['address'] ?? '';
      _websiteController.text = doc['website'] ?? '';
      _youtubeController.text = doc['youtube'] ?? '';
      _facebookController.text = doc['facebook'] ?? '';
      _whatsappController.text = doc['whatsapp'] ?? '';
      _tiktokController.text = doc['tiktok'] ?? '';
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
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    _whatsappController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  bool _isPickingLogo = false;

  Future<void> _pickLogo() async {
    if (_isPickingLogo) return;
    setState(() => _isPickingLogo = true);

    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (img != null) {
        CroppedFile? croppedFile;
        try {
          croppedFile = await ImageCropper().cropImage(
            sourcePath: img.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Recadrer le logo',
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
                hideBottomControls: true,
              ),
              IOSUiSettings(
                title: 'Recadrer le logo',
                aspectRatioLockEnabled: true,
              ),
              WebUiSettings(
                context: context,
                presentStyle: WebPresentStyle.page,
              ),
            ],
          );
        } catch (e) {
          debugPrint("Erreur recadrage logo: $e");
        }

        final String finalPath = croppedFile?.path ?? img.path;
        setState(() => _newLogoFile = XFile(finalPath));
      }
    } catch (e) {
      debugPrint("Error picking logo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingLogo = false);
      }
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
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'website': _websiteController.text.trim(),
        'youtube': _youtubeController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'tiktok': _tiktokController.text.trim(),
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
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Coordonnées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de contact',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'N° de téléphone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse du siège',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Site Web',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Réseaux Sociaux', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook (URL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.facebook),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _whatsappController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp (Lien ou N°)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.chat),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _youtubeController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube (URL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.play_circle_fill),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _tiktokController,
                  decoration: const InputDecoration(
                    labelText: 'TikTok (URL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.music_note),
                  ),
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
