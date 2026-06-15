import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import 'package:intl/intl.dart';
import '../auth/auth_wrapper.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isEditing = false;
  bool _isUploading = false;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  DateTime? _selectedBirthDate;
  String? _selectedGenre;
  
  XFile? _newProfileImage;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final user = Provider.of<UserProvider>(context, listen: false).userProfile;
    _phoneController = TextEditingController(text: user?.telephone);
    _addressController = TextEditingController(text: user?.adresse);
    _firstNameController = TextEditingController(text: user?.prenom);
    _lastNameController = TextEditingController(text: user?.nom);
    _selectedBirthDate = user?.dateNaissance;
    _selectedGenre = user?.genre;
    _newProfileImage = null;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer la photo',
            toolbarColor: AppTheme.darkBlue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Recadrer la photo',
            aspectRatioLockEnabled: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.page,
            size: const CropperSize(width: 400, height: 400),
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _newProfileImage = XFile(croppedFile.path);
          _isEditing = true; 
        });
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  void _submitUpdate() async {
    final user = Provider.of<UserProvider>(context, listen: false).userProfile;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      debugPrint("MyProfileScreen: Tentative de soumission...");
      String? uploadedImageUrl;
      if (_newProfileImage != null) {
        debugPrint("MyProfileScreen: Upload de la nouvelle photo...");
        uploadedImageUrl = await StorageService().uploadProfileImage(_newProfileImage!, user.id);
        debugPrint("MyProfileScreen: Photo uploadée: $uploadedImageUrl");
      }

      final Map<String, dynamic> updates = {
        'telephone': _phoneController.text.trim(),
        'adresse': _addressController.text.trim(),
        'prenom': _firstNameController.text.trim(),
        'nom': _lastNameController.text.trim(),
        'genre': _selectedGenre,
      };

      if (_selectedBirthDate != null) {
        updates['dateNaissance'] = Timestamp.fromDate(_selectedBirthDate!);
      }

      if (uploadedImageUrl != null) {
        updates['photoUrl'] = uploadedImageUrl;
      }

      debugPrint("MyProfileScreen: Envoi à DatabaseService: $updates");
      await DatabaseService().updateMember(user.id, {
        'pendingModifications': updates,
      });
      debugPrint("MyProfileScreen: Succès de l'update Firestore");

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande de modification envoyée au Secrétaire.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).userProfile;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (user == null) return const Center(child: CircularProgressIndicator());

    ImageProvider? profileImage;
    if (_newProfileImage != null) {
      profileImage = NetworkImage(_newProfileImage!.path);
    } else if (user.photoUrl.isNotEmpty) {
      profileImage = NetworkImage(user.photoUrl);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickAndCropImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: isDark ? AppTheme.gold : AppTheme.darkBlue,
                        backgroundImage: profileImage,
                        child: (profileImage == null)
                          ? Icon(
                              Icons.person, 
                              size: 60, 
                              color: isDark ? AppTheme.deepNavy : Colors.white
                            )
                          : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndCropImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? AppTheme.deepNavy : Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: AppTheme.darkBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              if (_isEditing) ...[
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 12),
                _buildInfoTile('Email', user.email, isDark),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController, 
                  decoration: const InputDecoration(labelText: 'Téléphone')
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController, 
                  decoration: const InputDecoration(labelText: 'Adresse')
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date de naissance'),
                  subtitle: Text(_selectedBirthDate != null ? DateFormat('dd/MM/yyyy').format(_selectedBirthDate!) : 'Non définie'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickBirthDate,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGenre,
                  decoration: const InputDecoration(labelText: 'Genre'),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Masculin')),
                    DropdownMenuItem(value: 'F', child: Text('Féminin')),
                  ],
                  onChanged: (val) => setState(() => _selectedGenre = val),
                ),
                const SizedBox(height: 30),
                if (_isUploading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  ElevatedButton(
                    onPressed: _submitUpdate, 
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Soumettre pour validation')
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() => _isEditing = false);
                      _initControllers(); 
                    }, 
                    child: const Text('Annuler')
                  ),
                ],
              ] else ...[
                _buildInfoTile('Nom', '${user.prenom} ${user.nom}', isDark),
                _buildInfoTile('Email', user.email, isDark),
                _buildInfoTile('Date de naissance', DateFormat('dd/MM/yyyy').format(user.dateNaissance), isDark),
                _buildInfoTile('Genre', user.genre == 'M' ? 'Masculin' : 'Féminin', isDark),
                _buildInfoTile('Téléphone', user.telephone, isDark),
                _buildInfoTile('Adresse', user.adresse, isDark),
                const Divider(height: 40),
                ElevatedButton(
                  onPressed: () {
                    _initControllers();
                    setState(() => _isEditing = true);
                  }, 
                  child: const Text('Modifier mes infos')
                ),
              ],
              
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false,
                    );
                  }
                },
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
      },
    );
  }

  Widget _buildInfoTile(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
          Text(value, 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w500, 
              color: isDark ? Colors.white : Colors.black87
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
