import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import '../../../models/member_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/post_model.dart';
import '../../../models/idea_model.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class StrategicInsightsScreen extends StatelessWidget {
  const StrategicInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilotage Stratégique'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Performance Financière', Icons.analytics),
            const SizedBox(height: 16),
            _buildFinancialStats(dbService, isDark),
            
            const SizedBox(height: 32),
            _buildSectionHeader('Dynamique des Membres', Icons.group_work),
            const SizedBox(height: 16),
            _buildMemberStats(dbService, isDark),
            
            const SizedBox(height: 32),
            _buildSectionHeader('Engagement & Innovation', Icons.tips_and_updates),
            const SizedBox(height: 16),
            _buildEngagementStats(dbService, isDark),
            
            const SizedBox(height: 40),
            _buildStrategicAdvice(dbService, isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildFinancialStats(DatabaseService dbService, bool isDark) {
    return StreamBuilder<List<PaymentModel>>(
      stream: dbService.getAllPayments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final payments = snapshot.data!;
        double total = 0;
        double adhesion = 0;
        double monthly = 0;
        double extra = 0;

        for (var p in payments) {
          total += p.montant;
          if (p.type == PaymentType.adhesion) {
            adhesion += p.montant;
          } else if (p.type == PaymentType.mensuelle) {
            monthly += p.montant;
          } else {
            extra += p.montant;
          }
        }

        return Column(
          children: [
            _buildMainStatCard(
              'Trésorerie Totale',
              NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(total),
              [AppTheme.darkBlue, const Color(0xFF003399)],
              Icons.account_balance,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.deepNavy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Répartition par type de Cotisation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  _buildFinancialBreakdownRow('Droits d\'Adhésion', adhesion, total, Colors.green, isDark),
                  const Divider(height: 24),
                  _buildFinancialBreakdownRow('Cotisations Mensuelles', monthly, total, Colors.blue, isDark),
                  const Divider(height: 24),
                  _buildFinancialBreakdownRow('Frais Extraordinaires', extra, total, Colors.orange, isDark),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialBreakdownRow(String label, double amount, double total, Color color, bool isDark) {
    final percentage = total > 0 ? (amount / total) : 0.0;
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'F', decimalDigits: 0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            Text(
              currencyFormat.format(amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(percentage * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberStats(DatabaseService dbService, bool isDark) {
    return StreamBuilder<List<MemberModel>>(
      stream: dbService.getMembers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final members = snapshot.data!;
        final total = members.length;
        final active = members.where((m) => m.status == UserStatus.actif).length;
        final pending = members.where((m) => m.status == UserStatus.enAttenteTresorier || m.status == UserStatus.enAttentePresident).length;
        
        final activeRate = total > 0 ? (active / total) : 0.0;

        return Row(
          children: [
            Expanded(
              child: _buildProgressCard(
                'Taux d\'Activité',
                activeRate,
                '$active / $total membres',
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleInfoCard(
                'En Attente',
                '$pending',
                'Demandes d\'adhésion',
                Colors.amber,
                isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEngagementStats(DatabaseService dbService, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<IdeaModel>>(
            stream: dbService.getAllIdeas(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _buildSimpleInfoCard(
                'Suggestions',
                '$count',
                'Idées partagées',
                Colors.purple,
                isDark,
              );
            }
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<PostModel>>(
            stream: dbService.getPosts(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _buildSimpleInfoCard(
                'Publications',
                '$count',
                'Posts diffusés',
                Colors.teal,
                isDark,
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildStrategicAdvice(DatabaseService dbService, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.gold.withValues(alpha: 0.05) : AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.gold, size: 30),
              const SizedBox(width: 12),
              Text(
                'Conseils du Conseiller Virtuel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.gold : AppTheme.darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAdviceItem('Si le taux d\'activité est inférieur à 70%, envisagez de lancer un événement communautaire.'),
          _buildAdviceItem('Vérifiez régulièrement les adhésions en attente pour ne pas décourager les nouveaux membres.'),
          _buildAdviceItem('Les suggestions non traitées depuis plus d\'une semaine réduisent l\'engagement.'),
        ],
      ),
    );
  }

  Widget _buildAdviceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.gold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildMainStatCard(String title, String value, List<Color> colors, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 100, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String title, double progress, String subtitle, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.deepNavy : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 80,
                  width: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[200],
                    color: progress > 0.8 ? Colors.green : AppTheme.gold,
                  ),
                ),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoCard(String title, String value, String subtitle, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.deepNavy : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.trending_up, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
