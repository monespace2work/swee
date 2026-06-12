import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  MemberModel? _userProfile;
  bool _isLoading = true; // Initialisé à true pour attendre la vérification initiale
  final AuthService _authService = AuthService();

  MemberModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  UserProvider() {
    _authService.user.listen((user) async {
      _isLoading = true;
      notifyListeners();
      
      try {
        if (user != null) {
          _userProfile = await _authService.getMemberProfile(user.uid);
          debugPrint("UserProvider: Profil chargé pour ${user.uid} -> ${_userProfile?.role}");
        } else {
          _userProfile = null;
          debugPrint("UserProvider: Aucun utilisateur connecté");
        }
      } catch (e) {
        debugPrint("Erreur UserProvider: $e");
        _userProfile = null;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("Erreur Stream Auth: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> refreshProfile() async {
    if (_userProfile != null) {
      _userProfile = await _authService.getMemberProfile(_userProfile!.id);
      notifyListeners();
    }
  }
}
