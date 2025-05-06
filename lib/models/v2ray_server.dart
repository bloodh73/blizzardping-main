import 'dart:convert';

class V22RayServer {
  final String remark;
  final String address;
  final int port;
  final String config;
  final String? network; // اضافه کردن فیلد network برای پشتیبانی از httpupgrade

  V22RayServer({
    required this.remark,
    required this.address,
    required this.port,
    required this.config,
    this.network,
  });

  factory V22RayServer.fromJson(Map<String, dynamic> json) {
    return V22RayServer(
      remark: json['remark'] as String? ?? 'Unknown',
      address: json['address'] as String? ?? '',
      port: json['port'] != null ? int.parse(json['port'].toString()) : 0,
      config: json['config'] as String? ?? '',
      network: json['network'] as String?,
    );
  }

  factory V22RayServer.fromV2RayURL(String url) {
    if (url.startsWith('vmess://')) {
      return _fromVMessURL(url);
    } else if (url.startsWith('vless://')) {
      return _fromVLESSURL(url);
    } else if (url.startsWith('ss://')) {
      return _fromShadowsocksURL(url);
    } else {
      throw Exception(
        'Unsupported protocol: URL must start with vmess://, vless://, or ss://',
      );
    }
  }

  // Parse VMess URL
  static V22RayServer _fromVMessURL(String url) {
    // Remove the "vmess://" prefix
    final cleanUrl = url.replaceFirst('vmess://', '');

    try {
      // Decode base64
      final decoded = utf8.decode(base64.decode(cleanUrl.trim()));

      // Parse JSON
      final Map<String, dynamic> data = json.decode(decoded);

      // Extract network type, default to "tcp" if not specified
      String network = data['net'] ?? 'tcp';

      // Check if httpupgrade is specified in the parameters
      if (data['type'] == 'httpupgrade' ||
          (data['net'] == 'http' && data['type'] == 'httpupgrade') ||
          (data['headers'] != null &&
              data['headers']['Upgrade'] == 'websocket')) {
        network = 'httpupgrade';
      }

      return V22RayServer(
        remark: data['ps'] ?? 'Unknown VMess Server',
        address: data['add'] ?? '',
        port: int.parse(data['port']?.toString() ?? '0'),
        config: url, // Store the original URL as config
        network: network,
      );
    } catch (e) {
      throw Exception('Failed to parse VMess URL: $e');
    }
  }

  // Parse VLESS URL
  static V22RayServer _fromVLESSURL(String url) {
    try {
      // VLESS URLs are in the format: vless://uuid@host:port?params#remark
      final uri = Uri.parse(url);

      // Extract parameters
      final params = uri.queryParameters;

      // Extract network type, default to "tcp" if not specified
      String network = params['type'] ?? 'tcp';

      // Check if httpupgrade is specified in the parameters
      if (params['type'] == 'httpupgrade' ||
          (params['type'] == 'http' && params['headerType'] == 'httpupgrade') ||
          params['security'] == 'httpupgrade') {
        network = 'httpupgrade';
      }

      // Extract remark from fragment
      final remark = Uri.decodeComponent(
        uri.fragment.isNotEmpty ? uri.fragment : 'Unknown VLESS Server',
      );

      return V22RayServer(
        remark: remark,
        address: uri.host,
        port:
            uri.port > 0
                ? uri.port
                : 443, // Default to 443 if port is not specified
        config: url, // Store the original URL as config
        network: network,
      );
    } catch (e) {
      throw Exception('Failed to parse VLESS URL: $e');
    }
  }

