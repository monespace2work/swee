import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../models/member_model.dart';
import '../../../models/alert_model.dart';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/user_menu_button.dart';
import '../../../widgets/member_avatar.dart';
import 'package:intl/intl.dart';

enum MemberSortOption { alphabetical, chronological, status, gender }

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  
  // Sorting & Filtering State
  MemberSortOption _sortOption = MemberSortOption.alphabetical;
  bool _isAscending = true;
  String _searchQuery = '';
  UserStatus? _statusFilter;
  String? _genderFilter;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Membres'),
        actions: [
          if (!isLargeScreen)
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
              onPressed: () => setState(() => _showFilters = !_showFilters),
              tooltip: 'Filtres',
            ),
          IconButton(
            icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _isAscending = !_isAscending),
            tooltip: _isAscending ? 'Croissant' : 'Décroissant',
          ),
          PopupMenuButton<MemberSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Trier par',
            onSelected: (MemberSortOption option) {
              setState(() => _sortOption = option);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: MemberSortOption.alphabetical, child: Text('Nom')),
              const PopupMenuItem(value: MemberSortOption.chronological, child: Text('Date d\'inscription')),
              const PopupMenuItem(value: MemberSortOption.status, child: Text('Statut')),
              const PopupMenuItem(value: MemberSortOption.gender, child: Text('Sexe')),
            ],
          ),
          const UserMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemberDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 1200 : double.infinity),
          child: Column(
            children: [
              if (_showFilters || isLargeScreen) _buildFilterPanel(isLargeScreen),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // Les streams se mettent à jour seuls, mais on peut forcer 
                    // un rebuild si on veut ou juste attendre pour l'UX.
                    await Future.delayed(const Duration(milliseconds: 800));
                    if (mounted) setState(() {});
                  },
                  child: StreamBuilder<List<MemberModel>>(
                    stream: _dbService.getMembers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      List<MemberModel> members = snapshot.data!;
                      
                      // 1. Apply Filtering
                      if (_searchQuery.isNotEmpty) {
                        members = members.where((m) => 
                          '${m.prenom} ${m.nom}'.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          m.email.toLowerCase().contains(_searchQuery.toLowerCase())
                        ).toList();
                      }
                      if (_statusFilter != null) {
                        members = members.where((m) => m.status == _statusFilter).toList();
                      }
                      if (_genderFilter != null) {
                        members = members.where((m) => m.genre == _genderFilter).toList();
                      }
      
                      // 2. Apply Sorting
                      members.sort((a, b) {
                        int cmp;
                        switch (_sortOption) {
                          case MemberSortOption.alphabetical:
                            cmp = a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
                            break;
                          case MemberSortOption.chronological:
                            cmp = a.dateInscription.compareTo(b.dateInscription);
                            break;
                          case MemberSortOption.status:
                            cmp = a.status.index.compareTo(b.status.index);
                            break;
                          case MemberSortOption.gender:
                            cmp = a.genre.compareTo(b.genre);
                            break;
                        }
                        return _isAscending ? cmp : -cmp;
                      });
      
                      if (members.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('Aucun membre ne correspond aux critères.')),
                          ],
                        );
                      }
      
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 24 : 8,
                          vertical: 16
                        ),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          if (isLargeScreen) {
                            return _buildWebMemberTile(member);
                          }
                          return _buildMobileMemberTile(member);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMemberTile(MemberModel member) {
    return ListTile(
      leading: MemberAvatar(member: member),
      title: Text('${member.prenom} ${member.nom}'),
      subtitle: Text('Status: ${member.status.name}'),
      trailing: member.pendingModifications != null
          ? const Icon(Icons.pending_actions, color: Colors.orange)
          : const Icon(Icons.chevron_right),
      onTap: () => _showMemberDetails(context, member),
    );
  }

  Widget _buildWebMemberTile(MemberModel member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: MemberAvatar(member: member, radius: 25),
        title: Text('${member.prenom} ${member.nom}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(member.email),
              const SizedBox(width: 24),
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Statut: ${member.status.name}'),
            ],
          ),
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            if (member.pendingModifications != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text('Validation requise', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _showMemberDetails(context, member),
      ),
    );
  }

  Widget _buildFilterPanel(bool isLargeScreen) {
    if (isLargeScreen) {
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher par nom ou email...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<UserStatus?>(
                initialValue: _statusFilter,
                decoration: const InputDecoration(labelText: 'Statut', isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                  ...UserStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                ],
                onChanged: (val) => setState(() => _statusFilter = val),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String?>(
                initialValue: _genderFilter,
                decoration: const InputDecoration(labelText: 'Sexe', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: 'M', child: Text('M')),
                  DropdownMenuItem(value: 'F', child: Text('F')),
                ],
                onChanged: (val) => setState(() => _genderFilter = val),
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () => setState(() {
                _statusFilter = null;
                _genderFilter = null;
                _searchQuery = '';
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Réinitialiser'),
            )
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher par nom ou email...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Statut: '),
                DropdownButton<UserStatus?>(
                  value: _statusFilter,
                  hint: const Text('Tous'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    ...UserStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val),
                ),
                const SizedBox(width: 16),
                const Text('Sexe: '),
                DropdownButton<String?>(
                  value: _genderFilter,
                  hint: const Text('Tous'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'M', child: Text('M')),
                    DropdownMenuItem(value: 'F', child: Text('F')),
                  ],
                  onChanged: (val) => setState(() => _genderFilter = val),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _statusFilter = null;
                    _genderFilter = null;
                    _searchQuery = '';
                  }),
                  child: const Text('Réinitialiser'),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final adresseController = TextEditingController();
    String photoUrl = '';
    bool isUploadingPhoto = false;
    String selectedGenre = 'M';
    DateTime selectedBirthDate = DateTime(1990, 1, 1);
    DateTime registrationDate = DateTime.now();
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    
    // On génère l'ID en avance pour l'upload de l'image
    final newId = FirebaseFirestore.instance.collection('members').doc().id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickImage() async {
            if (isUploadingPhoto) return;
            
            final picker = ImagePicker();
            final XFile? pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 80,
            );
            
            if (pickedFile == null) return;
            if (!context.mounted) return;

            // Recadrage
            CroppedFile? croppedFile;
            try {
              croppedFile = await ImageCropper().cropImage(
                sourcePath: pickedFile.path,
                aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                uiSettings: [
                  AndroidUiSettings(
                    toolbarTitle: 'Recadrer',
                    toolbarColor: const Color(0xFF002366),
                    toolbarWidgetColor: Colors.white,
                    initAspectRatio: CropAspectRatioPreset.square,
                    lockAspectRatio: true,
                    hideBottomControls: true,
                  ),
                  IOSUiSettings(title: 'Recadrer'),
                  WebUiSettings(context: context, presentStyle: WebPresentStyle.page),
                ],
              );
            } catch (e) {
              debugPrint("Erreur recadrage: $e");
            }

            final finalFile = croppedFile != null ? XFile(croppedFile.path) : pickedFile;

            setState(() => isUploadingPhoto = true);
            try {
              final url = await StorageService().uploadProfileImage(finalFile, newId);
              if (url != null) {
                setState(() {
                  photoUrl = url;
                });
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur upload : $e')),
                );
              }
            } finally {
              setState(() => isUploadingPhoto = false);
            }
          }

          return AlertDialog(
            title: const Text('Ajouter un Membre'),
            content: SizedBox(
              width: isLargeScreen ? 500 : null,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: pickImage,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: selectedGenre == 'F' ? Colors.pink[100] : Colors.blue[100],
                              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              child: photoUrl.isEmpty && !isUploadingPhoto
                                  ? Icon(Icons.add_a_photo, size: 30, color: selectedGenre == 'F' ? Colors.pink : Colors.blue)
                                  : isUploadingPhoto 
                                      ? const CircularProgressIndicator()
                                      : null,
                            ),
                          ),
                          if (photoUrl.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                child: const Icon(Icons.check, size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom *')),
                    const SizedBox(height: 12),
                    TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prénom *')),
                    const SizedBox(height: 12),
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *')),
                    const SizedBox(height: 12),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Téléphone')),
                    const SizedBox(height: 12),
                    TextField(controller: adresseController, decoration: const InputDecoration(labelText: 'Adresse')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGenre,
                      decoration: const InputDecoration(labelText: 'Genre *'),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Masculin')),
                        DropdownMenuItem(value: 'F', child: Text('Féminin')),
                      ],
                      onChanged: (val) => setState(() => selectedGenre = val!),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Date de naissance'),
                      subtitle: Text('${selectedBirthDate.day}/${selectedBirthDate.month}/${selectedBirthDate.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedBirthDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => selectedBirthDate = picked);
                      },
                    ),
                    ListTile(
                      title: const Text('Date d\'inscription'),
                      subtitle: Text('${registrationDate.day}/${registrationDate.month}/${registrationDate.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: registrationDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => registrationDate = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: isUploadingPhoto ? null : () async {
                  if (nomController.text.isEmpty || prenomController.text.isEmpty || emailController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez remplir les champs obligatoires (*)')),
                    );
                    return;
                  }

                  final newMember = MemberModel(
                    id: newId,
                    username: emailController.text.split('@').first,
                    email: emailController.text.trim().toLowerCase(),
                    nom: nomController.text.trim(),
                    prenom: prenomController.text.trim(),
                    telephone: phoneController.text.trim(),
                    adresse: adresseController.text.trim(),
                    dateNaissance: selectedBirthDate,
                    genre: selectedGenre,
                    photoUrl: photoUrl,
                    dateInscription: registrationDate,
                    role: UserRole.membre,
                    status: UserStatus.enAttenteTresorier,
                  );
                  await _dbService.createMember(newMember);
                  
                  // AA to Treasurer
                  final treasurerIds = await _dbService.getUserIdsByRole(UserRole.tresorier);
                  await _dbService.sendAutomaticAlert(
                    title: 'Nouveau membre enregistré',
                    details: 'Le secrétaire a enregistré ${newMember.prenom} ${newMember.nom}. En attente de votre validation.',
                    initiatorId: _dbService.currentUser?.uid ?? 'system',
                    targetType: AlertTarget.manual,
                    targetUserIds: treasurerIds,
                    memberId: newId,
                  );

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMemberDetails(BuildContext context, MemberModel member) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    
    if (isLargeScreen) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Détails du Membre'),
                  automaticallyImplyLeading: false,
                  actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                ),
                Expanded(
                  child: MemberDetailsView(
                    member: member, 
                    dbService: _dbService,
                    scrollController: ScrollController(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => MemberDetailsView(
            member: member, 
            dbService: _dbService,
            scrollController: scrollController,
          ),
        ),
      );
    }
  }
}

