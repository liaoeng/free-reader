import 'package:flutter/services.dart';

class TtsSegment {
  const TtsSegment({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;

  Map<String, String> toJson() {
    return {
      'id': id,
      'text': text,
    };
  }
}

class TtsProgress {
  const TtsProgress({required this.segmentId});

  final String segmentId;
}

typedef TtsProgressListener = void Function(TtsProgress progress);

class TtsService {
  TtsService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channel = MethodChannel('free_reader/tts');

  TtsProgressListener? _progressListener;

  void setProgressListener(TtsProgressListener? listener) {
    _progressListener = listener;
  }

  Future<void> speak(String text) {
    return _channel.invokeMethod<void>('speak', {'text': text});
  }

  Future<void> speakSegments(List<TtsSegment> segments) {
    return _channel.invokeMethod<void>(
      'speakSegments',
      {
        'segments': segments.map((segment) => segment.toJson()).toList(),
      },
    );
  }

  Future<void> stop() {
    return _channel.invokeMethod<void>('stop');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onProgress') {
      return;
    }

    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }

    final segmentId = arguments['segmentId'];
    if (segmentId is String && segmentId.isNotEmpty) {
      _progressListener?.call(TtsProgress(segmentId: segmentId));
    }
  }
}
