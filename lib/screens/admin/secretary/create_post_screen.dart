import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../../models/post_model.dart';
import '../../../models/idea_model.dart';
import '../../../models/alert_model.dart';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

class CreatePostScreen extends StatefulWidget {
  final IdeaModel? fromIdea;
  const CreatePostScreen({super.key, this.fromIdea});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final StorageService _storageService = StorageService();
  XFile? _image;
  String? _selectedAsset;
  bool _isUploading = false;
  PostType _selectedType = PostType.ordinaire;

  final List<String> _internalAssets = [
    'assets/images/logo.png',
    'assets/images/default_post.jpg',
    'assets/images/default_profile.png',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.fromIdea?.title ?? ''
    );
    
    // Si ça vient d'une idée, on pré-remplit avec le nom du membre en italique simulé
    // En Flutter standard, on peut utiliser des marqueurs ou simplement du texte
    // Ici on va préparer le contenu avec une mention de l'auteur
    String initialContent = '';
    if (widget.fromIdea != null) {
      initialContent = "Suggestion de : ${widget.fromIdea!.memberName}\n\n${widget.fromIdea!.description}";
    }
    _contentController = TextEditingController(text: initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool _isPickingImage = false;

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      // Délai de stabilisation
      await Future.delayed(const Duration(milliseconds: 200));

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recadrer',
              toolbarColor: const Color(0xFF002366),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
            IOSUiSettings(
              title: 'Recadrer',
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.page,
            ),
          ],
        );
      } catch (e) {
        debugPrint("Erreur recadrage: $e");
      }

      final String finalPath = croppedFile?.path ?? image.path;

      setState(() {
        _image = XFile(finalPath);
        _selectedAsset = null;
      });
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _submitPost() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter un contenu.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    final user = Provider.of<UserProvider>(context, listen: false).userProfile;
    final dbService = DatabaseService();
    
    String? imageUrl = _selectedAsset;
    
    if (_image != null) {
      imageUrl = await _storageService.uploadPostImage(_image!);
      if (imageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'envoi de l\'image. Vérifiez votre connexion.')),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
    }

    String description = _contentController.text;
    String title = _titleController.text.trim();
    
    if (title.isEmpty) {
      title = description.length > 30 
          ? '${description.substring(0, 30)}...' 
          : description;
    }

    final post = PostModel(
      id: '',
      title: title,
      content: description,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      authorId: user?.id ?? 'unknown',
      type: _selectedType,
    );

    await dbService.addPost(post);

    // Si ça vient d'une idée, on met à jour le statut de l'idée en 'publiee'
    if (widget.fromIdea != null) {
      await dbService.updateIdea(widget.fromIdea!.id, {'status': IdeaStatus.publiee.name});
      
      // AA to Member
      await dbService.sendAutomaticAlert(
        title: 'Suggestion publiée !',
        details: 'Votre suggestion "${widget.fromIdea!.title}" a été publiée dans le fil d\'actualité.',
        initiatorId: dbService.currentUser?.uid ?? 'system',
        targetType: AlertTarget.manual,
        targetUserIds: [widget.fromIdea!.memberId],
      );
    }
    
    setState(() => _isUploading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réussie !')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fromIdea != null ? 'Publier une suggestion' : 'Nouvelle Publication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.fromIdea != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Suggestion originale :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(widget.fromIdea!.description, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            const Text(
              'Type de Publication',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return ToggleButtons(
                  constraints: BoxConstraints.expand(width: (constraints.maxWidth - 4) / 3),
                  borderRadius: BorderRadius.circular(8),
                  isSelected: [
                    _selectedType == PostType.ordinaire,
                    _selectedType == PostType.officiel,
                    _selectedType == PostType.promotion,
                  ],
                  onPressed: (index) {
                    setState(() {
                      _selectedType = PostType.values[index];
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('Ordinaire', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('Officiel', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('Promotion', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Contenu de la publication',
                helperText: 'Vous pouvez modifier le texte avant de publier.',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 16),
            if (_image != null || _selectedAsset != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedAsset != null
                        ? Image.asset(_selectedAsset!, height: 150, width: double.infinity, fit: BoxFit.cover)
                        : (kIsWeb && _image != null
                            ? FutureBuilder<Uint8List>(
                                future: _image!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) return Image.memory(snapshot.data!, height: 150, width: double.infinity, fit: BoxFit.cover);
                                  return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                                },
                              )
                            : (_image != null ? Image.file(File(_image!.path), height: 150, width: double.infinity, fit: BoxFit.cover) : const SizedBox.shrink())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(blurRadius: 2)]),
                    onPressed: () => setState(() {
                      _image = null;
                      _selectedAsset = null;
                    }),
                  ),
                ],
              ),
            
            const SizedBox(height: 8),
            const Text(
              'Ajouter une image',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Option Galerie
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library),
                          Text('Galerie', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Options Internes
                  ..._internalAssets.map((asset) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedAsset = asset;
                        _image = null;
                      }),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedAsset == asset ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(asset, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Publier maintenant'),
                  ),
          ],
        ),
      ),
    );
  }
}