class MemberDetailsView extends StatefulWidget {
  final MemberModel member;
  final DatabaseService dbService;
  final ScrollController scrollController;

  const MemberDetailsView({
    super.key, 
    required this.member, 
    required this.dbService,
    required this.scrollController,
  });

  @override
  State<MemberDetailsView> createState() => _MemberDetailsViewState();
}

class _MemberDetailsViewState extends State<MemberDetailsView> {
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _phoneController;
  late TextEditingController _adresseController;
  late String _photoUrl;
  bool _isUploadingPhoto = false;
  late UserStatus _selectedStatus;
  late UserRole _selectedRole;
  late String _selectedGenre;
  late DateTime _selectedBirthDate;
  late DateTime _selectedRegistrationDate;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.member.nom);
    _prenomController = TextEditingController(text: widget.member.prenom);
    _phoneController = TextEditingController(text: widget.member.telephone);
    _adresseController = TextEditingController(text: widget.member.adresse);
    _photoUrl = widget.member.photoUrl;
    _selectedStatus = widget.member.status;
    _selectedRole = widget.member.role;
    _selectedGenre = widget.member.genre;
    _selectedBirthDate = widget.member.dateNaissance;
    _selectedRegistrationDate = widget.member.dateInscription;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _phoneController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isUploadingPhoto) return;
    
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (pickedFile == null) return;
    if (!mounted) return;

    // Recadrage
    CroppedFile? croppedFile;
    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer',
            toolbarColor: const Color(0xFF002366),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(title: 'Recadrer'),
          WebUiSettings(context: context, presentStyle: WebPresentStyle.page),
        ],
      );
    } catch (e) {
      debugPrint("Erreur recadrage: $e");
    }

    final finalFile = croppedFile != null ? XFile(croppedFile.path) : pickedFile;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await StorageService().uploadProfileImage(finalFile, widget.member.id);
      if (url != null) {
        setState(() {
          _photoUrl = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nouvelle photo prête à être enregistrée.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.all(isLargeScreen ? 32 : 20),
      children: [
        if (!isLargeScreen) ...[
          Row(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: _isUploadingPhoto 
                        ? const SizedBox(width: 60, height: 60, child: Center(child: CircularProgressIndicator()))
                        : MemberAvatar(member: widget.member.copyWith(photoUrl: _photoUrl), radius: 30),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 12, color: AppTheme.darkBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Détails du Membre', style: Theme.of(context).textTheme.headlineSmall),
              ),
            ],
          ),
          const Divider(),
        ] else ...[
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: _isUploadingPhoto 
                      ? const SizedBox(width: 100, height: 100, child: Center(child: CircularProgressIndicator()))
                      : MemberAvatar(member: widget.member.copyWith(photoUrl: _photoUrl), radius: 50),
                ),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 16, color: AppTheme.darkBlue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.member.pendingModifications != null) _buildValidationCard(isLargeScreen),
        const SizedBox(height: 20),
        _buildEditForm(isDark, isLargeScreen),
      ],
    );
  }

  Widget _buildValidationCard(bool isLargeScreen) {
    final mods = widget.member.pendingModifications!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      color: isDark ? AppTheme.gold : Colors.orange.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppTheme.gold : Colors.orange, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: isDark ? AppTheme.darkBlue : Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Validations requises', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isDark ? AppTheme.darkBlue : null,
                  )
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Le membre a mis à jour ses informations :', 
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkBlue.withValues(alpha: 0.8) : null,
              )
            ),
            const SizedBox(height: 16),
            if (mods.containsKey('photoUrl')) ...[
              const Text('Nouvelle photo de profil :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Lien détecté: ${mods['photoUrl'].toString().substring(0, mods['photoUrl'].toString().length > 30 ? 30 : mods['photoUrl'].toString().length)}...', 
                style: const TextStyle(fontSize: 10, color: Colors.blue)
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppTheme.darkBlue.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    mods['photoUrl'].toString(),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                          const SizedBox(height: 8),
                          const Text('Problème d\'affichage (CORS ou réseau)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(error.toString(), style: const TextStyle(fontSize: 8, color: Colors.red), textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: mods.entries.where((e) => e.key != 'photoUrl').map((entry) {
                String label = entry.key;
                // Traduction des labels techniques pour le Secrétaire
                switch(entry.key) {
                  case 'nom': label = 'Nom'; break;
                  case 'prenom': label = 'Prénom'; break;
                  case 'telephone': label = 'Téléphone'; break;
                  case 'adresse': label = 'Adresse'; break;
                  case 'genre': label = 'Genre'; break;
                  case 'dateNaissance': label = 'Date de Naissance'; break;
                }

                String displayValue = entry.value.toString();
                if (entry.value is Timestamp) {
                  displayValue = DateFormat('dd/MM/yyyy').format((entry.value as Timestamp).toDate());
                } else if (entry.key == 'genre') {
                  displayValue = entry.value == 'M' ? 'Masculin' : 'Féminin';
                }

                return SizedBox(
                  width: isLargeScreen ? 240 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label, 
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isDark ? AppTheme.darkBlue.withValues(alpha: 0.7) : Colors.grey[600],
                        )
                      ),
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.darkBlue : Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        )
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _handleValidation(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.red[900] : Colors.red,
                    side: isDark ? BorderSide(color: Colors.red[900]!) : null,
                  ),
                  child: const Text('Rejeter'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _handleValidation(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkBlue : Colors.orange, 
                    foregroundColor: isDark ? AppTheme.gold : Colors.white,
                  ),
                  child: const Text('Approuver'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _handleValidation(bool approve) async {
    // Demander confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Confirmer l\'approbation' : 'Confirmer le rejet'),
        content: Text(approve 
          ? 'Voulez-vous valider et appliquer ces modifications au profil du membre ?' 
          : 'Voulez-vous rejeter ces modifications ? Elles seront définitivement supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(approve ? 'APPROUVER' : 'REJETER'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Capturer les données nécessaires avant toute opération asynchrone
    final String memberId = widget.member.id;
    final Map<String, dynamic>? pendingMods = widget.member.pendingModifications;
    
    // Si on approuve mais qu'il n'y a plus de modifs, on arrête
    if (approve && (pendingMods == null || pendingMods.isEmpty)) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Références locales pour éviter les problèmes de contexte après await
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (approve) {
        // 1. Préparer les données à appliquer
        final Map<String, dynamic> dataToApply = Map<String, dynamic>.from(pendingMods!);
        
        // Nettoyage de sécurité pour Firestore Web
        dataToApply.removeWhere((key, value) => value == null);
        
        // S'assurer qu'on ne réinjecte pas accidentellement le champ pendingModifications lui-même
        dataToApply.remove('pendingModifications');
        
        // 2. Créer l'objet de mise à jour final qui inclut la suppression de la demande
        final Map<String, dynamic> finalUpdate = {
          ...dataToApply,
          'pendingModifications': FieldValue.delete(),
        };

        debugPrint("Validation: Envoi des données -> $finalUpdate");
        await widget.dbService.updateMember(memberId, finalUpdate);
      } else {
        // Rejet : On supprime juste les modifications en attente
        await widget.dbService.updateMember(memberId, {
          'pendingModifications': FieldValue.delete()
        });
      }
      
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(approve ? 'Modifications appliquées avec succès' : 'Modifications rejetées'),
            backgroundColor: approve ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (e is FirebaseException) {
        errorMessage = "Erreur Firebase [${e.code}]: ${e.message}";
      }
      
      debugPrint("ERREUR VALIDATION: $errorMessage");
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Échec: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'DÉTAILS',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Détail de l\'erreur'),
                    content: SingleChildScrollView(child: Text(errorMessage)),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildEditForm(bool isDark, bool isLargeScreen) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).userProfile;
    final isPresident = currentUser?.role == UserRole.president;
    final isSecretary = currentUser?.role == UserRole.secretaire;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations Personnelles', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? AppTheme.gold : AppTheme.darkBlue,
          )
        ),
        const SizedBox(height: 16),
        if (isLargeScreen) ...[
          Row(
            children: [
              Expanded(child: _buildField(_nomController, 'Nom', isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(_prenomController, 'Prénom', isDark)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildField(_phoneController, 'Téléphone', isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildField(_adresseController, 'Adresse', isDark)),
            ],
          ),
        ] else ...[
          _buildField(_nomController, 'Nom', isDark),
          _buildField(_prenomController, 'Prénom', isDark),
          _buildField(_phoneController, 'Téléphone', isDark),
          _buildField(_adresseController, 'Adresse', isDark),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedGenre,
            dropdownColor: isDark ? AppTheme.deepNavy : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.darkBlue),
            decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'M', child: Text('Masculin')),
              DropdownMenuItem(value: 'F', child: Text('Féminin')),
            ],
            onChanged: (val) => setState(() => _selectedGenre = val!),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Date de naissance'),
            subtitle: Text('${_selectedBirthDate.day}/${_selectedBirthDate.month}/${_selectedBirthDate.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedBirthDate,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedBirthDate = picked);
            },
          ),
          ListTile(
            title: const Text('Date d\'inscription'),
            subtitle: Text('${_selectedRegistrationDate.day}/${_selectedRegistrationDate.month}/${_selectedRegistrationDate.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedRegistrationDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedRegistrationDate = picked);
            },
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Administration', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? AppTheme.gold : AppTheme.darkBlue,
          )
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UserStatus>(
          initialValue: _selectedStatus,
          dropdownColor: isDark ? AppTheme.deepNavy : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.darkBlue),
          decoration: InputDecoration(
            labelText: 'Statut du compte',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.darkBlue),
            helperText: widget.member.status == UserStatus.actif && !(isPresident || isSecretary)
              ? 'Seul le Président ou le Secrétaire peut modifier un membre actif' 
              : null,
            helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
            border: const OutlineInputBorder(),
          ),
          // Le Secrétaire peut désormais modifier le statut même si le membre est actif
          onChanged: (widget.member.status == UserStatus.actif && !(isPresident || isSecretary))
            ? null 
            : (val) => setState(() => _selectedStatus = val!),
          items: UserStatus.values.map((status) => DropdownMenuItem(
            value: status,
            child: Text(status.name),
          )).toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UserRole>(
          initialValue: _selectedRole,
          dropdownColor: isDark ? AppTheme.deepNavy : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.darkBlue),
          decoration: InputDecoration(
            labelText: 'Rôle',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.darkBlue),
            helperText: !isPresident ? 'Seul le Président peut modifier le rôle' : null,
            helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
            border: const OutlineInputBorder(),
          ),
          onChanged: !isPresident ? null : (val) => setState(() => _selectedRole = val!),
          items: UserRole.values.map((role) => DropdownMenuItem(
            value: role,
            child: Text(role.name),
          )).toList(),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUploadingPhoto ? null : () async {
              final oldStatus = widget.member.status;
              final newStatus = _selectedStatus;

              // Demander confirmation si le statut change vers Actif ou si c'est une modification de rôle
              if (oldStatus != newStatus || _selectedRole != widget.member.role) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmer les modifications'),
                    content: const Text('Voulez-vous enregistrer ces changements administratifs ? Certaines actions comme l\'activation sont sensibles.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('ANNULER'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('CONFIRMER'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }

              final Map<String, dynamic> updateData = {
                'nom': _nomController.text,
                'prenom': _prenomController.text,
                'telephone': _phoneController.text,
                'adresse': _adresseController.text,
                'photoUrl': _photoUrl,
                'genre': _selectedGenre,
                'dateNaissance': Timestamp.fromDate(_selectedBirthDate),
                'dateInscription': Timestamp.fromDate(_selectedRegistrationDate),
                'status': _selectedStatus.name,
                'role': _selectedRole.name,
              };

              // Si on active le compte manuellement
              if (oldStatus != UserStatus.actif && newStatus == UserStatus.actif) {
                updateData['dateActivation'] = FieldValue.serverTimestamp();
              }

              await widget.dbService.updateMember(widget.member.id, updateData);
              if (!mounted) return;

              // AA to Member if status changed by President
              if (oldStatus != newStatus) {
                final currentUser = Provider.of<UserProvider>(context, listen: false).userProfile;
                if (currentUser?.role == UserRole.president) {
                  await widget.dbService.sendAutomaticAlert(
                    title: 'Statut de membre mis à jour',
                    details: 'Votre statut a été modifié en "${newStatus.name}" par le Président.',
                    initiatorId: currentUser?.id ?? 'system',
                    targetType: AlertTarget.manual,
                    targetUserIds: [widget.member.id],
                  );
                }
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer les modifications'),
          ),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : AppTheme.darkBlue),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.darkBlue),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
