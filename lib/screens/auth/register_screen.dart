import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/member_model.dart';

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
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final email = _emailController.text.trim();
        final username = _usernameController.text.trim().toLowerCase();
        
        // Vérifier si le nom d'utilisateur existe déjà
        final query = await FirebaseFirestore.instance
            .collection('members')
            .where('username', isEqualTo: username)
            .get(const GetOptions(source: Source.server)); // Forcer la lecture serveur

        if (query.docs.isNotEmpty) {
          throw "Ce nom d'utilisateur est déjà pris.";
        }

        // 1. Création dans Firebase Auth ET 2. Création du profil dans Firestore
        await _authService.signUp(
          email: email,
          password: _passwordController.text,
          username: username,
          nom: _nomController.text.trim(),
          prenom: _prenomController.text.trim(),
        );

        // Déconnexion immédiate pour revenir à l'état "déconnecté" proprement
        await _authService.signOut();

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context, "success");
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().contains('Timeout') 
                  ? 'Erreur réseau (Timeout). Réessayez.' 
                  : 'Erreur: $e'), 
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _prenomController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: 'Prénom', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
                  validator: (v) => v!.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: 'Nom', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
                  validator: (v) => v!.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email invalide' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: 'Nom d\'utilisateur (Unique)', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
                  validator: (v) => v!.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(labelText: 'Mot de passe (6+ car.)', labelStyle: TextStyle(color: Colors.black54), fillColor: Colors.white, filled: true),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Trop court' : null,
                ),
                const SizedBox(height: 24),
                _isLoading 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Créer le compte'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
