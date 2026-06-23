import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class EditedImageResult {
  final XFile image;
  final double aspectRatio;
  EditedImageResult(this.image, this.aspectRatio);
}

class ImageEditDialog extends StatefulWidget {
  final XFile image;
  final double initialAspectRatio;

  const ImageEditDialog({
    super.key, 
    required this.image,
    this.initialAspectRatio = 16 / 9,
  });

  @override
  State<ImageEditDialog> createState() => _ImageEditDialogState();
}

class _ImageEditDialogState extends State<ImageEditDialog> {
  late XFile _currentImage;
  late double _currentAspectRatio;

  final List<Map<String, dynamic>> _ratios = [
    {'label': '16:9', 'value': 16 / 9, 'preset': CropAspectRatioPreset.ratio16x9},
    {'label': '4:3', 'value': 4 / 3, 'preset': CropAspectRatioPreset.ratio4x3},
    {'label': '1:1', 'value': 1.0, 'preset': CropAspectRatioPreset.square},
    {'label': '3:2', 'value': 3 / 2, 'preset': CropAspectRatioPreset.ratio3x2},
  ];

  @override
  void initState() {
    super.initState();
    _currentImage = widget.image;
    _currentAspectRatio = widget.initialAspectRatio;
  }

  Future<void> _cropImage() async {
    final selectedRatio = _ratios.firstWhere(
      (r) => (r['value'] - _currentAspectRatio).abs() < 0.01,
      orElse: () => _ratios[0],
    );

    final selectedPreset = selectedRatio['preset'] as CropAspectRatioPreset;
    
    double rx = 16;
    double ry = 9;
    if (selectedRatio['label'] == '4:3') { rx = 4; ry = 3; }
    else if (selectedRatio['label'] == '1:1') { rx = 1; ry = 1; }
    else if (selectedRatio['label'] == '3:2') { rx = 3; ry = 2; }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _currentImage.path,
      aspectRatio: CropAspectRatio(ratioX: rx, ratioY: ry),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recadrer',
          toolbarColor: const Color(0xFF002366),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: selectedPreset,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Recadrer'),
        WebUiSettings(context: context),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _currentImage = XFile(croppedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier l\'image'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: AspectRatio(
                    aspectRatio: _currentAspectRatio,
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: _currentImage.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) return Image.memory(snapshot.data!, fit: BoxFit.cover);
                              return const Center(child: CircularProgressIndicator());
                            },
                          )
                        : Image.file(File(_currentImage.path), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Choisir le format :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _ratios.map((r) {
                final isSelected = (r['value'] - _currentAspectRatio).abs() < 0.01;
                return ChoiceChip(
                  label: Text(r['label']),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentAspectRatio = r['value'];
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _cropImage,
              icon: const Icon(Icons.crop),
              label: const Text('Appliquer le recadrage'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, EditedImageResult(_currentImage, _currentAspectRatio)),
          child: const Text('Terminer'),
        ),
      ],
    );
  }
}
