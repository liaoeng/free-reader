import 'package:flutter/services.dart';

class PathLauncherService {
  const PathLauncherService();

  static const _channel = MethodChannel('free_reader/files');

  Future<bool> openDirectory(String path) async {
    final result = await _channel.invokeMethod<bool>(
      'openDirectory',
      {'path': path},
    );
    return result ?? false;
  }
}
