import 'package:flutter/material.dart';

class ZoomableImageViewer extends StatelessWidget {
  final String imageUrl;
  final bool isAsset;

  const ZoomableImageViewer({
    super.key,
    required this.imageUrl,
    this.isAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl,
            child: isAsset
                ? Image.asset(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
