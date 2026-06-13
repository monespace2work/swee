import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/member_model.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  
  bool _isLoading = false;
  int _currentStep = 0; // 0: Vérification Email, 1: Création compte
  MemberModel? _preRegisteredMember;

  void _checkEmail() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un email valide.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final email = _emailController.text.trim().toLowerCase();
      final member = await _dbService.getMemberByEmail(email);

      if (member == null) {
        throw "Cet email n'a pas été pré-enregistré par le Secrétaire. Veuillez contacter l'administration.";
      }

      if (member.status != UserStatus.actif) {
        String statusMsg = "";
        switch (member.status) {
          case UserStatus.enAttenteTresorier:
            statusMsg = "votre compte attend la validation du Trésorier.";
            break;
          case UserStatus.enAttentePresident:
            statusMsg = "votre compte attend la validation du Président.";
            break;
          case UserStatus.suspendu:
            statusMsg = "votre compte est suspendu.";
            break;
          case UserStatus.desactive:
            statusMsg = "votre compte est désactivé.";
            break;
          default:
            statusMsg = "votre compte n'est pas encore actif.";
        }
        throw "Votre email est enregistré, mais $statusMsg";
      }

      // Email trouvé et actif !
      setState(() {
        _preRegisteredMember = member;
        _nomController.text = member.nom;
        _prenomController.text = member.prenom;
        _usernameController.text = member.username;
        _currentStep = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final email = _emailController.text.trim();
        final username = _usernameController.text.trim().toLowerCase();
        
        // Vérifier si le nom d'utilisateur existe déjà (et n'est pas celui déjà attribué)
        if (username != _preRegisteredMember?.username) {
          final query = await FirebaseFirestore.instance
              .collection('members')
              .where('username', isEqualTo: username)
              .get(const GetOptions(source: Source.server));

          if (query.docs.isNotEmpty) {
            throw "Ce nom d'utilisateur est déjà pris.";
          }
        }


        // Création dans Firebase Auth avec migration du profil
        await _authService.signUp(
          email: email,
          password: _passwordController.text,
          username: username,
          nom: _nomController.text.trim(),
          prenom: _prenomController.text.trim(),
          existingMember: _preRegisteredMember,
        );

        // Déconnexion immédiate pour revenir à l'état "déconnecté" proprement
        await _authService.signOut();

        if (mounted) {
          setState(() => _isLoading = false);
          _showSuccessDialog();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'), 
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Compte créé !'),
        content: const Text('Votre compte a été activé avec succès. Vous pouvez maintenant vous connecter.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // fermer dialog
              Navigator.pop(context, "success"); // retour login
            },
            child: const Text('D\'accord'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Création de compte')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _currentStep == 0 ? _buildStep0() : _buildStep1(),
      ),
    );
  }

  Widget _buildStep0() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 100),
            const SizedBox(height: 24),
            const Text(
              'Vérification de l\'inscription',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Entrez l\'adresse email avec laquelle le Secrétaire vous a inscrit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Votre Email',
                prefixIcon: Icon(Icons.email),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 24),
            _isLoading 
              ? const CircularProgressIndicator() 
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _checkEmail,
                    child: const Text('Suivant'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Email validé ! Bienvenue ${_prenomController.text}.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _prenomController,
              enabled: false, // On ne change pas le prénom validé
              style: const TextStyle(color: Colors.black54),
              decoration: const InputDecoration(labelText: 'Prénom', fillColor: Colors.white, filled: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomController,
              enabled: false, // On ne change pas le nom validé
              style: const TextStyle(color: Colors.black54),
              decoration: const InputDecoration(labelText: 'Nom', fillColor: Colors.white, filled: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(labelText: 'Nom d\'utilisateur', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(labelText: 'Créez votre mot de passe (6+ car.)', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
              obscureText: true,
              validator: (v) => v!.length < 6 ? 'Trop court' : null,
            ),
            const SizedBox(height: 32),
            _isLoading 
              ? const CircularProgressIndicator() 
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        child: const Text('Retour'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _register,
                        child: const Text('Finaliser l\'inscription'),
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
