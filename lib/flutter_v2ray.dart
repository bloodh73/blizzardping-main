import 'dart:async';
import 'package:flutter/services.dart';

class V22RayStatus {
  final String state;
  final int uploadSpeed;
  final int downloadSpeed;

  V22RayStatus({
    this.state = 'DISCONNECTED',
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
  });

  static starttV2Ray({required String config, required String remark, required bool proxyOnly, required bool enableIPv6, required bool enableMux, required bool enableHttpUpgrade}) {}
}

class FlutterV2ray {
  static const MethodChannel _channel = MethodChannel('flutter_v2ray');
  final StreamController<V22RayStatus> _statusController =
      StreamController<V22RayStatus>.broadcast();

  Stream<V22RayStatus> get v2rayStatusStream => _statusController.stream;

  FlutterV2ray() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'updateStatus':
        final Map<String, dynamic> args = call.arguments;
        final status = V22RayStatus(
          state: args['state'],
          uploadSpeed: args['uploadSpeed'] ?? 0,
          downloadSpeed: args['downloadSpeed'] ?? 0,
        );
        _statusController.add(status);
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod('requestPermission');
    return result ?? false;
  }

  Future<void> starttV2Ray({
    required String config,
    required String remark,
    bool proxyOnly = false,
    bool enableIPv6 = false,
    bool enableMux = false,
    bool enableHttpUpgrade = false,
  }) async {
    final Map<String, dynamic> args = {
      'config': config,
      'remark': remark,
      'proxyOnly': proxyOnly,
      'enableIPv6': enableIPv6,
      'enableMux': enableMux,
      'enableHttpUpgrade': enableHttpUpgrade,
    };

    await _channel.invokeMethod('starttV2Ray', args);
  }

  Future<void> stopV2Ray() async {
    await _channel.invokeMethod('stopV2Ray');
  }

  Future<bool> isRunning() async {
    final result = await _channel.invokeMethod('isRunning');
    return result ?? false;
  }

  Future<void> dispose() async {
    await _statusController.close();
  }

  Future<V22RayStatus?> getV2RayStatus() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'getV2RayStatus',
      );
      if (result != null) {
        return V22RayStatus(
          state: result['state'] as String? ?? 'UNKNOWN',
          uploadSpeed: result['uploadSpeed'] as int? ?? 0,
          downloadSpeed: result['downloadSpeed'] as int? ?? 0,
        );
      }
      return null;
    } catch (e) {
      print('Error getting V2Ray status: $e');
      return null;
    }
  }
}
