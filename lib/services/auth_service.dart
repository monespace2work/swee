import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/member_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Transforme un nom d'utilisateur en email technique pour Firebase Auth
  String _emailFromUsername(String username) => "${username.trim().toLowerCase()}@swee.app";

  Stream<User?> get user => _auth.authStateChanges();

  Future<MemberModel?> getMemberProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('members')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (doc.exists && doc.data() != null) {
        return MemberModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint("Erreur getMemberProfile: $e");
    }
    return null;
  }

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String username,
    required String nom,
    required String prenom,
    String genre = 'M',
    MemberModel? existingMember,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final uid = result.user!.uid;
        
        if (existingMember != null) {
          // Migration du profil existant (créé par le secrétaire) vers le UID Auth
          final data = existingMember.toMap();
          data['username'] = username;
          // On garde les autres infos (nom, prenom, role, status) du profil validé
          
          await _db.collection('members').doc(uid).set(data);
          
          // Supprimer l'ancien document temporaire si l'ID est différent
          if (existingMember.id != uid) {
            await _db.collection('members').doc(existingMember.id).delete();
          }
        } else {
          // Fallback au cas où (ne devrait plus arriver avec le nouveau flux)
          final newMember = MemberModel(
            id: uid,
            username: username,
            email: email,
            nom: nom,
            prenom: prenom,
            telephone: "",
            adresse: "",
            dateNaissance: DateTime.now(),
            genre: genre,
            dateInscription: DateTime.now(),
            role: UserRole.membre,
            status: UserStatus.enAttenteTresorier,
          );
          await _db.collection('members').doc(uid).set(newMember.toMap());
        }
      }
      return result;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Re-authentication pour actions sensibles
  Future<bool> reauthenticate(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Erreur reauthenticate: $e");
      return false;
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
