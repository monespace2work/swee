import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/member_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/alert_model.dart';
import '../../../services/database_service.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  MemberModel? _selectedMember;
  PaymentType _selectedType = PaymentType.mensuelle;
  DateTime _selectedDate = DateTime.now();
  final _amountController = TextEditingController();
  final _modeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  @override
  void dispose() {
    _amountController.dispose();
    _modeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer un Paiement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            StreamBuilder<List<MemberModel>>(
              stream: _dbService.getMembers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final members = snapshot.data!.where((m) => m.status == UserStatus.actif).toList();
                
                return DropdownButtonFormField<MemberModel>(
                  hint: const Text('Sélectionner un membre'),
                  // S'assurer que la valeur sélectionnée est toujours présente dans la liste filtrée
                  value: (members.contains(_selectedMember)) ? _selectedMember : null,
                  onChanged: (m) => setState(() => _selectedMember = m),
                  items: members.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text('${m.prenom} ${m.nom}'),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentType>(
              value: _selectedType,
              onChanged: (t) => setState(() => _selectedType = t!),
              items: PaymentType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.toString().split('.').last.toUpperCase()),
              )).toList(),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _modeController,
              decoration: const InputDecoration(labelText: 'Mode de règlement (Espèces, Orange Money, etc.)'),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date du paiement',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Précisions / Observations',
                hintText: 'Ex: Cotisation du mois de Mars...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _savePayment,
              child: const Text('Enregistrer le paiement'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _savePayment() async {
    if (_selectedMember != null && _amountController.text.isNotEmpty) {
      final payment = PaymentModel(
        id: '',
        memberId: _selectedMember!.id,
        date: _selectedDate,
        type: _selectedType,
        montant: double.parse(_amountController.text),
        modeReglement: _modeController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      );
      await _dbService.addPayment(payment);

      // AA to Member
      await _dbService.sendAutomaticAlert(
        title: 'Paiement enregistré',
        details: 'Type: ${_selectedType.name.toUpperCase()}\nMontant: ${payment.montant} FCFA\nDate: ${DateFormat('dd/MM/yyyy').format(payment.date)}\nMoyen: ${payment.modeReglement}\nObs: ${payment.description ?? "-"}',
        initiatorId: _dbService.currentUser?.uid ?? 'system',
        targetType: AlertTarget.manual,
        targetUserIds: [payment.memberId],
      );

      if (mounted) Navigator.pop(context);
    }
  }
}
