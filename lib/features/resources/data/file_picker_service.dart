import 'package:flutter/services.dart';

class PickedResourceFile {
  const PickedResourceFile({
    required this.name,
    required this.tempPath,
    required this.size,
    this.mimeType,
  });

  final String name;
  final String tempPath;
  final int size;
  final String? mimeType;

  static PickedResourceFile? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    final name = value['name'];
    final tempPath = value['tempPath'];
    final size = value['size'];
    if (name is! String || tempPath is! String || size is! int) {
      return null;
    }

    return PickedResourceFile(
      name: name,
      tempPath: tempPath,
      size: size,
      mimeType:
          value['mimeType'] is String ? value['mimeType'] as String : null,
    );
  }
}

class FilePickerService {
  const FilePickerService();

  static const _channel = MethodChannel('free_reader/files');

  Future<PickedResourceFile?> pickResourceFile() async {
    final result = await _channel.invokeMethod<Object?>('pickResourceFile');
    return PickedResourceFile.fromMap(result);
  }
}
