import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadPostImage(XFile image) async {
    try {
      debugPrint("StorageService: Début de l'upload pour ${image.name}");
      String extension = image.name.split('.').last.toLowerCase();
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png' && extension != 'webp') {
        extension = 'jpg';
      }
      
      String fileName = 'posts/${DateTime.now().millisecondsSinceEpoch}.$extension';
      Reference ref = _storage.ref().child(fileName);
      
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/$extension',
        customMetadata: {'picked-name': image.name},
      );

      // Utilisation de putData pour une meilleure compatibilité Android/Web
      // et éviter les problèmes de chemins de fichiers (Scoped Storage)
      Uint8List data = await image.readAsBytes();
      UploadTask uploadTask = ref.putData(data, metadata);

      // Suivi de la progression
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          double progress = 100.0 * (snapshot.bytesTransferred / snapshot.totalBytes);
          debugPrint("StorageService: Progression: ${progress.toStringAsFixed(2)}%");
        },
        onError: (e) => debugPrint("StorageService: Erreur durant le flux d'upload: $e"),
      );

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("StorageService: Upload réussi ! URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("StorageService ERREUR: $e");
      if (e is FirebaseException) {
        debugPrint("Code d'erreur Firebase: ${e.code}");
        debugPrint("Message d'erreur Firebase: ${e.message}");
      }
      return null;
    }
  }

  Future<String?> uploadProfileImage(XFile file, String userId) async {
    try {
      debugPrint("StorageService: Upload profil pour $userId");
      String extension = file.path.split('.').last.toLowerCase();
      if (extension.contains('?')) extension = extension.split('?').first; 
      if (extension.length > 4 || extension.isEmpty) extension = 'jpg';

      String fileName = 'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      debugPrint("StorageService: Chemin final: $fileName");
      
      Reference ref = _storage.ref().child(fileName);
      
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/$extension',
      );

      debugPrint("StorageService: Lecture des bytes...");
      Uint8List data = await file.readAsBytes();
      debugPrint("StorageService: Envoi des données (${data.length} bytes)...");
      
      // Utilisation de putData pour toutes les plateformes (plus fiable sur Web)
      UploadTask uploadTask = ref.putData(data, metadata);
      
      // Monitor progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('StorageService: Progress: ${progress.toStringAsFixed(2)} %');
      }, onError: (e) {
        debugPrint('StorageService: Error in stream: $e');
      });

      TaskSnapshot snapshot = await uploadTask;
      String url = await snapshot.ref.getDownloadURL();
      debugPrint("StorageService: Upload profil réussi: $url");
      return url;
    } catch (e) {
      debugPrint("StorageService Profile Upload ERREUR: $e");
      if (e is FirebaseException) {
        debugPrint("Firebase Error Code: ${e.code}");
        debugPrint("Firebase Error Message: ${e.message}");
      }
      return null;
    }
  }
}
