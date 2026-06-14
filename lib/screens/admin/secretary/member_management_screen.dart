import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../models/member_model.dart';
import '../../../services/database_service.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/user_menu_button.dart';

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
                      return const Center(child: Text('Aucun membre ne correspond aux critères.'));
                    }
    
                    return ListView.builder(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMemberTile(MemberModel member) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member.genre == 'F' ? Colors.pink[100] : Colors.blue[100],
        child: Text(member.genre, style: TextStyle(color: member.genre == 'F' ? Colors.pink : Colors.blue)),
      ),
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
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: member.genre == 'F' ? Colors.pink[100] : Colors.blue[100],
          child: Text(member.genre, style: TextStyle(fontSize: 18, color: member.genre == 'F' ? Colors.pink : Colors.blue)),
        ),
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
                  color: Colors.orange.withOpacity(0.1),
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
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
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
                value: _statusFilter,
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
                value: _genderFilter,
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
    final photoUrlController = TextEditingController();
    String selectedGenre = 'M';
    DateTime selectedBirthDate = DateTime(1990, 1, 1);
    DateTime registrationDate = DateTime.now();
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter un Membre'),
          content: Container(
            width: isLargeScreen ? 500 : null,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  TextField(controller: photoUrlController, decoration: const InputDecoration(labelText: 'URL Photo Profil')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGenre,
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
              onPressed: () async {
                if (nomController.text.isEmpty || prenomController.text.isEmpty || emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez remplir les champs obligatoires (*)')),
                  );
                  return;
                }

                final newId = FirebaseFirestore.instance.collection('members').doc().id;
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
                  photoUrl: photoUrlController.text.trim(),
                  dateInscription: registrationDate,
                  role: UserRole.membre,
                  status: UserStatus.enAttenteTresorier,
                );
                await _dbService.createMember(newMember);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
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
  late TextEditingController _photoUrlController;
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
    _photoUrlController = TextEditingController(text: widget.member.photoUrl);
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
    _photoUrlController.dispose();
    super.dispose();
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
          Text('Détails du Membre', style: Theme.of(context).textTheme.headlineSmall),
          const Divider(),
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
      color: isDark ? AppTheme.gold : Colors.orange.withOpacity(0.1),
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
                color: isDark ? AppTheme.darkBlue.withOpacity(0.8) : null,
              )
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: mods.entries.map((entry) {
                return SizedBox(
                  width: isLargeScreen ? 240 : double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key} : ', 
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkBlue : null,
                        )
                      ),
                      Expanded(
                        child: Text(
                          '${entry.value}', 
                          style: TextStyle(
                            color: isDark ? AppTheme.darkBlue : Colors.orange,
                            fontWeight: isDark ? FontWeight.bold : null,
                          )
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
    if (approve) {
      final updatedData = Map<String, dynamic>.from(widget.member.pendingModifications!);
      updatedData['pendingModifications'] = FieldValue.delete();
      await widget.dbService.updateMember(widget.member.id, updatedData);
    } else {
      await widget.dbService.updateMember(widget.member.id, {'pendingModifications': FieldValue.delete()});
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _buildEditForm(bool isDark, bool isLargeScreen) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).userProfile;
    final isPresident = currentUser?.role == UserRole.president;

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
          _buildField(_photoUrlController, 'URL Photo Profil', isDark),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedGenre,
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
          value: _selectedStatus,
          dropdownColor: isDark ? AppTheme.deepNavy : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.darkBlue),
          decoration: InputDecoration(
            labelText: 'Statut du compte',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.darkBlue),
            helperText: widget.member.status == UserStatus.actif && !isPresident
              ? 'Seul le Président peut modifier un membre actif' 
              : null,
            helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
            border: const OutlineInputBorder(),
          ),
          // Désactiver le changement si déjà actif et que l'utilisateur n'est pas président
          onChanged: (widget.member.status == UserStatus.actif && !isPresident)
            ? null 
            : (val) => setState(() => _selectedStatus = val!),
          items: UserStatus.values.map((status) => DropdownMenuItem(
            value: status,
            child: Text(status.name),
          )).toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UserRole>(
          value: _selectedRole,
          dropdownColor: isDark ? AppTheme.deepNavy : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.darkBlue),
          decoration: InputDecoration(
            labelText: 'Rôle',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : AppTheme.darkBlue),
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
            onPressed: () async {
              await widget.dbService.updateMember(widget.member.id, {
                'nom': _nomController.text,
                'prenom': _prenomController.text,
                'telephone': _phoneController.text,
                'adresse': _adresseController.text,
                'photoUrl': _photoUrlController.text,
                'genre': _selectedGenre,
                'dateNaissance': Timestamp.fromDate(_selectedBirthDate),
                'dateInscription': Timestamp.fromDate(_selectedRegistrationDate),
                'status': _selectedStatus.name,
                'role': _selectedRole.name,
              });
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
