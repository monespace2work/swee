import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

class AppTutorial extends StatefulWidget {
  final String userId;
  final bool isManualLaunch;
  const AppTutorial({super.key, required this.userId, this.isManualLaunch = false});

  static void show(BuildContext context, String userId, {bool isManualLaunch = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppTutorial(userId: userId, isManualLaunch: isManualLaunch),
    );
  }

  @override
  State<AppTutorial> createState() => _AppTutorialState();
}

class _AppTutorialState extends State<AppTutorial> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "Bienvenue sur Swee !",
      description: "Votre plateforme moderne pour gérer la vie de votre association en toute simplicité.",
      icon: Icons.celebration,
      color: AppTheme.gold,
    ),
    TutorialStep(
      title: "Fil d'Actualité",
      description: "Restez informé des dernières nouvelles, événements et annonces importantes de l'association.",
      icon: Icons.home,
      color: AppTheme.darkBlue,
    ),
    TutorialStep(
      title: "Boîte à Idées",
      description: "Partagez vos suggestions et votez pour les meilleures idées pour faire grandir la communauté.",
      icon: Icons.lightbulb,
      color: Colors.orange,
    ),
    TutorialStep(
      title: "Suivi Financier",
      description: "Consultez l'historique de vos cotisations et versements en temps réel dans l'onglet Mon Compte.",
      icon: Icons.account_balance_wallet,
      color: Colors.green,
    ),
    TutorialStep(
      title: "Notifications & Alertes",
      description: "Recevez des rappels personnalisés et des alertes administratives directement sur votre mobile.",
      icon: Icons.notifications_active,
      color: Colors.redAccent,
    ),
    TutorialStep(
      title: "C'est parti !",
      description: "Vous êtes maintenant prêt à explorer Swee. Profitez de votre expérience !",
      icon: Icons.rocket_launch,
      color: AppTheme.gold,
    ),
  ];

  void _finish() async {
    if (!widget.isManualLaunch) {
      await DatabaseService().markTutorialAsSeen(widget.userId);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    "Passer",
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: step.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(step.icon, size: 80, color: step.color),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        step.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dots indicator
                Row(
                  children: List.generate(
                    _steps.length,
                    (index) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? AppTheme.gold
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                // Next/Finish button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _steps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_currentPage < _steps.length - 1 ? "Suivant" : "Commencer"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
