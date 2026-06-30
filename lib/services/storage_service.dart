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
      debugPrint("StorageService: Début upload profil pour $userId");
      
      String extension = 'jpg';
      if (file.name.contains('.')) {
        extension = file.name.split('.').last.toLowerCase();
      }
      
      final String fileName = 'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final Reference ref = _storage.ref().child(fileName);
      
      final metadata = SettableMetadata(contentType: 'image/$extension');

      // Lecture sécurisée des bytes
      final Uint8List data = await file.readAsBytes();
      
      debugPrint("StorageService: Tentative d'envoi de ${data.length} bytes...");
      
      // On utilise putData qui est plus universel
      final UploadTask uploadTask = ref.putData(data, metadata);
      
      // On attend la fin complète
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      
      if (snapshot.state == TaskState.success) {
        final String url = await snapshot.ref.getDownloadURL();
        debugPrint("StorageService: Upload réussi, URL générée.");
        return url;
      } else {
        throw Exception("L'état de l'upload est : ${snapshot.state}");
      }
    } catch (e) {
      debugPrint("StorageService ERREUR: $e");
      if (e.toString().contains('object-not-found')) {
        throw Exception("Le stockage Firebase n'est pas encore prêt ou le bucket est mal configuré.");
      }
      rethrow;
    }
  }
}
