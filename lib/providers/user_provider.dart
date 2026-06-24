import 'dart:async';
import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class UserProvider with ChangeNotifier {
  MemberModel? _userProfile;
  Map<String, dynamic> _allPermissions = {};
  bool _isLoading = true; 
  bool _isRegistering = false;
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription? _profileSubscription;
  StreamSubscription? _permissionsSubscription;

  MemberModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  void setIsRegistering(bool value) {
    _isRegistering = value;
    if (!value) {
      // Re-déclencher une vérification si on sort du mode inscription
      _authService.signOut(); 
    }
  }

  UserProvider() {
    // Écouter les permissions globales
    _permissionsSubscription = _dbService.getAllRolePermissions().listen((perms) {
      _allPermissions = perms;
      notifyListeners();
    });

    _authService.user.listen((user) {
      if (_isRegistering) {
        debugPrint("UserProvider: Ignorer auth change pendant l'inscription");
        return;
      }

      _profileSubscription?.cancel();
      
      if (user != null) {
        _isLoading = true;
        notifyListeners();

        // Synchroniser le token de notification
        NotificationService().syncToken(user.uid);

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
    
    // Le président a tout par défaut
    if (_userProfile!.role == UserRole.president) return true;
    
    final roleName = _userProfile!.role.name;
    
    // Si des permissions sont définies en BDD pour ce rôle, on les utilise (priorité)
    if (_allPermissions.containsKey(roleName)) {
      final rolePerms = _allPermissions[roleName];
      if (rolePerms is Map) {
        final hasPerm = rolePerms[permissionId] == true;
        debugPrint("UserProvider: Permission '$permissionId' pour '$roleName' (BDD) -> $hasPerm");
        return hasPerm;
      }
    }
    
    // Sinon, on applique des permissions par défaut selon le rôle pour éviter le blocage
    final defaultPerm = _getDefaultPermission(_userProfile!.role, permissionId);
    debugPrint("UserProvider: Permission '$permissionId' pour '$roleName' (Défaut) -> $defaultPerm");
    return defaultPerm;
  }

  bool _getDefaultPermission(UserRole role, String permissionId) {
    switch (role) {
      case UserRole.secretaire:
        return [
          'can_manage_members',
          'can_manage_posts',
          'can_moderate_ideas',
          'can_edit_settings',
          'can_manage_alerts'
        ].contains(permissionId);
      case UserRole.tresorier:
        return [
          'can_manage_payments',
          'can_manage_members',
          'can_manage_alerts'
        ].contains(permissionId);
      case UserRole.conseiller:
        return [
          'can_moderate_ideas',
          'can_manage_posts',
          'can_manage_alerts'
        ].contains(permissionId);
      default:
        return false;
    }
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
