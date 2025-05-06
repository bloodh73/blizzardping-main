import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:blizzardping/edit_server_screen.dart';
import 'package:blizzardping/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blizzardping/class/class.dart';
import 'package:blizzardping/utils/snackbar_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blizzardping/splash_screen.dart';
import 'widgets/free_subscription_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:url_launcher/url_launcher.dart';

class V2RrayServer {
  final String remark;
  final String address;
  final int port;
  final String config;
  final String? network;

  V2RrayServer({
    required this.remark,
    required this.address,
    required this.port,
    required this.config,
    this.network,
  });

  factory V2RrayServer.fromV2RayURL(String url) {
    try {
      final v2rayURL = FlutterV2ray.parseFromURL(url);
      return V2RrayServer(
        remark: v2rayURL.remark,
        address: v2rayURL.address,
        port: v2rayURL.port,
        config: v2rayURL.getFullConfiguration(),
        network: null,
      );
    } catch (e) {
      throw Exception('Failed to parse V2Ray URL: $e');
    }
  }

  // Add the getFullConfiguration method
  String getFullConfiguration({bool enableHttpUpgrade = false}) {
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
          } else {
            // VLESS
            protocol = 'vless';
            final uri = Uri.parse(config);
            final params = uri.queryParameters;

            id = uri.userInfo;
            address = uri.host;
            port = uri.port > 0 ? uri.port : 443;
            encryption = 'none';
            path = params['path'] ?? '/';
          }

          // Create a new httpupgrade config with proper settings based on the example
          final httpUpgradeConfig = {
            "log": {"loglevel": "warning"},
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
                  "httpupgradeSettings": {
                    "path": path,
                    "host": [address],
                  },
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
                  "ip": ["geoip:private"],
                  "outboundTag": "direct",
                },
                {"port": "443", "network": "udp", "outboundTag": "block"},
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

class Subscription {
  final String name;
  final String url;

  Subscription({required this.name, required this.url});

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }
}

class ServerConfig {
  final String remark;
  final String config;
  final DateTime addedTime;

  ServerConfig({
    required this.remark,
    required this.config,
    required this.addedTime,
  });

  Map<String, dynamic> toJson() => {
    'remark': remark,
    'config': config,
    'addedTime': addedTime.toIso8601String(),
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      remark: json['remark'] as String,
      config: json['config'] as String,
      addedTime: DateTime.parse(json['addedTime'] as String),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? true;
  runApp(MyApp(initialDarkMode: isDarkMode));
}

class MyApp extends StatefulWidget {
  final bool initialDarkMode;
  const MyApp({super.key, required this.initialDarkMode});

  // اضافه کردن متد استاتیک of
  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  // اضافه کردن متد updateThemeMode
  void updateThemeMode(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blizzard Ping',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        cardTheme: const CardTheme(elevation: 2),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade50,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          actionsIconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          color: Colors.blue.shade900.withOpacity(0.2),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade900.withOpacity(0.2),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          actionsIconTheme: const IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

class V2RayManager extends StatefulWidget {
  const V2RayManager({super.key});

  @override
  State<V2RayManager> createState() => _V2RayManagerState();
}

class _V2RayManagerState extends State<V2RayManager>
    with SingleTickerProviderStateMixin {
  String _subscriptionUrl = '';
  String _defaultSubscriptionUrl = '';
  // Add this line
  List<Subscription> _subscriptions = [];
  bool _enableHttpUpgrade = false;
  bool _isPingingAll =
      false; // اضافه کردن متغیر جدید برای وضعیت پینگ همه سرورها

  void initializeState() {
    // Renamed to 'initializeState'
    super.initState();
    _loadDefaultSubscription();
    _loadSubscriptions();

    _loadSavedSubscriptionUrl();
    _loadSavedServers();
    _loadSettings(); // اضافه کردن این خط
  }

  Future<void> _loadDefaultSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultSubscriptionUrl =
          prefs.getString('default_subscription_url') ?? '';
    });
  }

  Future<void> _saveDefaultSubscription(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_subscription_url', url);
    setState(() {
      _defaultSubscriptionUrl = url;
    });
  }

