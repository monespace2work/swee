import 'dart:async';
import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class UserProvider with ChangeNotifier {
  MemberModel? _userProfile;
  Map<String, dynamic> _allPermissions = {};
  bool _isLoading = true; 
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription? _profileSubscription;
  StreamSubscription? _permissionsSubscription;

  MemberModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  UserProvider() {
    // Écouter les permissions globales
    _permissionsSubscription = _dbService.getAllRolePermissions().listen((perms) {
      _allPermissions = perms;
      notifyListeners();
    });

    _authService.user.listen((user) {
      _profileSubscription?.cancel();
      
      if (user != null) {
        _isLoading = true;
        notifyListeners();

        _profileSubscription = _authService.getMemberProfileStream(user.uid).listen(
          (profile) {
            _userProfile = profile;
            _isLoading = false;
            debugPrint("UserProvider: Profil mis à jour -> ${profile?.role}");
            notifyListeners();
          },
          onError: (e) {
            debugPrint("Erreur UserProvider Stream: $e");
            _isLoading = false;
            notifyListeners();
          }
        );
      } else {
        _userProfile = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  bool hasPermission(String permissionId) {
    if (_userProfile == null) return false;
    if (_userProfile!.role == UserRole.president) return true; // Le président a tout
    
    final roleName = _userProfile!.role.name;
    final rolePerms = _allPermissions[roleName] as Map<String, dynamic>?;
    
    return rolePerms?[permissionId] == true;
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _permissionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshProfile() async {
    if (_userProfile != null) {
      final updated = await _authService.getMemberProfile(_userProfile!.id);
      if (updated != null) {
        _userProfile = updated;
        notifyListeners();
      }
    }
  }
}
