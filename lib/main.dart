import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'package:blizzardping/class/class.dart';
import 'package:blizzardping/utils/snackbar_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blizzardping/splash_screen.dart';
import 'widgets/free_subscription_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:url_launcher/url_launcher.dart';

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

  factory V2RayServer.fromV2RayURL(String url) {
    try {
      final v2rayURL = FlutterV2ray.parseFromURL(url);
      return V2RayServer(
        remark: v2rayURL.remark,
        address: v2rayURL.address,
        port: v2rayURL.port,
        config: v2rayURL.getFullConfiguration(),
      );
    } catch (e) {
      throw Exception('Failed to parse V2Ray URL: $e');
    }
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

  Future<List<V2RayServer>> _loadAllServers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<V2RayServer> allServers = [];
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
                  (item) => V2RayServer(
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
    final uniqueServers = <V2RayServer>[];
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

  List<V2RayServer> _servers = [];
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
  List<V2RayServer> _savedServers = [];
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

  Future<List<V2RayServer>> _loadServersForSubscription(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'servers_for_subscription_${url.hashCode}';
    final serversJson = prefs.getString(key) ?? '[]';

    try {
      final List<dynamic> serversList = json.decode(serversJson);
      return serversList
          .map(
            (item) => V2RayServer(
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
    List<V2RayServer> servers,
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

  List<V2RayServer> _parseSubscription(String subscriptionContent) {
    try {
      final List<V2RayServer> servers = [];
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
            final server = V2RayServer.fromV2RayURL(line);
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

  V2RayServer? _parseShadowsocksURL(String url, String remark) {
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

      return V2RayServer(
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

  // -------------------- اصلاحات در این بخش --------------------

  // ------------------------------------------------------------
  // تابع برای توقف پینگ
  void _stopPingUpdates() {
    _pingTimer?.cancel();
    _pingTimer = null;

    // Clear any ongoing ping operations
    for (var server in _servers) {
      _isPingLoading[server.remark] = false;
    }
  }

  // تابع برای شروع پینگ دوره‌ای

  // تابع برای بروزرسانی پینگ

  Future<int> _testServerDelay(
    String address,
    int port,
    FlutterV2ray v2ray,
    bool useIPv6, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      _addLog('Testing delay for $address:$port');

      final stopwatch = Stopwatch()..start();

      // Try multiple connection attempts for better reliability
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final socket = await Socket.connect(
            address,
            port,
            timeout: timeout,
          ).catchError((error) {
            _addLog('Socket connection error (attempt $attempt): $error');
            // ignore: invalid_return_type_for_catch_error
            return null;
          });

          final delay = stopwatch.elapsedMilliseconds;
          await socket.close();

          _addLog('Socket connection successful, delay: $delay ms');
          return delay > 0 ? delay : 1;
        } catch (socketError) {
          _addLog('Socket connection error (attempt $attempt): $socketError');
        }

        // Wait a bit before retrying
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 30));
        }
      }

      return 0;
    } catch (e) {
      _addLog('Server delay test failed: $e');
      return 0;
    }
  }

  Future<void> _connect(V2RayServer server) async {
    if (!mounted) return;

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

      // حذف پینگ اتوماتیک قبل از اتصال
      // try {
      //   await _updatePing(server);
      // } catch (e) {
      //   _addLog('Pre-connection ping failed: $e');
      // }

      // حذف شروع بروزرسانی دوره‌ای پینگ
      // _startPingUpdates();

      // Parse the config and modify it if needed
      Map<String, dynamic> configMap = {};
      try {
        // اگر کانفیگ یک URL است، آن را پارس کنیم
        if (server.config.startsWith('vless://')) {
          _addLog(
            'Parsing VLESS URL: ${server.config.substring(0, Math.min(30, server.config.length))}...',
          );
          configMap = _parseVLESSURL(server.config);
        } else if (server.config.startsWith('vmess://')) {
          _addLog(
            'Parsing VMess URL: ${server.config.substring(0, Math.min(30, server.config.length))}...',
          );
          configMap = _parseVMESSURL(server.config);
        } else if (server.config.startsWith('ss://')) {
          _addLog(
            'Parsing Shadowsocks URL: ${server.config.substring(0, Math.min(30, server.config.length))}...',
          );
          // کد پارس Shadowsocks
        } else {
          // اگر کانفیگ JSON است
          configMap = json.decode(server.config);
        }

        // اطمینان از وجود بخش stats برای گزارش آمار
        configMap['stats'] = configMap['stats'] ?? {};

        // اضافه کردن بخش policy اگر وجود ندارد
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

        // تنظیم پارامترهای اضافی
        final jsonConfig = json.encode(configMap);
        _addLog(
          'Starting V2Ray with config: ${jsonConfig.substring(0, Math.min(100, jsonConfig.length))}...',
        );

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

        // تاخیر قبل از بررسی مجدد پینگ
        await Future.delayed(const Duration(seconds: 3));

        // بررسی مجدد پینگ بعد از اتصال
        try {
          await _updatePing(server);
        } catch (e) {
          _addLog('Post-connection ping failed: $e');
        }
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

  // New method to apply settings to the configuration

  Future<void> _updatePing(V2RayServer server) async {
    if (!mounted) return;

    // Skip ping for empty addresses
    if (server.address.isEmpty || server.port == 0) {
      _addLog('Skipping ping for ${server.remark}: Invalid address or port');
      return;
    }

    setState(() {
      _isPingLoading[server.remark] = true;
    });

    // Detect if the address is IPv6
    bool isIPv6 = server.address.contains(':');

    // Update last attempt time
    _lastPingAttempt[server.remark] = DateTime.now().millisecondsSinceEpoch;

    try {
      _addLog(
        'Updating ping for ${server.remark}, address: ${server.address}:${server.port}, IPv6: $isIPv6',
      );
      print(
        'Updating ping for ${server.remark}, address: ${server.address}:${server.port}',
      ); // Debug print

      // Use IPv6 automatically if the address is IPv6 and IPv6 is enabled globally
      final delay = await _testServerDelay(
        server.address,
        server.port,
        _flutterV2ray,
        isIPv6 && _enableIPv6, // Use global IPv6 setting for IPv6 addresses
        timeout: const Duration(seconds: 3),
      );

      if (mounted) {
        setState(() {
          // اطمینان از اینکه مقدار پینگ null نیست
          if (delay > 0) {
            _pingResults[server.remark] = delay;
          }
          _isPingLoading[server.remark] = false;
        });
        _addLog('Ping result for ${server.remark}: ${delay}ms');
        print('Ping result for ${server.remark}: ${delay}ms'); // اضافه کردن لاگ
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPingLoading[server.remark] = false;
        });
      }
      _addLog('Error updating ping: $e');
      print('Error updating ping: $e'); // اضافه کردن لاگ
    }
  }

  Future<void> _handleServerChange(String newServer) async {
    if (_currentServer != newServer) {
      try {
        if (_v2rayStatus.value.state == 'CONNECTED') {
          await _disconnect();
          await Future.delayed(const Duration(seconds: 1));
        }

        setState(() {
          _currentServer = newServer;
        });

        // ذخیره آخرین سرور انتخاب شده
        await _saveLastSelectedServer(newServer);
      } catch (e) {
        _addLog('خطا در تغییر سرور: $e');
        _showError('خطا در تغییر سرور: $e');
      }
    }
  }

  Future<void> _deleteServer(V2RayServer server) async {
    setState(() {
      _servers.removeWhere((s) => s.remark == server.remark);
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

  void _showSettingsDialog() {
    // Create state variables that will be updated by the dialog
    bool tempProxyOnly = _proxyOnly;
    bool tempEnableIPv6 = _enableIPv6;
    bool tempEnableMux = _enableMux;
    // حذف متغیر tempEnableHttpUpgrade
    final defaultSubController = TextEditingController(
      text: _defaultSubscriptionUrl,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Proxy Only'),
                      subtitle: const Text('Only redirect proxy traffic'),
                      value: tempProxyOnly,
                      onChanged: (value) {
                        setDialogState(() {
                          tempProxyOnly = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Enable IPv6'),
                      subtitle: const Text('Support IPv6 connections'),
                      value: tempEnableIPv6,
                      onChanged: (value) {
                        setDialogState(() {
                          tempEnableIPv6 = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Enable Mux'),
                      subtitle: const Text(
                        'Multiplex connections for better performance',
                      ),
                      value: tempEnableMux,
                      onChanged: (value) {
                        setDialogState(() {
                          tempEnableMux = value;
                        });
                      },
                    ),
                    // حذف SwitchListTile مربوط به HTTP Upgrade
                    // حذف دکمه تست HTTP Upgrade
                    const Divider(),
                    const Text('Default Subscription URL:'),
                    TextField(
                      controller: defaultSubController,
                      decoration: const InputDecoration(
                        hintText: 'Enter default subscription URL',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _proxyOnly = tempProxyOnly;
                      _enableIPv6 = tempEnableIPv6;
                      // حذف خط مربوط به _enableIPv6Ping
                      _enableMux = tempEnableMux;
                      // حذف خط مربوط به _enableHttpUpgrade
                    });

                    await _saveSettings();

                    final newDefaultUrl = defaultSubController.text.trim();
                    if (newDefaultUrl != _defaultSubscriptionUrl) {
                      await _saveDefaultSubscription(newDefaultUrl);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                      SnackBarUtils.showSnackBar(
                        context,
                        message: 'Settings saved successfully',
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _saveServers(List<V2RayServer> servers) async {
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
      final List<V2RayServer> loadedServers =
          serversList
              .map(
                (item) => V2RayServer(
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
    final existingRemarks = Set<String>.from(_servers.map((s) => s.remark));

    for (var savedServer in _savedServers) {
      if (!existingRemarks.contains(savedServer.remark)) {
        _servers.add(savedServer);
      }
    }
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

  void _showConnectionMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      items: [
        _buildPopupMenuItem(
          icon: Icons.power_settings_new,
          title: 'Connect',
          onTap: _connectToSelectedServer,
        ),
        _buildPopupMenuItem(
          icon: Icons.refresh,
          title: 'Reconnect',
          onTap: () => _disconnect().then((_) => _connectToSelectedServer()),
        ),
        _buildPopupMenuItem(
          icon: Icons.info_outline,
          title: 'Connection Info',
          onTap: () {
            Navigator.pop(context);
            _showConnectionDetails();
          },
        ),
      ],
    );
  }

  PopupMenuItem _buildPopupMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return PopupMenuItem(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      ),
    );
  }

  void _showConnectionDetails() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text('Connection Details'),
              ],
            ),
            content: ValueListenableBuilder<V2RayStatus>(
              valueListenable: _v2rayStatus,
              builder: (context, status, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow(
                      icon: Icons.radio_button_checked,
                      label: 'Status',
                      value: status.state,
                      color:
                          status.state == 'CONNECTED'
                              ? Colors.green
                              : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.upload,
                      label: 'Upload',
                      value: '${_formatSpeed(status.uploadSpeed)}/s',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.download,
                      label: 'Download',
                      value: '${_formatSpeed(status.downloadSpeed)}/s',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                );
              },
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B';
    } else if (bytesPerSecond < 1024 * 1024) {
      final kb = (bytesPerSecond / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else {
      final mb = (bytesPerSecond / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    }
  }

  // اضافه کردن متد جدید برای پینگ همه سرورها

  // تابع برای پینگ دستی یک سرور

  // متد جدید برای پارس کردن URL های V2Ray

  // پارس کردن URL های VLESS
  Map<String, dynamic> _parseVLESSURL(String url) {
    _addLog(
      'Parsing VLESS URL: ${url.substring(0, Math.min(30, url.length))}...',
    );

    // حذف پیشوند vless://
    String cleanUrl = url.replaceFirst('vless://', '');

    // جدا کردن بخش fragment (بعد از #)
    String fragment = '';
    if (cleanUrl.contains('#')) {
      final parts = cleanUrl.split('#');
      cleanUrl = parts[0];
      fragment = parts.length > 1 ? Uri.decodeComponent(parts[1]) : '';
    }

    // پارس کردن URI
    final uri = Uri.parse('vless://$cleanUrl');

    // استخراج UUID از userInfo
    String uuid = '';
    if (uri.userInfo.isNotEmpty) {
      uuid = uri.userInfo.split(':')[0];
    }

    _addLog('VLESS: UUID=$uuid, Host=${uri.host}, Port=${uri.port}');

    // پارس کردن پارامترها از query و fragment
    final params = <String, String>{};

    // پارامترهای query
    uri.queryParameters.forEach((key, value) {
      params[key] = value;
    });

    // پارامترهای fragment
    if (fragment.isNotEmpty) {
      final parts = fragment.split('&');
      for (var part in parts) {
        if (part.contains('=')) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            params[keyValue[0]] = Uri.decodeComponent(keyValue[1]);
          }
        }
      }
    }

    _addLog('VLESS params: ${params.toString()}');

    // تنظیم مقادیر پیش‌فرض برای پارامترهای مهم
    final type = params['type'] ?? 'tcp';
    final security = params['security'] ?? 'none';
    final path = params['path'] ?? '/';
    final host = params['host'] ?? uri.host;

    // ساخت کانفیگ VLESS با پشتیبانی از HTTP Upgrade
    final config = {
      "stats": {}, // اطمینان از وجود بخش stats برای ثبت آمار ترافیک
      "log": {"loglevel": "warning"},
      "outbounds": [
        {
          "protocol": "vless",
          "settings": {
            "vnext": [
              {
                "address": uri.host,
                "port": uri.port > 0 ? uri.port : 443,
                "users": [
                  {
                    "id": uuid,
                    "encryption": "none",
                    "flow": params['flow'] ?? "",
                  },
                ],
              },
            ],
          },
          "streamSettings": {
            "network": type, // استفاده از نوع شبکه از پارامترها
            "security": security,
            "sockopt": {
              "tcpFastOpen": true,
              "tcpKeepAliveInterval": 30,
              "domainStrategy": _enableIPv6 ? "UseIPv4v6" : "UseIP",
            },
          },
          "tag": "proxy",
          "mux": {"enabled": _enableMux, "concurrency": 8},
        },
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {"type": "field", "outboundTag": "proxy", "network": "tcp,udp"},
        ],
      },
      "dns": {
        "servers":
            _enableIPv6
                ? [
                  "8.8.8.8",
                  "1.1.1.1",
                  "2001:4860:4860::8888",
                  "2606:4700:4700::1111",
                ]
                : ["8.8.8.8", "1.1.1.1"],
        "queryStrategy": _enableIPv6 ? "UseIPv4v6" : "UseIP",
      },
      // اضافه کردن بخش policy برای بهبود گزارش آمار
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
    };

    // تنظیم پارامترهای مخصوص هر نوع شبکه
    final outbound = (config["outbounds"] as List<dynamic>)[0];

    if (type == "tcp") {
      outbound["streamSettings"]["tcpSettings"] = {
        "header": {"type": "none"},
      };
    } else if (type == "ws") {
      outbound["streamSettings"]["wsSettings"] = {
        "path": path,
        "headers": {"Host": host},
      };
    } else if (type == "http" || type == "h2") {
      outbound["streamSettings"]["httpSettings"] = {
        "path": path,
        "host": [host],
      };
    } else if (type == "grpc") {
      outbound["streamSettings"]["grpcSettings"] = {
        "serviceName": path,
        "multiMode": false,
      };
    } else if (type == "httpupgrade") {
      // بهبود تنظیمات HTTP Upgrade
      outbound["streamSettings"]["httpupgradeSettings"] = {
        "path": path,
        "host": host,
      };
    }

    // تنظیمات TLS اگر فعال باشد
    if (security == "tls") {
      outbound["streamSettings"]["tlsSettings"] = {
        "serverName": params['sni'] ?? host,
        "allowInsecure": false,
      };
    }

    _addLog('Generated VLESS config with type: $type');
    return config;
  }

  // پارس کردن URL های VMESS
  Map<String, dynamic> _parseVMESSURL(String url) {
    // حذف پیشوند vmess://
    final cleanUrl = url.replaceFirst('vmess://', '');

    // دیکود base64
    final decoded = utf8.decode(base64.decode(cleanUrl));

    // پارس JSON
    final Map<String, dynamic> data = json.decode(decoded);

    // ساخت کانفیگ VMESS
    final config = {
      "stats": {},
      "outbounds": [
        {
          "protocol": "vmess",
          "settings": {
            "vnext": [
              {
                "address": data['add'],
                "port": int.parse(data['port'].toString()),
                "users": [
                  {
                    "id": data['id'],
                    "alterId": int.parse(data['aid'].toString()),
                    "security": data['scy'] ?? "auto",
                  },
                ],
              },
            ],
          },
          "streamSettings": {
            "network": "httpupgrade",
            "security": data['tls'] == 'tls' ? "tls" : "none",
            "httpupgradeSettings": {
              "path": data['path'] ?? "/",
              "host": data['host'] ?? data['add'],
            },
          },
          "tag": "proxy",
        },
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {"type": "field", "outboundTag": "proxy", "network": "tcp,udp"},
        ],
      },
    };

    _addLog('Generated VMESS config with httpupgrade');
    return config;
  }

  // تابع برای پینگ همه سرورها
  Future<void> _pingAllServers() async {
    if (!mounted) return;

    _addLog('Starting ping test for all servers');

    try {
      for (var server in _servers) {
        if (!mounted) break;

        setState(() {
          _isPingLoading[server.remark] = true;
        });

        try {
          await _updatePing(server);
        } catch (e) {
          _addLog('Ping failed for ${server.remark}: $e');
        } finally {
          if (mounted) {
            setState(() {
              _isPingLoading[server.remark] = false;
            });
          }
        }

        // کمی مکث بین هر پینگ
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      // اگر سرور فعلی انتخاب شده است، پینگ آن را دوباره بررسی کنیم
      if (_currentServer.isNotEmpty) {
        try {
          final currentServerObj = _servers.firstWhere(
            (s) => s.remark == _currentServer,
            orElse: () => throw Exception('Current server not found'),
          );
          await _updatePing(currentServerObj);
        } catch (e) {
          _addLog('Failed to update ping for current server: $e');
        }
      }
    }

    _addLog('Completed ping test for all servers');

    // استفاده از SnackBarUtils به جای ScaffoldMessenger مستقیم
    if (mounted) {
      SnackBarUtils.showSnackBar(
        context,
        message: 'Ping test completed for all servers',
      );
    }
  }

  // تابع برای پینگ فقط سرور انتخاب شده

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

              leading: ValueListenableBuilder<V2RayStatus>(
                valueListenable: _v2rayStatus,
                builder: (context, status, _) {
                  final isConnected = status.state == 'CONNECTED';
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final colorScheme = Theme.of(context).colorScheme;

                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (isConnected) {
                            _showDisconnectConfirmation();
                          } else {
                            _showConnectionMenu();
                          }
                        },
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _showConnectionDetails();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color:
                                isConnected
                                    ? (isDark
                                        ? colorScheme.primary.withOpacity(0.15)
                                        : colorScheme.primary.withOpacity(0.1))
                                    : (isDark
                                        ? Colors.grey[900]?.withOpacity(0.2)
                                        : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isConnected
                                      ? (isDark
                                          ? colorScheme.primary.withOpacity(0.5)
                                          : colorScheme.primary.withOpacity(
                                            0.3,
                                          ))
                                      : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow:
                                isConnected
                                    ? [
                                      BoxShadow(
                                        color: colorScheme.primary.withOpacity(
                                          0.2,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
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
                                      ? Icons.wifi
                                      : Icons.wifi_off_rounded,
                                  key: ValueKey(isConnected),
                                  color:
                                      isConnected
                                          ? colorScheme.primary
                                          : (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600]),
                                  size: 22,
                                ),
                              ),
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
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.4),
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.speed),
                  tooltip: 'Ping All Servers',
                  onPressed: _pingAllServers,
                ),
                _buildUpdateSubscriptionButton(),
                _buildFreeConfigButton(),
                _buildClipboardButton(),
                _buildMoreActionsButton(),
              ],
            ),
          ),
        ),
      ),
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
                    : RefreshIndicator(
                      onRefresh: refreshServers,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _servers.length,
                        itemBuilder: (context, index) {
                          final server = _servers[index];
                          return ServerCard(
                            server: server,
                            currentServer: _currentServer,

                            pingResults: _pingResults,
                            isPingLoading: _isPingLoading,
                            isLoading: _isLoading,
                            onSelect:
                                (server) => _handleServerChange(server.remark),
                            onDelete: () => _deleteServer(server),
                            onEdit: () => _editServer(server),
                            onConnect: _connect,
                            v2rayStatus: _v2rayStatus,
                            // onPing: _pingServer, // این خط را حذف یا کامنت می‌کنیم
                          );
                        },
                      ),
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

                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
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
                            ),
                            _buildDivider(isDark),
                            _buildStatItem(
                              icon: Icons.timer_outlined,
                              label: 'Ping',
                              value: ping > 0 ? '$ping ms' : 'N/A',
                              color: _getPingColor(ping),
                              isDark: isDark,
                              progress:
                                  ping > 0
                                      ? ping / 500
                                      : 0, // نسبت برای نمودار (حداکثر 500ms)
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
  }) {
    // محدود کردن نسبت بین 0 تا 1
    final clampedRatio = progress.clamp(0.0, 1.0);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          // نمودار میله‌ای با انیمیشن
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: clampedRatio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animatedRatio, _) {
              return Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping <= 0) return Colors.grey;
    if (ping < 800) return Colors.green;
    if (ping < 1100) return Colors.orange;
    return Colors.red;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  // اضافه کردن متد جدید برای پردازش کلیپ‌برد

  Widget _buildUpdateSubscriptionButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: () {
          HapticFeedback.lightImpact();
          refreshServers();
        },
        tooltip: 'Update Subscription',
      ),
    );
  }

  Widget _buildFreeConfigButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.lightImpact();
            _showFreeConfigDialog();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.blue[300]! : Colors.blue[700]!,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'Free',
                  style: TextStyle(
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreActionsButton() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        return PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder:
              (context) => [
                _buildPopupMenuItem(
                  icon: Icons.refresh_rounded,
                  title: 'Refresh Servers',
                  onTap: refreshServers,
                ),
                _buildPopupMenuItem(
                  icon: Icons.playlist_add_rounded,
                  title: 'Subscription Manager',
                  onTap: _openSubscriptionManager,
                ),
                _buildPopupMenuItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: _showSettingsDialog,
                ),
                _buildPopupMenuItem(
                  icon: Icons.system_update_rounded,
                  title: 'Check for Updates',
                  onTap: () => UpdateChecker.checkForUpdate(context),
                ),
                _buildPopupMenuItem(
                  icon:
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                  title:
                      Theme.of(context).brightness == Brightness.dark
                          ? 'Light Theme'
                          : 'Dark Theme',
                  onTap: () {
                    // Toggle theme using MyApp's method
                    final myAppState = MyApp.of(context);
                    if (myAppState != null) {
                      myAppState.toggleTheme();
                    }
                  },
                ),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Version: ${snapshot.data?.version ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
        );
      },
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

  void _editServer(V2RayServer server) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    final configController = TextEditingController(text: server.config);
    final remarkController = TextEditingController(text: server.remark);
    final addressController = TextEditingController(text: server.address);
    final portController = TextEditingController(text: server.port.toString());

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: colors.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ویرایش سرور',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Settings Section
                          _buildSectionHeader(
                            title: 'تنظیمات اصلی',
                            icon: Icons.settings_rounded,
                            colors: colors,
                          ),
                          const SizedBox(height: 16),

                          // Remark Field
                          _buildInputField(
                            controller: remarkController,
                            label: 'نام سرور',
                            icon: Icons.label_rounded,
                            colors: colors,
                          ),
                          const SizedBox(height: 16),

                          // Address Field
                          _buildInputField(
                            controller: addressController,
                            label: 'آدرس سرور',
                            icon: Icons.dns_rounded,
                            colors: colors,
                          ),
                          const SizedBox(height: 16),

                          // Port Field
                          _buildInputField(
                            controller: portController,
                            label: 'پورت',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            colors: colors,
                          ),
                          const SizedBox(height: 24),

                          // Advanced Settings Section
                          _buildSectionHeader(
                            title: 'تنظیمات پیشرفته',
                            icon: Icons.code_rounded,
                            colors: colors,
                            trailing: TextButton.icon(
                              onPressed:
                                  () => _showJsonEditorDialog(
                                    configController,
                                    colors,
                                  ),
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                              ),
                              label: const Text('ویرایش'),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Config Preview
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : colors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.outline.withOpacity(0.1),
                              ),
                            ),
                            child: TextField(
                              controller: configController,
                              maxLines: 6,
                              readOnly: true,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: colors.onSurface.withOpacity(0.8),
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(12),
                                hintText: 'کانفیگ JSON',
                                hintStyle: TextStyle(
                                  color: colors.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : colors.surface,
                      border: Border(
                        top: BorderSide(color: colors.outline.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('انصراف'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed:
                              () => _saveV2rayServerChanges(
                                context,
                                server,
                                remarkController.text,
                                addressController.text,
                                portController.text,
                                configController.text,
                              ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('ذخیره تغییرات'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required ColorScheme colors,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: colors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colors,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 14, color: colors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary),
        ),
        filled: true,
        fillColor: colors.surfaceVariant.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  Future<void> _saveV2rayServerChanges(
    BuildContext context,
    V2RayServer originalServer,
    String remark,
    String address,
    String portStr,
    String config,
  ) async {
    try {
      // Validate JSON config
      json.decode(config);

      // Validate port
      final port = int.tryParse(portStr);
      if (port == null || port < 1 || port > 65535) {
        throw Exception('Port must be between 1 and 65535');
      }

      // Validate other fields
      if (remark.trim().isEmpty) {
        throw Exception('Server name cannot be empty');
      }
      if (address.trim().isEmpty) {
        throw Exception('Server address cannot be empty');
      }

      final updatedServer = V2RayServer(
        remark: remark.trim(),
        address: address.trim(),
        port: port,
        config: config.trim(),
      );

      setState(() {
        final index = _servers.indexOf(originalServer);
        if (index != -1) {
          _servers[index] = updatedServer;
        }
      });

      await _saveServers(_servers);
      Navigator.pop(context);

      SnackBarUtils.showSnackBar(
        context,
        message: 'Server configuration saved successfully',
        isError: false,
      );
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showV2raySnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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

                            final newServer = V2RayServer(
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
              final server = V2RayServer.fromV2RayURL(text);
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

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('proxy_only', _proxyOnly);
    await prefs.setBool('enable_ipv6', _enableIPv6);
    await prefs.setBool('enable_mux', _enableMux);
    // حذف خط مربوط به enable_httpupgrade
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _proxyOnly = prefs.getBool('proxy_only') ?? false;
      _enableIPv6 = prefs.getBool('enable_ipv6') ?? false;
      _enableMux = prefs.getBool('enable_mux') ?? false;
      // حذف خط مربوط به enable_httpupgrade
    });
  }

  Future<void> _saveLastSelectedServer(String serverRemark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_server', serverRemark);
  }

  void _showJsonEditorDialog(
    TextEditingController configController,
    ColorScheme colors,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.code, color: colors.onPrimary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'ویرایش کانفیگ',
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.format_align_left,
                            color: colors.onPrimary,
                          ),
                          onPressed: () {
                            try {
                              final jsonObj = json.decode(
                                configController.text,
                              );
                              final prettyJson = const JsonEncoder.withIndent(
                                '  ',
                              ).convert(jsonObj);
                              configController.text = prettyJson;
                            } catch (e) {
                              _showV2raySnackBar(
                                'فرمت JSON نامعتبر است',
                                isError: true,
                              );
                            }
                          },
                          tooltip: 'فرمت‌بندی JSON',
                        ),
                      ],
                    ),
                  ),
                  // Editor
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: configController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: colors.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: colors.outline.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: colors.outline.withOpacity(0.2),
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                  // Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colors.outline.withOpacity(0.2)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                          ),
                          child: const Text('بستن'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

extension on FlutterV2ray {
  getV2rayStatus() {}
}

extension on V2RayStatus {}

// -------------------- اصلاحات در این بخش --------------------

// ------------------------------------------------------------

// اصلاح تابع پردازش متن کپی شده

// اضافه کردن تابع برای تشخیص لینک Shadowsocks
bool isShadowsocksURL(String url) {
  return url.trim().toLowerCase().startsWith('ss://');
}

// اصلاح تابع درخواست دسترسی

// تعریف تابع _startPingUpdates

// Add server change handler

// اضافه کردن متد برای حذف سرور
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
