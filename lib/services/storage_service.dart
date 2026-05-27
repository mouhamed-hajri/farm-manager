import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CloudinaryConfig {
  final String cloudName;
  final String uploadPreset;

  const CloudinaryConfig({
    required this.cloudName,
    required this.uploadPreset,
  });
}

class StorageService {
  StorageService(this._config);

  final CloudinaryConfig _config;

  Future<String?> uploadAnimalPhoto({
    required String userId,
    required String animalId,
    required String localPath,
  }) =>
      _upload(
        localPath: localPath,
        publicId: 'farms/$userId/animals/$animalId/photo',
      );

  Future<String?> uploadReceiptPhoto({
    required String userId,
    required String expenseId,
    required String localPath,
  }) =>
      _upload(
        localPath: localPath,
        publicId: 'farms/$userId/receipts/$expenseId/receipt',
      );

  Future<String?> _upload({
    required String localPath,
    required String publicId,
  }) async {
    // Guard: source file must exist before we attempt anything.
    if (!File(localPath).existsSync()) return null;

    File? compressed;
    try {
      compressed = await _compress(localPath);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://api.cloudinary.com/v1_1/${_config.cloudName}/image/upload'),
      );
      request.fields['upload_preset'] = _config.uploadPreset;
      request.fields['public_id'] = publicId;
      request.files
          .add(await http.MultipartFile.fromPath('file', compressed.path));

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      }
      // Non-200 from Cloudinary — log status for debugging.
      assert(() {
        // ignore: avoid_print
        print('[StorageService] upload failed: HTTP ${streamed.statusCode} – $body');
        return true;
      }());
      return null;
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[StorageService] upload error: $e');
        return true;
      }());
      return null;
    } finally {
      // Always delete the temp compressed file to avoid storage leaks.
      try {
        if (compressed != null &&
            compressed.path != localPath &&
            compressed.existsSync()) {
          await compressed.delete();
        }
      } catch (_) {}
    }
  }

  Future<File> _compress(String path) async {
    final dir = await getTemporaryDirectory();
    final target =
        p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      target,
      quality: 75,
      minWidth: 1024,
      minHeight: 1024,
    );
    return result != null ? File(result.path) : File(path);
  }
}
