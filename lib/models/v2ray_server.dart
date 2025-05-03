import 'dart:convert';

class V2RayServer {
  final String remark;
  final String address;
  final int port;
  final String config;

  V2RayServer({
    required this.remark,
    required this.address,
    required this.port,
    required this.config,
  });

  factory V2RayServer.fromJson(Map<String, dynamic> json) {
    return V2RayServer(
      remark: json['remark'] as String? ?? 'Unknown',
      address: json['address'] as String? ?? '',
      port: json['port'] != null ? int.parse(json['port'].toString()) : 0,
      config: json['config'] as String? ?? '',
    );
  }

  factory V2RayServer.fromV2RayURL(String url) {
    // Remove the "vmess://" prefix
    final cleanUrl = url.replaceFirst('vmess://', '');

    // Decode base64
    final decoded = utf8.decode(base64.decode(cleanUrl));

    // Parse JSON
    final Map<String, dynamic> data = json.decode(decoded);

    return V2RayServer(
      remark: data['ps'] ?? 'Unknown Server',
      address: data['add'] ?? '',
      port: int.parse(data['port']?.toString() ?? '0'),
      config: url, // Store the original URL as config
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remark': remark,
      'address': address,
      'port': port,
      'config': config,
    };
  }
}