  Future<void> _loadSavedSubscriptionUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('subscription_url') ?? '';
    setState(() {
      _subscriptionUrl = url;
      // حذف کد اضافی که ممکن است باعث آپدیت شود
      // if (url.isNotEmpty) {}
    });
  }

  Future<List<V2RrayServer>> _loadAllServers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<V2RrayServer> allServers = [];
    _addLog('Loading servers from all subscriptions...');

    // Load servers from all subscriptions
    for (var subscription in _subscriptions) {
      _addLog('Loading servers from subscription: ${subscription.name}');
      final key = 'servers_for_subscription_${subscription.url.hashCode}';
      final serversJson = prefs.getString(key) ?? '[]';

      try {
        final List<dynamic> serversList = json.decode(serversJson);
        final servers =
            serversList
                .map(
                  (item) => V2RrayServer(
                    remark: item['remark'] as String? ?? 'Unknown',
                    address: item['address'] as String? ?? '',
                    port:
                        item['port'] != null
                            ? int.parse(item['port'].toString())
                            : 0,
                    config: item['config'] as String? ?? '',
                  ),
                )
                .toList();

        _addLog(
          'Found ${servers.length} servers in subscription ${subscription.name}',
        );
        allServers.addAll(servers);
      } catch (e) {
        _addLog(
          'Error loading servers for subscription ${subscription.url}: $e',
        );
      }
    }

    // Also add saved servers
    _addLog('Adding ${_savedServers.length} manually saved servers');
    allServers.addAll(_savedServers);

    // Remove duplicates based on remark
    final uniqueServers = <V2RrayServer>[];
    final seenRemarks = <String>{};

    for (var server in allServers) {
      if (!seenRemarks.contains(server.remark)) {
        uniqueServers.add(server);
        seenRemarks.add(server.remark);
      }
    }

    _addLog('Total unique servers loaded: ${uniqueServers.length}');
    return uniqueServers;
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString('subscriptions') ?? '[]';
    print('Main: Loading subscriptions JSON: $subscriptionsJson'); // برای دیباگ

    try {
      final List<dynamic> subscriptionsList = json.decode(subscriptionsJson);
      setState(() {
        _subscriptions =
            subscriptionsList
                .map((item) => Subscription.fromJson(item))
                .toList();
      });

      print(
        'Main: Loaded ${_subscriptions.length} subscriptions',
      ); // برای دیباگ
      for (var sub in _subscriptions) {
        print('Main: Subscription: ${sub.name} - ${sub.url}'); // برای دیباگ
      }
    } catch (e) {
      print('Main: Error loading subscriptions: $e'); // برای دیباگ
      _showError('Error loading subscriptions');
    }
  }

  List<V2RrayServer> _servers = [];
  bool _isLoading = false;
  final ValueNotifier<V2RayStatus> _v2rayStatus = ValueNotifier(V2RayStatus());
  late FlutterV2ray _flutterV2ray;
  String _currentServer = '';
  bool _proxyOnly = false;
  bool _enableIPv6 = false;
  bool _enableMux = false;

  final Map<String, int> _pingResults = {};
  final Map<String, bool> _isPingLoading = {};
  final List<String> _logs = []; // متغیر جدید برای لاگ‌ها
  List<V2RrayServer> _savedServers = [];
  Timer? _pingTimer;

  final Map<String, int> _lastPingAttempt = {};

  get onSelect => null; // Track last ping attempt time

  void _openSubscriptionManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SubscriptionManager(
              currentSubscriptionUrl: _subscriptionUrl,
              onSubscriptionSelected: (url) async {
                await _saveSubscriptionUrl(url);
                // حذف فراخوانی خودکار _fetchServers
                // await _fetchServers(url);
              },
              onSubscriptionsChanged: (
                List<Subscription> newSubscriptions,
              ) async {
                setState(() {
                  _subscriptions = newSubscriptions;
                });
                await _saveSubscriptions();
              },
            ),
      ),
    );

    if (result == true) {
      await _loadSubscriptions();
      // اگر سابسکریپشن فعلی حذف شده، اولین سابسکریپشن را انتخاب کن
      if (_subscriptions.every((sub) => sub.url != _subscriptionUrl)) {
        if (_subscriptions.isNotEmpty) {
          final firstSub = _subscriptions.first;
          await _saveSubscriptionUrl(firstSub.url);
          // حذف فراخوانی خودکار _fetchServers
          // await _fetchServers(firstSub.url);
        } else {
          setState(() {
            _subscriptionUrl = '';
            _servers.clear();
          });
        }
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message: message, isError: true);
  }

  @override
  void initState() {
    super.initState();
    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (V2RayStatus status) {
        setState(() {
          _v2rayStatus.value = status;
        });
      },
    );
    _initV2Ray();
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPermission();
      _checkAndRequestPermissions(); // اضافه کردن این خط
    });
    // چک کردن آپدیت بعد از مدت کوتاهی
    Future.delayed(const Duration(seconds: 2), () {
      UpdateChecker.checkForUpdate(context);
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      // بررسی دسترسی VPN
      final hasVpnPermission = await _flutterV2ray.requestPermission();
      if (!hasVpnPermission) {
        _addLog('VPN permission denied');
        _showError('VPN permission required for connection');
      } else {
        _addLog('VPN permission granted');
      }

      // بررسی دسترسی نوتیفیکیشن برای اندروید 13 و بالاتر
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+
          final status = await Permission.notification.status;
          if (status.isDenied) {
            _addLog('Requesting notification permission');
            await Permission.notification.request();
          }
        }
      }

      // بررسی بهینه‌سازی باتری
      if (Platform.isAndroid) {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (status.isDenied) {
          _addLog('Battery optimization may affect background operation');

          // نمایش دیالوگ به کاربر
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Battery Optimization'),
                    content: const Text(
                      'For better performance in background, please disable battery optimization for this app.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Permission.ignoreBatteryOptimizations.request();
                        },
                        child: const Text('Disable Optimization'),
                      ),
                    ],
                  ),
            );
          }
        }
      }
    } catch (e) {
      _addLog('Error checking permissions: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      _addLog('شروع بارگذاری اطلاعات ذخیره شده...');

      await Future.wait([
        _loadSavedServers(),
        _loadDefaultSubscription(),
        _loadSubscriptions(),
        _loadSavedSubscriptionUrl(),
        _loadSettings(),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final lastSelectedServer = prefs.getString('last_selected_server');
      if (lastSelectedServer != null && lastSelectedServer.isNotEmpty) {
        setState(() {
          _currentServer = lastSelectedServer;
        });
        _addLog('سرور قبلی بازیابی شد: $lastSelectedServer');
      }

      // حذف آپدیت خودکار سابسکریپشن
      // اگر subscription فعلی خالی است و subscriptionها وجود دارند
      if (_subscriptionUrl.isEmpty && _subscriptions.isNotEmpty) {
        final firstSub = _subscriptions.first;
        await _saveSubscriptionUrl(firstSub.url);
        // حذف فراخوانی خودکار _fetchServers
        // await _fetchServers(firstSub.url);
      }

      _addLog('بارگذاری اطلاعات با موفقیت انجام شد');
    } catch (e) {
      _addLog('خطا در بارگذاری اطلاعات: $e');
      _showError('خطا در بارگذاری اطلاعات اولیه');
    }
  }

  Future<bool> _hasServersForSubscription(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'servers_for_subscription_${url.hashCode}';
    return prefs.containsKey(key);
  }

  Future<void> _requestInitialPermission() async {
    try {
      final hasPermission = await _flutterV2ray.requestPermission();
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لطفا دسترسی VPN را تایید کنید'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در درخواست دسترسی: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initV2Ray() async {
    try {
      await _flutterV2ray.initializeV2Ray(
        notificationIconResourceType: "mipmap",
        notificationIconResourceName: "ic_launcher",
      );
      setState(() {});
    } catch (e) {
      _showError('خطا در راه‌اندازی V2Ray: $e');
    }
  }

  Future<List<V2RrayServer>> _loadServersForSubscription(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'servers_for_subscription_${url.hashCode}';
    final serversJson = prefs.getString(key) ?? '[]';

    try {
      final List<dynamic> serversList = json.decode(serversJson);
      return serversList
          .map(
            (item) => V2RrayServer(
              remark: item['remark'] as String? ?? 'Unknown',
              address: item['address'] as String? ?? '',
              port:
                  item['port'] != null ? int.parse(item['port'].toString()) : 0,
              config: item['config'] as String? ?? '',
            ),
          )
          .toList();
    } catch (e) {
      _addLog('Error loading servers for subscription: $e');
      return [];
    }
  }

  Future<void> _saveSubscriptionUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_url', url);
    setState(() {
      _subscriptionUrl = url;
    });

    if (url.isEmpty) {
      // اگر URL خالی باشد (یعنی "All" انتخاب شده)، تمام سرورها را نمایش می‌دهیم
      _addLog('Loading all servers from all subscriptions');
      final allServers = await _loadAllServers();
      setState(() {
        _servers = allServers;
      });
      return;
    }

    // پیدا کردن نام سابسکریپشن مربوطه
    _subscriptions.firstWhere(
      (sub) => sub.url == url,
      orElse: () => Subscription(name: 'Unknown', url: url),
    );

    // بررسی می‌کنیم آیا قبلاً سرورهای این سابسکریپشن دریافت شده‌اند یا خیر
    bool hasServers = await _hasServersForSubscription(url);

    if (!hasServers && url.isNotEmpty) {
      // اگر سرورها قبلاً دریافت نشده‌اند، آن‌ها را دریافت می‌کنیم
      await _fetchServers(url);
    } else {
      // اگر سرورها قبلاً دریافت شده‌اند، آن‌ها را بارگیری می‌کنیم
      final servers = await _loadServersForSubscription(url);
      setState(() {
        _servers = servers;
      });
    }
  }

  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = json.encode(
      _subscriptions.map((sub) => sub.toJson()).toList(),
    );
    await prefs.setString('subscriptions', subscriptionsJson);
  }

  Future<void> _fetchServers(String url) async {
    // اگر URL خالی باشد، تمام سرورهای ذخیره شده را نمایش می‌دهیم
    if (url.isEmpty) {
      final allServers = await _loadAllServers();
      setState(() {
        _servers = allServers;
        _isLoading = false;
      });
      return;
    }

    String urlToFetch = url;

    if (urlToFetch.isEmpty && _defaultSubscriptionUrl.isNotEmpty) {
      urlToFetch = _defaultSubscriptionUrl;
      await _saveSubscriptionUrl(_defaultSubscriptionUrl);
    }

    if (urlToFetch.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(urlToFetch));
      if (response.statusCode == 200) {
        final servers = _parseSubscription(response.body);

        // ذخیره سرورهای جدید
        await _saveServers(servers);

        // ذخیره سرورها برای سابسکریپشن مربوطه
        await _saveServersForSubscription(urlToFetch, servers);

        setState(() {
          _servers = servers;
          _isLoading = false;
        });

        // بازیابی و ادغام سرورهای ذخیره شده
        await _loadSavedServers();

        _mergeServers(); // ادغام با سرورهای ذخیره شده
        await _saveServers(_servers); // ذخیره وضعیت جدید
      } else {
        setState(() {
          _isLoading = false;
        });
        _addLog('Failed to fetch servers: ${response.statusCode}');
        _showError('Failed to fetch servers: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _addLog('Error fetching servers: $e');
      _showError('Error fetching servers: $e');
    }
  }

  Future<void> _saveServersForSubscription(
    String url,
    List<V2RrayServer> servers,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'servers_for_subscription_${url.hashCode}';
    final serversJson = json.encode(
      servers
          .map(
            (server) => {
              'remark': server.remark,
              'address': server.address,
              'port': server.port,
              'config': server.config,
            },
          )
          .toList(),
    );
    await prefs.setString(key, serversJson);
  }

  List<V2RrayServer> _parseSubscription(String subscriptionContent) {
    try {
      final List<V2RrayServer> servers = [];
      final decoded = utf8.decode(base64.decode(subscriptionContent.trim()));
      final lines = decoded.split('\n');

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        try {
          if (isShadowsocksURL(line)) {
            final server = _parseShadowsocksURL(line, 'Unnamed Server');
            if (server != null) {
              print(
                'Successfully parsed SS server: ${server.remark}',
              ); // برای دیباگ
              servers.add(server);
            }
          } else if (line.startsWith('vmess://') ||
              line.startsWith('vless://')) {
            final server = V2RrayServer.fromV2RayURL(line);
            servers.add(server);
          }
        } catch (e) {
          print('Error parsing line: $line');
          print('Error details: $e');
          continue;
        }
      }

      print('Total parsed servers: ${servers.length}'); // برای دیباگ
      return servers;
    } catch (e) {
      print('Error parsing subscription: $e');
      return [];
    }
  }

  V2RrayServer? _parseShadowsocksURL(String url, String remark) {
    try {
      if (!url.startsWith('ss://')) {
        return null;
      }

      // حذف "ss://" از ابتدای URL
      String ssUrl = url.substring(5);

      // جدا کردن رمارک (اگر وجود داشته باشد)
      String remark = 'Unnamed Server';
      if (ssUrl.contains('#')) {
        final parts = ssUrl.split('#');
        ssUrl = parts[0];
        remark = Uri.decodeComponent(parts[1]);
      }

      String decodedUrl;
      Map<String, dynamic> serverConfig;

      // بررسی فرمت URL
      if (ssUrl.contains('@')) {
        // فرمت: ss://base64(method:password)@hostname:port
        final parts = ssUrl.split('@');
        final credentialsPart = parts[0];
        final hostPart = parts[1];

        // decode کردن اطلاعات authentication
        final credentials = utf8.decode(
          base64.decode(
            credentialsPart.padRight((credentialsPart.length + 3) & ~3, '='),
          ),
        );
        final credentialsParts = credentials.split(':');

        final method = credentialsParts[0];
        final password = credentialsParts[1];

        // پارس کردن هاست و پورت با پشتیبانی از IPv6
        String host;
        String portStr;

        if (hostPart.startsWith('[')) {
          // IPv6 address
          final closeBracket = hostPart.lastIndexOf(']');
          if (closeBracket == -1) {
            throw FormatException('Invalid IPv6 address format');
          }

          host = hostPart.substring(0, closeBracket + 1); // با براکت‌ها
          portStr = hostPart.substring(closeBracket + 2); // حذف کاراکتر ':'
        } else {
          // IPv4 or hostname
          final lastColon = hostPart.lastIndexOf(':');
          if (lastColon == -1) throw FormatException('Invalid address format');

          host = hostPart.substring(0, lastColon);
          portStr = hostPart.substring(lastColon + 1);
        }

        final port = int.parse(portStr);

        serverConfig = {
          'address': host
              .replaceAll('[', '')
              .replaceAll(']', ''), // حذف براکت‌ها
          'port': port,
          'method': method,
          'password': password,
        };
      } else {
        // فرمت: ss://base64(method:password@hostname:port)
        decodedUrl = utf8.decode(
          base64.decode(ssUrl.padRight((ssUrl.length + 3) & ~3, '=')),
        );

        final parts = decodedUrl.split('@');
        if (parts.length != 2) {
          throw FormatException('Invalid SS URL format');
        }

        final methodAndPassword = parts[0].split(':');

        // پشتیبانی از IPv6 در این فرمت
        String host;
        String portStr;
        final hostPart = parts[1];

        if (hostPart.startsWith('[')) {
          final closeBracket = hostPart.lastIndexOf(']');
          if (closeBracket == -1) {
            throw FormatException('Invalid IPv6 address format');
          }

          host = hostPart.substring(0, closeBracket + 1);
          portStr = hostPart.substring(closeBracket + 2);
        } else {
          final lastColon = hostPart.lastIndexOf(':');
          if (lastColon == -1) throw FormatException('Invalid address format');

          host = hostPart.substring(0, lastColon);
          portStr = hostPart.substring(lastColon + 1);
        }

        serverConfig = {
          'address': host.replaceAll('[', '').replaceAll(']', ''),
          'port': int.parse(portStr),
          'method': methodAndPassword[0],
          'password': methodAndPassword[1],
        };
      }

      // ساخت کانفیگ نهایی با پشتیبانی بهتر از IPv6
      final config = {
        "stats": {},
        "outbounds": [
          {
            "protocol": "shadowsocks",
            "settings": {
              "servers": [
                {
                  "address": serverConfig['address'],
                  "port": serverConfig['port'],
                  "method": serverConfig['method'],
                  "password": serverConfig['password'],
                  "level": 8,
                },
              ],
            },
            "streamSettings": {
              "network":
                  "tcp", // Using TCP instead of httpupgrade for better compatibility
              "security": "none",
              "sockopt": {
                "tcpFastOpen": true,
                "tproxy": "redirect",
                "domainStrategy":
                    "UseIP", // Changed from UseIPv4v6 to UseIP for better compatibility
                "mark": 255,
              },
            },
            "tag": "proxy",
          },
        ],
        "dns": {
          "servers": [
            "8.8.8.8",
            "1.1.1.1",
            // Removed IPv6 DNS servers for better compatibility
          ],
          "queryStrategy": "UseIP", // Changed from UseIPv4v6 to UseIP
        },
        "inbounds": [
          {
            "tag": "socks-in",
            "port": 10808,
            "protocol": "socks",
            "listen": "127.0.0.1",
            "settings": {"auth": "noauth", "udp": true, "userLevel": 8},
            "sniffing": {
              "enabled": true,
              "destOverride": ["http", "tls"],
            },
          },
        ],
        "policy": {
          "levels": {
            "8": {"statsUserUplink": true, "statsUserDownlink": true},
          },
          "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true,
            "statsOutboundUplink": true,
            "statsOutboundDownlink": true,
          },
        },
        "routing": {
          "domainStrategy": "IPIfNonMatch",
          "rules": [
            {"type": "field", "outboundTag": "proxy", "network": "tcp,udp"},
          ],
        },
      };

      print('Parsed Shadowsocks config: ${json.encode(config)}'); // برای دیباگ

      return V2RrayServer(
        remark: remark,
        address: serverConfig['address'],
        port: serverConfig['port'],
        config: json.encode(config),
      );
    } catch (e) {
      print('Error parsing Shadowsocks URL: $e');
      print('Original URL: $url'); // برای دیباگ
      return null;
    }
  }

  Future<int> _testServerDelay(
    String address,
    int port,
    FlutterV2ray v2ray,
    bool useIPv6, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      _addLog('Testing delay for $address:$port');
      print('Testing delay for $address:$port');

      // If we're connected to V2Ray, use a different approach for ping
      if (_v2rayStatus.value.state == 'CONNECTED') {
        return await _testHTTPPing();
      } else {
        return await _testDirectServerDelay(address, port, timeout);
      }
    } catch (e) {
      _addLog('Server delay test failed: $e');
      print('Server delay test failed: $e');
      return -1;
    }
  }

  // Test direct server delay (when not connected to V2Ray)
  Future<int> _testDirectServerDelay(
    String address,
    int port,
    Duration timeout,
  ) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;

    try {
      // تلاش برای اتصال به سرور با تایم‌اوت
      socket = await Socket.connect(address, port, timeout: timeout);

      // اگر اتصال موفق بود، سوکت را ببندیم
      await socket.close();

      stopwatch.stop();
      final pingValue = stopwatch.elapsedMilliseconds;

      // اگر پینگ خیلی کم است، احتمال scouting مشکلی وجود دارد
      if (pingValue < 10) return 50; // مقدار واقعی‌تر

      _addLog('Direct ping success: $pingValue ms to $address:$port');
      return pingValue;
    } catch (e) {
      _addLog('Direct ping failed: $e');
      return -1;
    } finally {
      // اطمینان از بسته شدن سوکت
      socket?.destroy();
    }
  }

  // Test ping when already connected through V2Ray

  Future<void> _connect(V2RrayServer server) async {
    try {
      _addLog('Connecting to ${server.remark}...');

      final hasPermission = await _flutterV2ray.requestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        _addLog('VPN permission denied');
        _showError('VPN permission required');
        return;
      }

      if (_v2rayStatus.value.state == 'CONNECTED' ||
          _v2rayStatus.value.state == 'CONNECTING') {
        await _disconnect();
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;
      setState(() {
        _currentServer = server.remark;
        _isPingLoading[server.remark] = true;
      });

      _v2rayStatus.value = V2RayStatus(
        state: 'CONNECTING',
        uploadSpeed: 0,
        downloadSpeed: 0,
      );

      try {
        // Get configuration with HTTP Upgrade support if enabled
        final configStr = server.getFullConfiguration(
          enableHttpUpgrade: _enableHttpUpgrade,
        );

        // Parse the config to ensure it's valid JSON
        final configMap = json.decode(configStr);

        // Make sure stats and policy are properly configured
        configMap['stats'] = configMap['stats'] ?? {};

        if (configMap['policy'] == null) {
          configMap['policy'] = {
            "levels": {
              "0": {"statsUserUplink": true, "statsUserDownlink": true},
            },
            "system": {
              "statsInboundUplink": true,
              "statsInboundDownlink": true,
              "statsOutboundUplink": true,
              "statsOutboundDownlink": true,
            },
          };
        }

        // Make sure API is configured for stats
        if (configMap['api'] == null) {
          configMap['api'] = {
            "tag": "api",
            "services": ["StatsService"],
          };
        }

        // Make sure there's an API inbound
        bool hasApiInbound = false;
        if (configMap['inbounds'] != null) {
          for (var inbound in configMap['inbounds']) {
            if (inbound['tag'] == 'api') {
              hasApiInbound = true;
              break;
            }
          }

          if (!hasApiInbound) {
            configMap['inbounds'].add({
              "tag": "api",
              "port": 8080,
              "listen": "127.0.0.1",
              "protocol": "dokodemo-door",
              "settings": {"address": "127.0.0.1"},
            });
          }
        }

        // Make sure there's a routing rule for API
        bool hasApiRoutingRule = false;
        if (configMap['routing'] != null &&
            configMap['routing']['rules'] != null) {
          for (var rule in configMap['routing']['rules']) {
            if (rule['inboundTag'] != null &&
                rule['inboundTag'] is List &&
                rule['inboundTag'].contains('api')) {
              hasApiRoutingRule = true;
              break;
            }
          }

          if (!hasApiRoutingRule) {
            configMap['routing']['rules'].insert(0, {
              "type": "field",
              "inboundTag": ["api"],
              "outboundTag": "api",
            });
          }
        }

        final jsonConfig = json.encode(configMap);
        _addLog('Starting V2Ray with stats enabled...');

        // شروع V2Ray با پشتیبانی از HTTP Upgrade
        await _flutterV2ray.startV2Ray(
          config: jsonConfig,
          remark: server.remark,
          proxyOnly: _proxyOnly,
        );

        _addLog('V2Ray started successfully');

        // ذخیره سرور فعلی
        await _saveLastSelectedServer(server.remark);

        // بروزرسانی وضعیت
        _updateStatus();

        // بلافاصله پینگ را بررسی کنیم
        _addLog('Checking ping immediately after connection...');
        print(
          'Checking ping immediately after connection...',
        ); // اضافه کردن لاگ برای دیباگ

        // تاخیر کوتاه برای اطمینان از برقراری اتصال
        await Future.delayed(const Duration(milliseconds: 500));

        // گرفتن پینگ
        await _updatePing(server);

        // شروع بروزرسانی دوره‌ای پینگ
        _startPeriodicPingUpdates();

        // نمایش اعلان موفقیت بدون اشاره به پینگ
        SnackBarUtils.showSnackBar(
          context,
          message: 'Connected to ${server.remark}',
        );
      } catch (e) {
        _addLog('Error starting V2Ray: $e');
        _showError('Error starting V2Ray: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isPingLoading[server.remark] = false;
          });
        }
      }
    } catch (e) {
      _addLog('Connection error: $e');
      _showError('Connection error: $e');
    }
  }

  // اضافه کردن تابع بروزرسانی وضعیت
  Future<void> _updateStatus() async {
    try {
      final status = await _flutterV2ray.getV2rayStatus();
      if (status != null) {
        _v2rayStatus.value = status;
      }
    } catch (e) {
      _addLog('Error updating status: $e');
    }
  }

  // Test ping using HTTP when connected to V2Ray
  Future<int> _testHTTPPing() async {
    // List of reliable endpoints to try (including IPv6-compatible sites)
    final endpoints = [
      'https://www.google.com/generate_204',
      'https://ipv6.google.com/generate_204', // IPv6 specific endpoint
      'https://www.cloudflare.com/cdn-cgi/trace',
      'https://[2606:4700:4700::1111]/cdn-cgi/trace', // Cloudflare IPv6
      'https://www.apple.com/library/test/success.html',
      'https://one.one.one.one/cdn-cgi/trace', // Cloudflare DNS
      'https://[2606:4700:4700::1001]/cdn-cgi/trace', // Cloudflare IPv6 DNS
      'https://www.example.com',
      'https://www.wikipedia.org',
    ];

    // Shuffle endpoints to avoid pattern detection
    endpoints.shuffle();

    final timeout = const Duration(seconds: 3);
    int successCount = 0;
    int totalPing = 0;

    for (final endpoint in endpoints) {
      try {
        _addLog('Testing HTTP ping to $endpoint');
        print('Testing HTTP ping to $endpoint');

        final stopwatch = Stopwatch()..start();
        final client = HttpClient();

        // Enable IPv6 connections
        client.connectionTimeout = timeout;
        client.autoUncompress = true; // For better compatibility

        // Try to resolve using IPv6 first
        final request = await client
            .getUrl(Uri.parse(endpoint))
            .timeout(timeout);

        request.headers.set('User-Agent', 'Mozilla/5.0 BlizzardPing App');
        request.headers.set('Accept', '*/*');

        final response = await request.close().timeout(timeout);

        // Read and discard response data
        await response.drain<void>().timeout(timeout);
        client.close();

        stopwatch.stop();

        if (response.statusCode >= 200 && response.statusCode < 400) {
          final pingValue = stopwatch.elapsedMilliseconds;

          if (pingValue < 10) {
            _addLog(
              'Suspicious ping value: $pingValue ms to $endpoint, ignoring',
            );
            continue;
          }

          _addLog('HTTP ping success: $pingValue ms to $endpoint');
          print('HTTP ping success: $pingValue ms to $endpoint');

          successCount++;
          totalPing += pingValue;

          if (successCount >= 2) {
            int averagePing = totalPing ~/ successCount;
            _addLog(
              'Average ping from $successCount successful tests: $averagePing ms',
            );
            return averagePing;
          }
        }
      } catch (e) {
        _addLog('HTTP ping to $endpoint failed: $e');
        print('HTTP ping to $endpoint failed: $e');
      }
    }

    if (successCount > 0) {
      int averagePing = totalPing ~/ successCount;
      _addLog(
        'Average ping from $successCount successful test: $averagePing ms',
      );
      return averagePing;
    }

    return -1;
  }

  Future<void> _updatePing(V2RrayServer server) async {
    if (!mounted) return;

    // Skip ping for empty addresses
    if (server.address.isEmpty || server.port == 0) {
      _addLog('Skipping ping for ${server.remark}: Invalid address or port');
      return;
    }

    setState(() {
      _isPingLoading[server.remark] = true;
    });

    // Update last attempt time
    _lastPingAttempt[server.remark] = DateTime.now().millisecondsSinceEpoch;

    try {
      _addLog(
        'Updating ping for ${server.remark}, address: ${server.address}:${server.port}',
      );
      print(
        'Updating ping for ${server.remark}, address: ${server.address}:${server.port}',
      );

      // Get ping value
      int delay = -1; // مقدار پیش‌فرض -1 (خطا)

      // تلاش چندباره برای گرفتن پینگ
      for (int attempt = 0; attempt < 3; attempt++) {
        // استفاده از _testHTTPPing برای همه سرورها
        delay = await _testHTTPPing();

        // اگر پینگ موفق بود، خروج از حلقه
        if (delay > 0) break;

        // کمی صبر کنیم و دوباره تلاش کنیم
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
          _addLog(
            'Retrying ping for ${server.remark} (attempt ${attempt + 2}/3)',
          );
        }
      }

      if (mounted) {
        setState(() {
          _pingResults[server.remark] = delay;
          _isPingLoading[server.remark] = false;
        });
        _addLog('Ping result for ${server.remark}: ${delay}ms');
        print('Ping result for ${server.remark}: ${delay}ms');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPingLoading[server.remark] = false;
          // در صورت خطا، مقدار -1 را ذخیره می‌کنیم
          _pingResults[server.remark] = -1;
        });
      }
      _addLog('Error updating ping: $e');
      print('Error updating ping: $e');
    }
  }

  Future<void> _handleServerChange(String newServer) async {
    if (_currentServer != newServer) {
      try {
        final wasConnected = _v2rayStatus.value.state == 'CONNECTED';

        if (_v2rayStatus.value.state == 'CONNECTED') {
          await _disconnect();
          await Future.delayed(const Duration(seconds: 1));
        }

        setState(() {
          _currentServer = newServer;
        });

        // ذخیره آخرین سرور انتخاب شده
        await _saveLastSelectedServer(newServer);

        // اگر قبلاً متصل بود، به سرور جدید متصل شویم
        if (wasConnected) {
          final server = _servers.firstWhere(
            (s) => s.remark == newServer,
            orElse: () => throw Exception('سرور انتخاب شده یافت نشد'),
          );
          await Future.delayed(const Duration(seconds: 1));
          await _connect(server);
          _addLog('اتصال خودکار به سرور جدید ${server.remark} برقرار شد');
        }
      } catch (e) {
        _addLog('خطا در تغییر سرور: $e');
        _showError('خطا در تغییر سرور: $e');
      }
    }
  }

  // Fix for ConcurrentModificationError when removing servers
  Future<void> _deleteServer(V2RrayServer server) async {
    // Create a new list instead of modifying the existing one during iteration
    final updatedServers = List<V2RrayServer>.from(_servers);
    updatedServers.removeWhere((s) => s.remark == server.remark);

    setState(() {
      _servers = updatedServers;
      if (_currentServer == server.remark) {
        _currentServer = '';
      }
    });

    await _saveServers(_servers);
    SnackBarUtils.showSnackBar(context, message: 'Server deleted successfully');
  }

  void _addLog(String log) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString()}: $log');
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _showSettingsScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SettingsScreen(
              initialProxyOnly: _proxyOnly,
              initialEnableIPv6: _enableIPv6,
              initialEnableMux: _enableMux,
              initialEnableHttpUpgrade: _enableHttpUpgrade,
              initialDefaultSubscriptionUrl: _defaultSubscriptionUrl,
            ),
      ),
    );

    // Handle the result when user returns from settings screen
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _proxyOnly = result['proxyOnly'] as bool;
        _enableIPv6 = result['enableIPv6'] as bool;
        _enableMux = result['enableMux'] as bool;
        _enableHttpUpgrade = result['enableHttpUpgrade'] as bool;
      });

      final newDefaultUrl = result['defaultSubscriptionUrl'] as String;
      if (newDefaultUrl != _defaultSubscriptionUrl) {
        await _saveDefaultSubscription(newDefaultUrl);
      }

      SnackBarUtils.showSnackBar(
        context,
        message: 'Settings saved successfully',
      );
    }
  }

  // Add this method to delete servers for a specific subscription
  Future<void> _deleteServersForSubscription(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'servers_for_subscription_${url.hashCode}';
    await prefs.remove(key);
    _addLog('Servers for subscription $url deleted');
    _handleSubscriptionDelete(
      _subscriptions.firstWhere(
        (sub) => sub.url == url,
        orElse: () => Subscription(name: 'Unknown', url: url),
      ),
    );
    setState(() {
      _servers.removeWhere((server) => server.config.contains(url));
    });
    SnackBarUtils.showSnackBar(
      context,
      message: 'Servers for subscription deleted successfully',
    );
  }

  // Modify the _handleSubscriptionDelete method to also delete servers
  Future<void> _handleSubscriptionDelete(Subscription subscription) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Subscription'),
            content: Text(
              'Are you sure you want to delete "${subscription.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (result == true) {
      // Delete servers for this subscription first
      await _deleteServersForSubscription(subscription.url);

      await _loadSubscriptions();
      // اگر سابسکریپشن فعلی حذف شده، اولین سابسکریپشن را انتخاب کن
      if (_subscriptions.every((sub) => sub.url != _subscriptionUrl)) {
        if (_subscriptions.isNotEmpty) {
          final firstSub = _subscriptions.first;
          await _saveSubscriptionUrl(firstSub.url);
        } else {
          setState(() {
            _subscriptionUrl = '';
            _servers.clear();
          });
        }
      }
    }
  }

  Future<void> _connectToSelectedServer() async {
    if (_currentServer.isEmpty) {
      _showError('لطفا یک سرور را انتخاب کنید');
      return;
    }

    try {
      final server = _servers.firstWhere(
        (s) => s.remark == _currentServer,
        orElse: () => throw Exception('سرور انتخاب شده یافت نشد'),
      );

      await _connect(server);
      _addLog('اتصال به ${server.remark} برقرار شد');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
      _addLog('خطا در اتصال: $e');
    }
  }

  Future<void> _saveServers(List<V2RrayServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = json.encode(
      servers
          .map(
            (server) => {
              'remark': server.remark,
              'address': server.address,
              'port': server.port,
              'config': server.config,
            },
          )
          .toList(),
    );
    await prefs.setString('saved_servers', serversJson);

    // اضافه کردن به لیست کلی سرورها
    await _saveServersForSubscription(_subscriptionUrl, servers);
  }

  Future<void> _loadSavedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getString('saved_servers') ?? '[]';

    try {
      final List<dynamic> serversList = json.decode(serversJson);
      final List<V2RrayServer> loadedServers =
          serversList
              .map(
                (item) => V2RrayServer(
                  remark: item['remark'] as String? ?? 'Unknown',
                  address: item['address'] as String? ?? '',
                  port:
                      item['port'] != null
                          ? int.parse(item['port'].toString())
                          : 0,
                  config: item['config'] as String? ?? '',
                ),
              )
              .toList();

      setState(() {
        _savedServers = loadedServers;

        // اگر URL سابسکریپشن خالی باشد، تمام سرورهای ذخیره شده را نمایش می‌دهیم
        if (_subscriptionUrl.isEmpty) {
          _servers = _savedServers;
        }

        _isLoading = false;
      });
    } catch (e) {
      _showError('Error loading saved servers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mergeServers() {
    // Create a safe copy of the existing servers
    final existingRemarks = Set<String>.from(_servers.map((s) => s.remark));
    final serversToAdd = <V2RrayServer>[];

    // Find servers to add without modifying the original list during iteration
    for (var savedServer in _savedServers) {
      if (!existingRemarks.contains(savedServer.remark)) {
        serversToAdd.add(savedServer);
      }
    }

    // Update the list after iteration is complete
    setState(() {
      _servers.addAll(serversToAdd);
    });
  }

  Future<void> _disconnect() async {
    if (!mounted) return;

    try {
      _stopPingUpdates(); // اطمینان از توقف تایمر پینگ
      await _flutterV2ray.stopV2Ray();

      if (!mounted) return;
      setState(() {
        // فقط وضعیت پینگ در حال بارگیری را پاک کنیم، نه نتایج پینگ
        _isPingLoading.clear();
        // _pingResults.clear(); // این خط را حذف یا کامنت کنیم
      });

      _v2rayStatus.value = V2RayStatus(
        state: 'DISCONNECTED',
        uploadSpeed: 0,
        downloadSpeed: 0,
      );

      _addLog('اتصال قطع شد');
    } catch (e) {
      if (!mounted) return;
      _showError('خطا در قطع اتصال: $e');
      _addLog('خطا در قطع اتصال: $e');
    }
  }

  Future<void> refreshServers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // نمایش اسنک بار برای شروع آپدیت دستی
    SnackBarUtils.showSnackBar(context, message: 'Updating servers...');

    try {
      // If we have a subscription URL, fetch servers for that subscription
      if (_subscriptionUrl.isNotEmpty) {
        await _fetchServers(_subscriptionUrl);
      } else {
        // If no subscription URL (All servers view), reload all servers
        final allServers = await _loadAllServers();
        setState(() {
          _servers = allServers;
        });
      }

      _addLog('Servers refreshed successfully');
      SnackBarUtils.showSnackBar(
        context,
        message: 'Servers refreshed successfully',
      );
    } catch (e) {
      _addLog('Error refreshing servers: $e');
      _showError('Error refreshing servers: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDisconnectConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Disconnect'),
            content: const Text('Are you sure you want to disconnect?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _disconnect();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );
  }

  // تابع برای پینگ همه سرورها
  Future<void> _pingAllServers() async {
    if (_isPingingAll) return;

    setState(() {
      _isPingingAll = true;
    });

    int successCount = 0;
    int failCount = 0;

    try {
      for (final server in _servers) {
        if (!mounted) break;

        setState(() {
          _isPingLoading[server.remark] = true;
        });

        try {
          await _updatePing(server);

          if (!mounted) break;

          if (_pingResults[server.remark] != null &&
              _pingResults[server.remark]! > 0) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          if (!mounted) break;

          setState(() {
            _pingResults[server.remark] = -1;
            _isPingLoading[server.remark] = false;
          });

          failCount++;
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // مرتب‌سازی سرورها بر اساس پینگ بعد از اتمام پینگ همه سرورها
      if (mounted) {
        _sortServersByPing();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPingingAll = false;
        });

        // نمایش نتیجه پینگ در SnackBar
        SnackBarUtils.showSnackBar(
          context,
          message:
              'Ping completed: $successCount successful, $failCount failed',
          icon: Icons.speed,
        );
      }
    }
  }

  // تابع جدید برای مرتب‌سازی سرورها بر اساس پینگ
  void _sortServersByPing() {
    setState(() {
      _servers.sort((a, b) {
        final pingA = _pingResults[a.remark] ?? -1;
        final pingB = _pingResults[b.remark] ?? -1;

        // سرورهای با پینگ موفق (مقدار مثبت) در اولویت هستند
        if (pingA > 0 && pingB <= 0) return -1;
        if (pingA <= 0 && pingB > 0) return 1;

        // هر دو پینگ موفق هستند، مرتب‌سازی از کمترین به بیشترین
        if (pingA > 0 && pingB > 0) return pingA.compareTo(pingB);

        // هر دو پینگ ناموفق هستند، ترتیب فعلی حفظ شود
        return 0;
      });
    });
  }

  // تابع برای شروع پینگ دوره‌ای
  void _startPeriodicPingUpdates() {
    _stopPingUpdates();

    print('Starting periodic ping updates');
    _addLog('Starting periodic ping updates');

    // ثابت کردن فاصله زمانی به 3 ثانیه
    const interval = Duration(seconds: 3);

    _pingTimer = Timer.periodic(interval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentServer.isNotEmpty &&
          _v2rayStatus.value.state == 'CONNECTED') {
        try {
          // استفاده از تست HTTP پینگ بهبود یافته
          final pingValue = await _testHTTPPing();

          if (mounted) {
            setState(() {
              _pingResults[_currentServer] = pingValue;
            });
            print('Periodic ping updated: ${pingValue}ms');
            _addLog('Periodic ping updated: ${pingValue}ms');
          }

          // به‌روزرسانی وضعیت V2Ray برای دریافت آمار آپلود و دانلود
          await _updateV2RayStats();
        } catch (e) {
          print('Periodic ping update failed: $e');
          _addLog('Periodic ping update failed: $e');
        }
      }
    });

    _addLog('Started periodic ping updates every 3 seconds');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _proxyOnly = prefs.getBool('proxy_only') ?? false;
      _enableIPv6 = prefs.getBool('enable_ipv6') ?? false;
      _enableMux = prefs.getBool('enable_mux') ?? false;
      _enableHttpUpgrade = prefs.getBool('enable_http_upgrade') ?? false;
    });
  }

  // تابع جدید برای به‌روزرسانی آمار V2Ray
  Future<void> _updateV2RayStats() async {
    try {
      final status = await _flutterV2ray.getV2rayStatus();
      if (status != null) {
        setState(() {
          _v2rayStatus.value = status;
        });
        print(
          'Updated V2Ray stats: Upload=${status.uploadSpeed}KB/s, Download=${status.downloadSpeed}KB/s',
        );
        _addLog(
          'Updated V2Ray stats: Upload=${status.uploadSpeed}KB/s, Download=${status.downloadSpeed}KB/s',
        );
      }
    } catch (e) {
      print('Error updating V2Ray stats: $e');
      _addLog('Error updating V2Ray stats: $e');
    }
  }

  void _stopPingUpdates() {
    if (_pingTimer != null) {
      _pingTimer!.cancel();
      _pingTimer = null;
      _addLog('Stopped periodic ping updates');
      print('Stopped periodic ping updates'); // Debug log
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).appBarTheme.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SafeArea(
            child: AppBar(
              elevation: 0,
              centerTitle: true,
              title: const Text('Blizzard Ping'),
              // دکمه پینگ به سمت چپ منتقل شد
              leading:
                  _isPingingAll
                      ? Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                      : IconButton(
                        icon: const Icon(Icons.speed),
                        tooltip: 'Ping All Servers',
                        onPressed: _pingAllServers,
                      ),
              actions: [
                // فقط دکمه منو باقی ماند
                Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Open Menu',
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          // Subscription List
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              // +1 برای گزینه All
              itemCount: _subscriptions.length + 1,
              itemBuilder: (context, index) {
                // اگر index صفر باشد، گزینه All را نمایش می‌دهیم
                if (index == 0) {
                  final isSelected = _subscriptionUrl.isEmpty;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: InkWell(
                      onTap: () async {
                        setState(() {
                          _subscriptionUrl = '';
                        });
                        await _saveSubscriptionUrl('');
                        // نمایش همه سرورهای ذخیره شده از تمام سابسکریپشن‌ها
                        final allServers = await _loadAllServers();
                        setState(() {
                          _servers = allServers;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          'All',
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // برای بقیه موارد، سابسکریپشن‌ها را نمایش می‌دهیم
                final subscription = _subscriptions[index - 1];
                final isSelected = subscription.url == _subscriptionUrl;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: InkWell(
                    onTap: () async {
                      setState(() {
                        _subscriptionUrl = subscription.url;
                      });
                      await _saveSubscriptionUrl(subscription.url);
                      // حذف فراخوانی خودکار _fetchServers
                      // await _fetchServers(subscription.url);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        subscription.name,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Existing content
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _servers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No servers available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FreeSubscriptionButton(
                            onSubscriptionReceived: (subscriptionUrl) {
                              _saveSubscriptionUrl(subscriptionUrl);
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add Subscription'),
                            onPressed: _openSubscriptionManager,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ReorderableListView.builder(
                      itemCount: _servers.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final item = _servers.removeAt(oldIndex);
                          _servers.insert(newIndex, item);
                        });
                        // ذخیره ترتیب جدید سرورها
                        _saveServers(_servers);
                      },
                      itemBuilder: (context, index) {
                        final server = _servers[index];
                        return Dismissible(
                          key: Key(server.remark),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) {
                            _deleteServer(server);
                            // استفاده از اسنک‌بار شخصی‌سازی شده با قابلیت بازگرداندن
                            SnackBarUtils.showSnackBar(
                              context,
                              message: '${server.remark} deleted',
                              actionLabel: 'UNDO',
                              onActionPressed: () {
                                setState(() {
                                  _servers.insert(index, server);
                                });
                                _saveServers(_servers);
                              },
                              icon: Icons.delete_outline,
                            );
                          },
                          child: ServerCard(
                            server: server,
                            currentServer: _currentServer,
                            pingResults: _pingResults,
                            isPingLoading: _isPingLoading,
                            isLoading: _isLoading,
                            onSelect:
                                (server) => _handleServerChange(server.remark),
                            onEdit: () => _editServer(server),
                            onConnect: _connect,
                            v2rayStatus: _v2rayStatus,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton:
          _currentServer.isEmpty
              ? null // Don't show FAB when no server is selected
              : ValueListenableBuilder(
                valueListenable: _v2rayStatus,
                builder: (context, status, _) {
                  final isConnected = status.state == 'CONNECTED';
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isConnected ? Colors.red : Colors.green)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap:
                            isConnected
                                ? _disconnect
                                : _connectToSelectedServer,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  isConnected
                                      ? [
                                        isDark
                                            ? Colors.red[900]!
                                            : Colors.red[400]!,
                                        isDark
                                            ? Colors.red[700]!
                                            : Colors.red[300]!,
                                      ]
                                      : [
                                        isDark
                                            ? Colors.green[900]!
                                            : Colors.green[400]!,
                                        isDark
                                            ? Colors.green[700]!
                                            : Colors.green[300]!,
                                      ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isConnected
                                      ? (isDark
                                          ? Colors.red[700]!
                                          : Colors.red[300]!)
                                      : (isDark
                                          ? Colors.green[700]!
                                          : Colors.green[300]!),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isConnected ? Colors.red : Colors.green)
                                    .withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: (isConnected ? Colors.red : Colors.green)
                                    .withOpacity(0.1),
                                blurRadius: 16,
                                spreadRadius: -2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glowing effect
                              if (isConnected)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDark
                                                ? Colors.red[700]!
                                                : Colors.red[300]!)
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              // Icon with animation
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (
                                  Widget child,
                                  Animation<double> animation,
                                ) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  isConnected
                                      ? Icons.power_settings_new_rounded
                                      : Icons.power_rounded,
                                  key: ValueKey<bool>(isConnected),
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              // Small dot indicator when connected
                              if (isConnected)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 500),
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isDark
                                                    ? Colors.red[700]!
                                                    : Colors.red[300]!)
                                                .withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar:
          _currentServer.isEmpty
              ? null // Don't show bottom bar when no server is selected
              : ValueListenableBuilder(
                valueListenable: _v2rayStatus,
                builder: (context, status, _) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final colorScheme = Theme.of(context).colorScheme;
                  final ping = _pingResults[_currentServer] ?? 0;
                  final isConnected = status.state == 'CONNECTED';

                  // اضافه کردن لاگ برای دیباگ
                  print('Current server: $_currentServer, Ping: $ping');

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // نوار پیشرفت با انیمیشن برای وضعیت اتصال
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: isConnected ? 1.0 : 0.0,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor:
                                    isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isConnected ? Colors.green : Colors.red,
                                ),
                                minHeight: 4,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // آمار ترافیک با نمودار
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              icon: Icons.arrow_upward_rounded,
                              label: 'Upload',
                              value: _formatBytes(status.uploadSpeed),
                              color: colorScheme.primary,
                              isDark: isDark,
                              progress:
                                  (status.uploadSpeed) /
                                  1024 /
                                  10, // نسبت برای نمودار
                              showProgressBar: true, // نمایش نوار پیشرفت
                            ),
                            _buildDivider(isDark),
                            _buildStatItem(
                              icon: Icons.arrow_downward_rounded,
                              label: 'Download',
                              value: _formatBytes(status.downloadSpeed),
                              color: colorScheme.secondary,
                              isDark: isDark,
                              progress:
                                  (status.downloadSpeed) /
                                  1024 /
                                  10, // نسبت برای نمودار
                              showProgressBar: true, // نمایش نوار پیشرفت
                            ),
                            _buildDivider(isDark),
                            _buildStatItem(
                              icon: Icons.timer_outlined,
                              label: 'Ping',
                              value:
                                  ping < 0
                                      ? 'Failed'
                                      : (ping > 0 ? '$ping ms' : 'N/A'),
                              color: _getPingColor(ping),
                              isDark: isDark,
                              progress:
                                  ping > 0
                                      ? (1 - ping / 1000).clamp(0.0, 1.0)
                                      : 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required double progress,
    bool showProgressBar = false,
  }) {
    // محدود کردن نسبت بین 0 تا 1
    final clampedRatio = progress.clamp(0.0, 1.0);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                label == 'Ping' && value == 'Failed'
                    ? Icons.error_outline
                    : icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),

          // نمایش نوار پیشرفت برای پینگ
          if ((label == 'Ping' && value != 'N/A' && value != 'Failed') ||
              showProgressBar) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: clampedRatio,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping < 0) return Colors.red; // Failed ping with red color
    if (ping == 0) return Colors.grey; // No ping data with grey color
    if (ping < 800) return Colors.green;
    if (ping < 900) return Colors.greenAccent;
    if (ping < 1000) return Colors.lime;
    if (ping < 1100) return Colors.yellow;
    if (ping < 1500) return Colors.orange;
    return Colors.red;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  // اضافه کردن متد جدید برای پردازش کلیپ‌برد

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.shade900.withOpacity(0.2)
                        : Colors.blue.shade50,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Blizzard Ping',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      return Text(
                        'Version: ${snapshot.data?.version ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.refresh_rounded,
                    title: 'Update Subscription',
                    onTap: () {
                      Navigator.pop(context);
                      refreshServers();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.playlist_add_rounded,
                    title: 'Subscription Manager',
                    onTap: () {
                      Navigator.pop(context);
                      _openSubscriptionManager();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsScreen();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.system_update_rounded,
                    title: 'Check for Updates',
                    onTap: () {
                      Navigator.pop(context);
                      UpdateChecker.checkForUpdate(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon:
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                    title:
                        Theme.of(context).brightness == Brightness.dark
                            ? 'Light Theme'
                            : 'Dark Theme',
                    onTap: () {
                      Navigator.pop(context);
                      // Toggle theme using MyApp's method
                      final myAppState = MyApp.of(context);
                      if (myAppState != null) {
                        myAppState.toggleTheme();
                      }
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.add_link_rounded,
                    title: 'Free Subscription',
                    onTap: () {
                      Navigator.pop(context);
                      _showFreeConfigDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.content_paste_rounded,
                    title: 'Import from Clipboard',
                    onTap: () {
                      Navigator.pop(context);
                      // Call the clipboard button functionality
                      _buildClipboardButton();
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '© 2025 Blizzard Ping',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    );
  }

  void _showFreeConfigDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDark
                          ? [Colors.grey[900]!, Colors.grey[850]!]
                          : [Colors.white, Colors.grey[50]!],
                ),

                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with glowing icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glowing effect
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    'Free Configuration',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Get a free subscription configuration to start using the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FreeSubscriptionButton(
                      onSubscriptionReceived: (subscriptionUrl) async {
                        Navigator.pop(context);
                        await _saveSubscriptionUrl(subscriptionUrl);
                        // اضافه کردن فراخوانی fetchServers بعد از ذخیره URL
                        await _fetchServers(subscriptionUrl);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Optional: Add a cancel button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _editServer(V2RrayServer server) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditServerScreen(
              server: server,
              onSave: (updatedServer) async {
                setState(() {
                  final index = _servers.indexOf(server);
                  if (index != -1) {
                    _servers[index] = updatedServer;
                  }
                });
                await _saveServers(_servers);
                SnackBarUtils.showSnackBar(
                  context,
                  message: 'Server configuration saved successfully',
                  isError: false,
                );
              },
            ),
      ),
    );
  }

  Widget _buildClipboardButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Import from Clipboard',
        onPressed: () async {
          HapticFeedback.lightImpact();
          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
          if (clipboardData?.text == null || clipboardData!.text!.isEmpty) {
            _showError('کلیپ‌برد خالی است');
            return;
          }

          final text = clipboardData.text!.trim();

          // Check if it's a subscription URL (typically starts with http:// or https://)
          if (text.startsWith('http://') || text.startsWith('https://')) {
            final subscription = Subscription(
              name: '${_subscriptions.length + 1}',
              url: text,
            );

            setState(() {
              _subscriptions.add(subscription);
            });
            await _saveSubscriptions();

            // سابسکریپشن جدید را فعال می‌کنیم
            await _saveSubscriptionUrl(text);
            await _fetchServers(text);

            SnackBarUtils.showSnackBar(
              context,
              message: 'Subscription added successfully',
            );
            return;
          }

          // Try to parse as JSON config first
          try {
            final jsonConfig = json.decode(text);
            // Basic validation of required fields
            if (jsonConfig is Map<String, dynamic> &&
                jsonConfig.containsKey('outbounds')) {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('افزودن کانفیگ'),
                      content: const Text(
                        'آیا می‌خواهید این کانفیگ را اضافه کنید؟',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);

                            // Try to extract address and port from config
                            String address = '';
                            int port = 0;
                            try {
                              final outbound = jsonConfig['outbounds'][0];
                              if (outbound != null &&
                                  outbound['settings'] != null) {
                                final vnext = outbound['settings']['vnext']?[0];
                                if (vnext != null) {
                                  address = vnext['address']?.toString() ?? '';
                                  port =
                                      int.tryParse(
                                        vnext['port']?.toString() ?? '0',
                                      ) ??
                                      0;
                                }
                              }
                            } catch (_) {
                              // Ignore parsing errors for address and port
                            }

                            final newServer = V2RrayServer(
                              remark:
                                  'Imported Config ${DateTime.now().millisecondsSinceEpoch}',
                              address: address,
                              port: port,
                              config: text,
                            );

                            setState(() {
                              _servers.add(newServer);
                            });
                            _saveServers(_servers);
                            SnackBarUtils.showSnackBar(
                              context,
                              message: 'کانفیگ با موفقیت اضافه شد',
                            );
                          },
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
              );
              return;
            }
          } catch (_) {
            // If JSON parsing fails, try as V2Ray URL
          }

          // Try to parse as V2Ray URL
          if (text.startsWith('vmess://') ||
              text.startsWith('vless://') ||
              text.startsWith('ss://')) {
            try {
              final server = V2RrayServer.fromV2RayURL(text);
              setState(() {
                _servers.add(server);
              });
              await _saveServers(_servers);
              SnackBarUtils.showSnackBar(
                context,
                message: 'سرور با موفقیت اضافه شد',
              );
              return;
            } catch (e) {
              SnackBarUtils.showSnackBar(
                context,
                message: 'لینک V2Ray نامعتبر است',
                isError: true,
              );
              return;
            }
          }

          SnackBarUtils.showSnackBar(
            context,
            message:
                'فرمت کانفیگ یا لینک نامعتبر است\nلطفا از صحت کانفیگ اطمینان حاصل کنید',
            isError: true,
          );
        },
      ),
    );
  }

  // Future<void> _saveSettings(bool _enableHttpUpgrade) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool('proxy_only', _proxyOnly);
  //   await prefs.setBool('enable_ipv6', _enableIPv6);
  //   await prefs.setBool('enable_mux', _enableMux);
  //   await prefs.setBool('enable_httpupgrade', _enableHttpUpgrade);
  // }

  // Future<void> _loadSettings() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(
  //     (bool _enableHttpUpgrade) {
  //           _proxyOnly = prefs.getBool('proxy_only') ?? false;
  //           _enableIPv6 = prefs.getBool('enable_ipv6') ?? false;
  //           _enableMux = prefs.getBool('enable_mux') ?? false;
  //           _enableHttpUpgrade = prefs.getBool('enable_httpupgrade') ?? false;
  //         }
  //         as VoidCallback,
  //   );
  // }

  Future<void> _saveLastSelectedServer(String serverRemark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_server', serverRemark);
  }
}

extension on Timer {
  // ignore: unused_element
  void Function(Timer timer) get callback => callback;
}

extension on FlutterV2ray {
  getV2rayStatus() {}
}

extension on V2RayStatus {}

bool isShadowsocksURL(String url) {
  return url.trim().toLowerCase().startsWith('ss://');
}

final config = {
  'outbounds': [
    {
      'protocol': 'shadowsocks',
      'settings': {},
      'streamSettings': {
        'network': 'tcp',
        'security': 'none',
        'sockopt': {
          'tcpFastOpen': true,
          'tproxy': 'redirect',
          'domainStrategy': 'UseIPv4v6', // Change to UseIPv4v6
          'dialerProxy': 'redirect',
          'mark': 255,
          'tcpKeepAliveInterval': 30, // Add keepalive
        },
      },
    },
  ],
  'routing': {
    'domainStrategy': 'UseIPv4v6', // Change routing strategy
    'rules': [
      {
        'type': 'field',
        'outboundTag': 'direct',
        'domain': ['geosite:private'],
      },
    ],
  },
  'dns': {
    'servers': [
      '8.8.8.8',
      '2001:4860:4860::8888', // Add IPv6 DNS servers
      '1.1.1.1',
      '2606:4700:4700::1111',
    ],
    'queryStrategy': 'UseIPv4v6',
  },
};

class UpdateChecker {
  static const String GITHUB_API =
      'https://api.github.com/repos/bloodh73/blizzardping-main/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await Dio().get(GITHUB_API);
      final latestVersion = response.data['tag_name'].toString().replaceAll(
        'v',
        '',
      );
      final downloadUrl = response.data['assets']?[0]?['browser_download_url'];
      final changelog = response.data['body'] ?? ''; // Get changelog
      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (_isNewVersionAvailable(currentVersion, latestVersion)) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                    width: 1,
                  ),
                ),
                title: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue[900] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Update Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVersionInfo(
                        currentVersion: currentVersion,
                        latestVersion: latestVersion,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      if (changelog.isNotEmpty) ...[
                        Text(
                          'What\'s New:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            changelog,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (downloadUrl != null) {
                        try {
                          Navigator.of(context).pop();
                          await _launchURL(downloadUrl);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.download_done,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Download started in your browser'),
                                  ],
                                ),
                                backgroundColor: Colors.green[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Failed to open download link'),
                                  ],
                                ),
                                backgroundColor: Colors.red[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Download Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              );
            },
          );
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to check for updates'),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  static Widget _buildVersionInfo({
    required String currentVersion,
    required String latestVersion,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVersionRow(
            'Current Version',
            currentVersion,
            isDark,
            Icons.phone_android_rounded,
          ),
          const SizedBox(height: 12),
          _buildVersionRow(
            'Latest Version',
            latestVersion,
            isDark,
            Icons.new_releases_rounded,
          ),
        ],
      ),
    );
  }

  static Widget _buildVersionRow(
    String label,
    String version,
    bool isDark,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: isDark ? Colors.blue[300] : Colors.blue, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
        const Spacer(),
        Text(
          version,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  static bool _isNewVersionAvailable(
    String currentVersion,
    String latestVersion,
  ) {
    final current = currentVersion.split('.').map(int.parse).toList();
    final latest = latestVersion.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  static Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      )) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('Error launching URL: $e');
      // اینجا می‌توانید یک اسنک‌بار نمایش دهید که نشان دهد باز کردن لینک با مشکل مواجه شده
      throw Exception('Could not launch $url: $e');
    }
  }
}
