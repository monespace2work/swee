import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/alert_model.dart';
import '../../../models/member_model.dart';
import '../../../services/database_service.dart';
import '../../../providers/user_provider.dart';
import 'package:intl/intl.dart';

class EditAlertScreen extends StatefulWidget {
  final AlertModel? alert;
  const EditAlertScreen({super.key, this.alert});

  @override
  State<EditAlertScreen> createState() => _EditAlertScreenState();
}

class _EditAlertScreenState extends State<EditAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _detailsController;
  late DateTime _startDate;
  late AlertTarget _targetType;
  List<String> _targetUserIds = [];
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.alert?.title ?? '');
    _detailsController = TextEditingController(text: widget.alert?.details ?? '');
    _startDate = widget.alert?.startDate ?? DateTime.now();
    _targetType = widget.alert?.targetType ?? AlertTarget.all;
    _targetUserIds = List.from(widget.alert?.targetUserIds ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProvider>(context).userProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alert == null ? 'Nouvelle Alerte' : 'Modifier l\'Alerte'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titre de l\'alerte'),
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(labelText: 'Détails / Message'),
                maxLines: 4,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date de début de lancement'),
                subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDate,
              ),
              const SizedBox(height: 16),
              const Text('Destinataires', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<AlertTarget>(
                value: _targetType,
                items: AlertTarget.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(_getTargetText(t)),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _targetType = val!;
                  });
                },
              ),
              if (_targetType == AlertTarget.manual) ...[
                const SizedBox(height: 16),
                const Text('Sélectionner les membres:', style: TextStyle(fontSize: 14)),
                _buildMemberSelection(),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _save(userProfile?.id),
                  child: Text(widget.alert == null ? 'Lancer l\'alerte' : 'Mettre à jour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSelection() {
    return StreamBuilder<List<MemberModel>>(
      stream: _dbService.getMembers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final members = snapshot.data!.where((m) => m.status == UserStatus.actif).toList();
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isSelected = _targetUserIds.contains(member.id);
            return CheckboxListTile(
              title: Text('${member.prenom} ${member.nom}'),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _targetUserIds.add(member.id);
                  } else {
                    _targetUserIds.remove(member.id);
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  String _getTargetText(AlertTarget target) {
    switch (target) {
      case AlertTarget.all: return 'Tout le monde';
      case AlertTarget.bureau: return 'Le Bureau uniquement';
      case AlertTarget.ordinary: return 'Membres ordinaires';
      case AlertTarget.manual: return 'Sélection manuelle';
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate),
      );
      if (time != null) {
        setState(() {
          _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  void _save(String? adminId) async {
    if (adminId == null) return;
    if (_formKey.currentState!.validate()) {
      if (_targetType == AlertTarget.manual && _targetUserIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner au moins un membre.')),
        );
        return;
      }

      final alertData = AlertModel(
        id: widget.alert?.id ?? '',
        title: _titleController.text,
        details: _detailsController.text,
        initiatorId: adminId,
        createdAt: widget.alert?.createdAt ?? DateTime.now(),
        startDate: _startDate,
        isActive: widget.alert?.isActive ?? true,
        targetType: _targetType,
        targetUserIds: _targetUserIds,
        viewedBy: widget.alert?.viewedBy ?? {},
      );

      if (widget.alert == null) {
        await _dbService.addAlert(alertData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre alerte a été envoyée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _dbService.updateAlert(widget.alert!.id, alertData.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alerte mise à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    }
  }
}
