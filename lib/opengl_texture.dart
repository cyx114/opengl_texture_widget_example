import 'dart:async';

import 'package:flutter/services.dart';

class OpenGLTextureController {
  static const MethodChannel _channel = const MethodChannel('opengl_texture');

  late int textureId;

  Future<int> initialize(double width, double height) async {
    textureId = await _channel.invokeMethod('create', {
      'width': width,
      'height': height,
    });
    return textureId;
  }

  Future<Null> dispose() =>
      _channel.invokeMethod('dispose', {'textureId': textureId});


  Future<Null> loadData() {
    return _channel.invokeMethod('loadData', {'textureId': textureId});
  }


  bool get isInitialized => textureId != null;
}
