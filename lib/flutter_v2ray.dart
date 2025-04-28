import 'package:flutter/services.dart';

class FlutterV2ray {
  static const MethodChannel _channel = MethodChannel('flutter_v2ray');

  Future<void> startV2Ray({
    required String config,
    required String remark,
    bool proxyOnly = false,
    bool enableIPv6 = false,
    bool enableMux = false,
  }) async {
    final Map<String, dynamic> args = {
      'config': config,
      'remark': remark,
      'proxyOnly': proxyOnly,
      'enableIPv6': enableIPv6,
      'enableMux': enableMux,
    };
    
    await _channel.invokeMethod('startV2Ray', args);
  }

  static parseFromUrl(String url) {}
}