  // Parse Shadowsocks URL
  static V22RayServer _fromShadowsocksURL(String url) {
    try {
      String ssUrl = url.substring(5); // Remove "ss://"
      String remark = 'Unknown Shadowsocks Server';

      // Extract remark if present
      if (ssUrl.contains('#')) {
        final parts = ssUrl.split('#');
        ssUrl = parts[0];
        remark = Uri.decodeComponent(parts[1]);
      }

      // Handle the two different formats
      String host;
      int port;
      String? plugin;

      if (ssUrl.contains('@')) {
        // Format 2: ss://base64(method:password)@host:port
        final parts = ssUrl.split('@');
        final hostPort = parts[1].split(':');
        host = hostPort[0];

        // Check if there's a plugin parameter
        if (hostPort[1].contains('?')) {
          final portAndParams = hostPort[1].split('?');
          port = int.parse(portAndParams[0]);

          // Parse plugin parameters
          final params = Uri.splitQueryString(portAndParams[1]);
          plugin = params['plugin'];
        } else {
          port = int.parse(hostPort[1]);
        }
      } else {
        // Format 1: ss://base64(method:password@host:port)
        final decoded = utf8.decode(base64.decode(ssUrl));
        final atIndex = decoded.lastIndexOf('@');
        final hostPortStr = decoded.substring(atIndex + 1);

        // Check if there's a plugin parameter
        if (hostPortStr.contains('?')) {
          final parts = hostPortStr.split('?');
          final hostPort = parts[0].split(':');
          host = hostPort[0];
          port = int.parse(hostPort[1]);

          // Parse plugin parameters
          final params = Uri.splitQueryString(parts[1]);
          plugin = params['plugin'];
        } else {
          final hostPort = hostPortStr.split(':');
          host = hostPort[0];
          port = int.parse(hostPort[1]);
        }
      }

      // Determine network type based on plugin
      String? network;
      if (plugin != null && plugin.contains('obfs-local')) {
        if (plugin.contains('obfs=http')) {
          network = 'http';
        } else if (plugin.contains('obfs=tls')) {
          network = 'tls';
        }
      }

      return V22RayServer(
        remark: remark,
        address: host,
        port: port,
        config: url, // Store the original URL as config
        network: network,
      );
    } catch (e) {
      throw Exception('Failed to parse Shadowsocks URL: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'remark': remark,
      'address': address,
      'port': port,
      'config': config,
      'network': network,
    };
  }

  // Helper method to get protocol type
  String getProtocolType() {
    if (config.startsWith('vmess://')) {
      return 'VMess';
    } else if (config.startsWith('vless://')) {
      return 'VLESS';
    } else if (config.startsWith('ss://')) {
      return 'Shadowsocks';
    } else {
      return 'Unknown';
    }
  }

  // Helper method to check if server uses httpupgrade
  bool usesHttpUpgrade() {
    return network == 'httpupgrade';
  }

  // Helper method to get full configuration for V2Ray with httpupgrade support
  Future<String> getFullConfiguration({bool enableHttpUpgrade = false}) async {
    if (enableHttpUpgrade &&
        (network == 'tcp' ||
            network == 'http' ||
            network == 'ws' ||
            network == null)) {
      try {
        // For VMess and VLESS protocols
        if (config.startsWith('vmess://') || config.startsWith('vless://')) {
          String protocol;
          String id;
          String address;
          int port;
          String? encryption;
          String path = "/"; // Default path
          List<String> hosts = []; // Default hosts

          if (config.startsWith('vmess://')) {
            protocol = 'vmess';
            final cleanUrl = config.replaceFirst('vmess://', '');
            final decoded = utf8.decode(base64.decode(cleanUrl.trim()));
            final data = json.decode(decoded);

            id = data['id'] ?? '';
            address = data['add'] ?? '';
            port = int.parse(data['port']?.toString() ?? '0');
            encryption = 'auto';
            path = data['path'] ?? '/';
            hosts = data['host'] != null ? [data['host']] : [address];

            // اضافه کردن لاگ برای دیباگ
            print(
              'VMess config: id=$id, address=$address, port=$port, path=$path, hosts=$hosts',
            );
          } else {
            // VLESS - اصلاح شده
            protocol = 'vless';
            final uri = Uri.parse(config);
            final params = uri.queryParameters;

            id = uri.userInfo;
            address = uri.host;
            port = uri.port > 0 ? uri.port : 443;
            encryption = params['encryption'] ?? 'none';
            path = params['path'] ?? '/';

            // اصلاح شده: استخراج host از پارامترها
            if (params['host'] != null && params['host']!.isNotEmpty) {
              hosts = params['host']!.split(',');
            } else {
              hosts = [address];
            }

            // اضافه کردن لاگ برای دیباگ
            print(
              'VLESS config: id=$id, address=$address, port=$port, path=$path, hosts=$hosts, encryption=$encryption',
            );
          }

          // اضافه کردن آمار برای پشتیبانی از آپلود و دانلود
          final httpUpgradeConfig = {
            "log": {"loglevel": "warning"},
            "stats": {}, // اضافه کردن بخش stats
            "policy": {
              "levels": {
                "0": {"statsUserUplink": true, "statsUserDownlink": true},
              },
              "system": {
                "statsInboundUplink": true,
                "statsInboundDownlink": true,
                "statsOutboundUplink": true,
                "statsOutboundDownlink": true,
              },
            },
            "api": {
              "tag": "api",
              "services": ["StatsService"],
            },
            "inbounds": [
              {
                "tag": "socks-in",
                "port": 1080,
                "protocol": "socks",
                "listen": "127.0.0.1",
                "settings": {"auth": "noauth", "udp": true, "userLevel": 8},
                "sniffing": {
                  "enabled": true,
                  "destOverride": ["http", "tls", "quic"],
                },
              },
              {
                "tag": "api",
                "port": 8888,
                "protocol": "dokodemo-door",
                "listen": "127.0.0.1",
                "settings": {"address": "127.0.0.1"},
              },
            ],
            "outbounds": [
              {
                "tag": "proxy",
                "protocol": protocol,
                "settings": {
                  "vnext": [
                    {
                      "address": address,
                      "port": port,
                      "users": [
                        {
                          "id": id,
                          "security": protocol == 'vmess' ? encryption : null,
                          "level": 8,
                          "encryption": protocol == 'vless' ? encryption : null,
                          "flow": "",
                        },
                      ],
                    },
                  ],
                },
                "streamSettings": {
                  "network": "httpupgrade",
                  "security": "none",
                  "httpupgradeSettings": {"path": path, "host": hosts},
                },
                "mux": {"enabled": false, "concurrency": 8},
              },
              {
                "tag": "direct",
                "protocol": "freedom",
                "settings": {"domainStrategy": "UseIp"},
              },
              {"tag": "blackhole", "protocol": "blackhole"},
            ],
            "dns": {
              "servers": ["8.8.8.8", "8.8.4.4"],
            },
            "routing": {
              "domainStrategy": "AsIs",
              "rules": [
                {
                  "type": "field",
                  "inboundTag": ["api"],
                  "outboundTag": "api",
                },
                {
                  "type": "field",
                  "ip": ["geoip:private"],
                  "outboundTag": "direct",
                },
                {"port": "443", "network": "udp", "outboundTag": "blackhole"},
              ],
            },
          };

          return json.encode(httpUpgradeConfig);
        }

        // Return original config if not VMess or VLESS
        return config;
      } catch (e) {
        print('Error converting config to httpupgrade: $e');
        return config;
      }
    }

    // Return original config if no conversion needed or possible
    return config;
  }
}
