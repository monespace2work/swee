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
}
