import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class PhotoPickerWidget extends StatefulWidget {
  const PhotoPickerWidget({
    super.key,
    this.localPath,
    this.cloudUrl,
    required this.onChanged,
    this.height = 180,
    this.label = 'Photo',
  });

  final String? localPath;
  final String? cloudUrl;
  final void Function(String? newLocalPath) onChanged;
  final double height;
  final String label;

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  String? _currentLocal;

  @override
  void initState() {
    super.initState();
    _currentLocal = widget.localPath;
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _currentLocal = picked.path);
      widget.onChanged(picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de choisir cette photo')),
      );
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir de la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            if (_currentLocal != null || widget.cloudUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.red),
                title: const Text('Supprimer la photo',
                    style: TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentLocal = null);
                  widget.onChanged(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = _currentLocal != null;
    final hasCloud = widget.cloudUrl != null && widget.cloudUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _showSourceSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: hasLocal
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(File(_currentLocal!),
                        fit: BoxFit.cover, width: double.infinity),
                  )
                : hasCloud
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(widget.cloudUrl!,
                            fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 48, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text('Ajouter une photo',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
          ),
        ),
        if (hasLocal || hasCloud) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _showSourceSheet,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Changer la photo'),
          ),
        ],
      ],
    );
  }
}
