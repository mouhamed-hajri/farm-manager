import 'package:image_picker/image_picker.dart';

class PhotoService {
  PhotoService(this._picker);

  final ImagePicker _picker;

  Future<String?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2048,
    );
    return file?.path;
  }

  Future<String?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2048,
    );
    return file?.path;
  }
}
