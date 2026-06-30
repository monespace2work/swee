import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/member_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/database_service.dart';
import '../../../theme/app_theme.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  String? _selectedMemberId;
  DateTimeRange? _selectedDateRange;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Situation des Paiements'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFilterPanel(isDark),
          Expanded(
            child: StreamBuilder<List<MemberModel>>(
              stream: _dbService.getMembers(),
              builder: (context, memberSnapshot) {
                if (!memberSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final members = {for (var m in memberSnapshot.data!) m.id: m};

                return StreamBuilder<List<PaymentModel>>(
                  stream: _dbService.getAllPayments(),
                  builder: (context, paymentSnapshot) {
                    if (!paymentSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                    List<PaymentModel> payments = paymentSnapshot.data!;

                    // Apply filters
                    if (_selectedMemberId != null) {
                      payments = payments.where((p) => p.memberId == _selectedMemberId).toList();
                    }
                    if (_selectedDateRange != null) {
                      payments = payments.where((p) {
                        final paymentDate = DateTime(p.date.year, p.date.month, p.date.day);
                        return (paymentDate.isAtSameMomentAs(_selectedDateRange!.start) || paymentDate.isAfter(_selectedDateRange!.start)) &&
                               (paymentDate.isAtSameMomentAs(_selectedDateRange!.end) || paymentDate.isBefore(_selectedDateRange!.end));
                      }).toList();
                    }

                    if (payments.isEmpty) {
                      return const Center(child: Text('Aucun paiement trouvé.'));
                    }

                    double total = payments.fold(0, (sum, item) => sum + item.montant);

                    return Column(
                      children: [
                        _buildSummaryCard(total, payments.length, isDark),
                        Expanded(
                          child: ListView.builder(
                            itemCount: payments.length,
                            itemBuilder: (context, index) {
                              final payment = payments[index];
                              final member = members[payment.memberId];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getPaymentTypeColor(payment.type),
                                    child: const Icon(Icons.attach_money, color: Colors.white),
                                  ),
                                  title: Text(member != null ? '${member.prenom} ${member.nom}' : 'Inconnu'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${DateFormat('dd/MM/yyyy').format(payment.date)} - ${payment.type.name.toUpperCase()}'),
                                      Text('Mode: ${payment.modeReglement}'),
                                      if (payment.description != null && payment.description!.isNotEmpty)
                                        Text(
                                          'Note: ${payment.description}',
                                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: Text(
                                    NumberFormat.currency(locale: 'fr_FR', symbol: 'F', decimalDigits: 0).format(payment.montant),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double total, int count, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gold : AppTheme.darkBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Total des paiements',
            style: TextStyle(
              color: isDark ? AppTheme.darkBlue : Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(total),
            style: TextStyle(
              color: isDark ? AppTheme.darkBlue : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$count transactions',
            style: TextStyle(
              color: isDark ? AppTheme.darkBlue.withValues(alpha: 0.7) : Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Column(
        children: [
          StreamBuilder<List<MemberModel>>(
            stream: _dbService.getMembers(),
            builder: (context, snapshot) {
              final members = snapshot.data ?? [];
              return DropdownButtonFormField<String?>(
                initialValue: _selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Filtrer par membre',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous les membres')),
                  ...members.map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.prenom} ${m.nom}'),
                  )),
                ],
                onChanged: (val) => setState(() => _selectedMemberId = val),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(_selectedDateRange == null 
                    ? 'Toutes les dates' 
                    : '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'),
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedMemberId != null || _selectedDateRange != null)
                IconButton(
                  onPressed: () => setState(() {
                    _selectedMemberId = null;
                    _selectedDateRange = null;
                  }),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Réinitialiser',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  Color _getPaymentTypeColor(PaymentType type) {
    switch (type) {
      case PaymentType.adhesion:
        return Colors.blue;
      case PaymentType.mensuelle:
        return Colors.green;
      case PaymentType.extraordinaire:
        return Colors.orange;
    }
  }
}
