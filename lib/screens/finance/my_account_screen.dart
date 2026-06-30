import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../models/payment_model.dart';
import '../../theme/app_theme.dart';

class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = DatabaseService();

    if (user == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async {
        await userProvider.refreshProfile();
        // Optionnel : un petit délai pour l'expérience utilisateur
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSummaryHeader(user.id, dbService, isDark),
          const SizedBox(height: 24),
          Text(
            'HISTORIQUE DES VERSEMENTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.gold : AppTheme.darkBlue,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<PaymentModel>>(
            stream: dbService.getMemberPayments(user.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ));
              }

              final payments = snapshot.data ?? [];

              if (payments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: isDark ? Colors.white10 : Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Aucun paiement enregistré pour le moment.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getPaymentTypeColor(payment.type).withValues(alpha: 0.2),
                        child: Icon(Icons.check, color: _getPaymentTypeColor(payment.type)),
                      ),
                      title: Text(
                        payment.type.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(payment.date)),
                          if (payment.description != null)
                            Text(payment.description!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            NumberFormat.currency(locale: 'fr_FR', symbol: 'F', decimalDigits: 0).format(payment.montant),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(payment.modeReglement, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(String userId, DatabaseService dbService, bool isDark) {
    return StreamBuilder<List<PaymentModel>>(
      stream: dbService.getMemberPayments(userId),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];
        final total = payments.fold(0.0, (sum, p) => sum + p.montant);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.7)]
                : [AppTheme.darkBlue, AppTheme.darkBlue.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppTheme.gold : AppTheme.darkBlue).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Situation Financière',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkBlue : Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet,
                    color: isDark ? AppTheme.darkBlue : Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'CUMUL TOTAL VERSÉ',
                style: TextStyle(
                  color: isDark ? AppTheme.darkBlue.withValues(alpha: 0.6) : Colors.white60,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(total),
                style: TextStyle(
                  color: isDark ? AppTheme.darkBlue : Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
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
