import 'dart:async';
import 'dart:convert';
import 'package:blizzardping/class/class.dart';
import 'package:blizzardping/utils/snackbar_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blizzardping/splash_screen.dart';
import 'widgets/free_subscription_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      if (url.isNotEmpty) {}
    });
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
  bool _isDarkMode = true; // متغیر جدید برای حالت تم

  void _openSubscriptionManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SubscriptionManager(
              currentSubscriptionUrl: _subscriptionUrl,
              onSubscriptionSelected: (url) async {
                await _saveSubscriptionUrl(url);
                await _fetchServers(url);
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
          await _fetchServers(firstSub.url);
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    _loadInitialData(); // اضافه کردن این خط
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPermission();
    });
    // چک کردن آپدیت بعد از مدت کوتاهی
    Future.delayed(const Duration(seconds: 2), () {
      UpdateChecker.checkForUpdate(context);
    });
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

      // اگر subscription فعلی خالی است و subscriptionها وجود دارند
      if (_subscriptionUrl.isEmpty && _subscriptions.isNotEmpty) {
        final firstSub = _subscriptions.first;
        await _saveSubscriptionUrl(firstSub.url);
        await _fetchServers(firstSub.url);
      }

      _addLog('بارگذاری اطلاعات با موفقیت انجام شد');
    } catch (e) {
      _addLog('خطا در بارگذاری اطلاعات: $e');
      _showError('خطا در بارگذاری اطلاعات اولیه');
    }
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

  Future<void> _saveSubscriptionUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_url', url);
    setState(() {
      _subscriptionUrl = url;
    });

    // پیدا کردن نام سابسکریپشن مربوطه
    _subscriptions.firstWhere(
      (sub) => sub.url == url,
      orElse: () => Subscription(name: 'Unknown', url: url),
    );

    setState(() {});
  }

  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = json.encode(
      _subscriptions.map((sub) => sub.toJson()).toList(),
    );
    await prefs.setString('subscriptions', subscriptionsJson);
  }

  Future<void> _fetchServers(String url) async {
    String urlToFetch = _subscriptionUrl;

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
            final server = _parseShadowsocksURL(line);
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

  V2RayServer? _parseShadowsocksURL(String url) {
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

      // ساخت کانفیگ نهایی
      final config = {
        'stats': {}, // اضافه کردن بخش stats
        'outbounds': [
          {
            'protocol': 'shadowsocks',
            'settings': {
              'servers': [
                {
                  'address': serverConfig['address'],
                  'port': serverConfig['port'],
                  'method': serverConfig['method'],
                  'password': serverConfig['password'],
                  'level': 8,
                },
              ],
            },
            'streamSettings': {
              'network': 'tcp',
              'security': 'none',
              'sockopt': {
                'tcpFastOpen': true,
                'tproxy': 'redirect', // اضافه کردن تنظیمات tproxy
                'domainStrategy': 'UseIP', // استراتژی استفاده از IP
              },
            },
            'tag': 'proxy', // اضافه کردن تگ
          },
        ],
        'inbounds': [
          {
            'tag': 'socks-in',
            'port': 10808,
            'protocol': 'socks',
            'listen': '127.0.0.1',
            'settings': {'auth': 'noauth', 'udp': true, 'userLevel': 8},
            'sniffing': {
              // اضافه کردن sniffing
              'enabled': true,
              'destOverride': ['http', 'tls'],
            },
          },
        ],
        'policy': {
          // اضافه کردن بخش policy
          'levels': {
            '8': {'statsUserUplink': true, 'statsUserDownlink': true},
          },
          'system': {
            'statsInboundUplink': true,
            'statsInboundDownlink': true,
            'statsOutboundUplink': true,
            'statsOutboundDownlink': true,
          },
        },
        'routing': {
          'domainStrategy': 'IPIfNonMatch',
          'rules': [
            {'type': 'field', 'outboundTag': 'proxy', 'network': 'tcp,udp'},
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

  // تابع برای شروع پینگ

  // تابع برای بروزرسانی پینگ

  Future<void> _connect(V2RayServer server) async {
    if (!mounted) return;

    try {
      final hasPermission = await _flutterV2ray.requestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        _addLog('دسترسی VPN رد شد');
        _showError('نیاز به دسترسی VPN');
        return;
      }

      if (_v2rayStatus.value.state == 'CONNECTED' ||
          _v2rayStatus.value.state == 'CONNECTING') {
        await _disconnect();
        await Future.delayed(const Duration(seconds: 3)); // افزایش تاخیر
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

      var configMap = json.decode(server.config);

      // بهبود تنظیمات IPv6
      if (_enableIPv6) {
        configMap['outbounds'][0]['streamSettings']['sockopt'] = {
          'tcpFastOpen': true,
          'tproxy': 'redirect',
          'domainStrategy': 'UseIPv4v6', // IPv4/IPv6 strategy
          'dialerProxy': 'redirect',
          'mark': 255,
          'tcpKeepAliveInterval': 30, // Keep-alive interval
        };

        // DNS settings
        configMap['dns'] = {
          'servers': [
            '8.8.8.8',
            '2001:4860:4860::8888', // Google DNS IPv6
            '1.1.1.1',
            '2606:4700:4700::1111', // Cloudflare DNS IPv6
          ],
          'queryStrategy': 'UseIPv4v6',
        };
      }

      await _flutterV2ray.startV2Ray(
        config: json.encode(configMap),
        remark: server.remark,
        proxyOnly: _proxyOnly,
      );

      // افزایش زمان انتظار و تعداد تلاش‌ها
      int attempts = 0;
      const maxAttempts = 30; // افزایش تعداد تلاش‌ها

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;

        if (_v2rayStatus.value.state == 'CONNECTED') {
          _addLog('اتصال به ${server.remark} برقرار شد');
          await _updatePing(server);
          _startPingUpdates();
          return;
        }
      }

      throw Exception('اتصال پس از چند تلاش ناموفق بود');
    } catch (e) {
      _addLog('خطای اتصال: $e');
      await _disconnect();
      throw Exception(
        'خطا در اتصال: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _updatePing(V2RayServer server) async {
    if (!mounted) return;

    // حذف setState برای نمایش لودینگ
    try {
      final delay = await _testServerDelay(
        server.config,
        [],
        _flutterV2ray,
        _enableIPv6,
        timeout: const Duration(seconds: 3),
      );

      if (mounted) {
        setState(() {
          _pingResults[server.remark] = delay;
        });
      }
    } catch (e) {
      print('Ping update failed: $e');
      if (mounted) {
        setState(() {
          _pingResults[server.remark] = 0;
        });
      }
    }
  }

  void _startPingUpdates() {
    _stopPingUpdates();

    _pingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_currentServer.isEmpty) return;

      final currentServerObj = _servers.firstWhere(
        (s) => s.remark == _currentServer,
        orElse: () => V2RayServer(remark: '', address: '', port: 0, config: ''),
      );

      // اگر سرور پیدا نشد، تایمر را متوقف کنید

      // فقط اگر واقعاً متصل هستیم پینگ را بروز کنید
      if (_v2rayStatus.value.state == 'CONNECTED') {
        try {
          await _updatePing(currentServerObj);
        } catch (e) {
          print('Ping update error: $e');
          // خطای پینگ نباید باعث قطع اتصال شود
        }
      }
    });
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
    bool tempProxyOnly = _proxyOnly;
    bool tempEnableIPv6 = _enableIPv6;
    bool tempEnableMux = _enableMux;
    bool tempIsDarkMode = _isDarkMode;
    final defaultSubController = TextEditingController(
      text: _defaultSubscriptionUrl,
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Settings',
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
                        _buildSettingsSection('Appearance', [
                          _buildSettingsSwitch(
                            icon: Icons.dark_mode,
                            title: 'Dark Mode',
                            subtitle: 'Enable dark theme',
                            value: tempIsDarkMode,
                            onChanged: (value) async {
                              setDialogState(() => tempIsDarkMode = value);
                              setState(() => _isDarkMode = value);
                              final myAppState = MyApp.of(context);
                              if (myAppState != null) {
                                myAppState.updateThemeMode(value);
                              }
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('is_dark_mode', value);
                            },
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildSettingsSection('Connection', [
                          _buildSettingsSwitch(
                            icon: Icons.route,
                            title: 'Proxy Only',
                            subtitle: 'Route all traffic through proxy',
                            value: tempProxyOnly,
                            onChanged:
                                (value) =>
                                    setDialogState(() => tempProxyOnly = value),
                          ),
                          _buildSettingsSwitch(
                            icon: Icons.network_wifi,
                            title: 'Enable IPv6',
                            subtitle: 'Support IPv6 connections',
                            value: tempEnableIPv6,
                            onChanged:
                                (value) => setDialogState(
                                  () => tempEnableIPv6 = value,
                                ),
                          ),
                          _buildSettingsSwitch(
                            icon: Icons.speed,
                            title: 'Enable Mux',
                            subtitle:
                                'Multiplex connections for better performance',
                            value: tempEnableMux,
                            onChanged:
                                (value) =>
                                    setDialogState(() => tempEnableMux = value),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildSettingsSection('Subscription', [
                          _buildTextField(
                            controller: defaultSubController,
                            icon: Icons.link,
                            label: 'Default Subscription URL',
                            hint: 'Enter subscription URL',
                          ),
                        ]),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.secondary,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _proxyOnly = tempProxyOnly;
                          _enableIPv6 = tempEnableIPv6;
                          _enableMux = tempEnableMux;
                        });

                        await _saveSettings();

                        final newDefaultUrl = defaultSubController.text.trim();
                        if (newDefaultUrl != _defaultSubscriptionUrl) {
                          await _saveDefaultSubscription(newDefaultUrl);
                        }

                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Settings saved successfully'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ),
          ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
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
  }

  Future<void> _loadSavedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getString('saved_servers') ?? '[]';
    final List<dynamic> serversList = json.decode(serversJson);

    _savedServers =
        serversList
            .map(
              (item) => V2RayServer(
                remark: item['remark'] as String,
                address: item['address'] as String,
                port: item['port'] as int,
                config: item['config'] as String,
              ),
            )
            .toList();

    _mergeServers();
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
      _stopPingUpdates();
      await _flutterV2ray.stopV2Ray();

      if (!mounted) return;
      setState(() {
        _isPingLoading.clear();
        _pingResults.clear();
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
    if (!mounted) return;

    if (_subscriptionUrl.isEmpty) {
      _showError('No subscription URL configured');
      _openSubscriptionManager();
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _addLog('Refreshing servers...');

    try {
      final response = await http.get(Uri.parse(_subscriptionUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final servers = _parseSubscription(response.body);
        await _saveServers(servers);

        if (!mounted) return;
        setState(() {
          _servers = servers;
          _isLoading = false;
          _pingResults.clear();
          _isPingLoading.clear();

          if (_currentServer.isNotEmpty) {
            _disconnect();
          }
        });

        await _loadSavedServers();
        _addLog('Successfully refreshed ${servers.length} servers');
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            message: 'Servers refreshed successfully',
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _addLog('Failed to refresh servers: ${response.statusCode}');
        SnackBarUtils.showSnackBar(
          context,
          message: 'Failed to refresh servers: ${response.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _addLog('Error refreshing servers: $e');
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error refreshing servers: $e',
        isError: true,
      );
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
  Future<void> _pingAllServers() async {
    if (_servers.isEmpty) {
      _showError('No servers available');
      return;
    }

    setState(() {
      for (var server in _servers) {
        _isPingLoading[server.remark] = true;
      }
    });

    _addLog('Starting ping test for all servers...');

    for (var server in _servers) {
      try {
        await _updatePing(server);
      } catch (e) {
        _addLog('Error pinging ${server.remark}: $e');
      }
    }

    setState(() {
      for (var server in _servers) {
        _isPingLoading[server.remark] = false;
      }
    });

    _addLog('Completed ping test for all servers');
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
                // Add this line
                _buildPingAllButton(),
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
            child:
                _subscriptions.isEmpty
                    ? Center(
                      child: Text(
                        'No subscriptions added',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                    : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _subscriptions.length,
                      itemBuilder: (context, index) {
                        final subscription = _subscriptions[index];
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
                              await _fetchServers(subscription.url);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.5),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                subscription.name,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                          : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
                          return ServerCard(
                            server: _servers[index],
                            currentServer: _currentServer,
                            v2rayStatus: _v2rayStatus,
                            pingResults: _pingResults,
                            isPingLoading: _isPingLoading,
                            isLoading: _isLoading,
                            onSelect:
                                (server) => _handleServerChange(server.remark),
                            onDelete: () => _deleteServer(_servers[index]),
                            onEdit:
                                () => _editServer(
                                  _servers[index],
                                ), // Add edit callback
                            onConnect: _connect,
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
    );
  }

  // اضافه کردن متد جدید برای پردازش کلیپ‌برد

  Widget _buildPingAllButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: const Icon(Icons.speed_rounded),
        onPressed: () {
          HapticFeedback.lightImpact();
          _pingAllServers();
        },
        tooltip: 'Ping All Servers',
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
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                      onSubscriptionReceived: (subscriptionUrl) {
                        Navigator.pop(context);
                        _saveSubscriptionUrl(subscriptionUrl);
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
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _proxyOnly = prefs.getBool('proxy_only') ?? false;
      _enableIPv6 = prefs.getBool('enable_ipv6') ?? false;
      _enableMux = prefs.getBool('enable_mux') ?? false;
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

extension on V2RayStatus {}

// -------------------- اصلاحات در این بخش --------------------

// ------------------------------------------------------------

Future<int> _testServerDelay(
  String config,
  List<String> urls,
  FlutterV2ray flutterV2ray,
  bool enableIPv6, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final client = http.Client();
    final stopwatch = Stopwatch()..start();

    // لیست آدرس‌های تست (هم IPv4 و هم IPv6)
    final testUrls = [
      'http://www.gstatic.com/generate_204',
      if (enableIPv6)
        'http://[2404:6800:4008:c07::67]/generate_204', // آدرس IPv6 گوگل
    ];

    for (final url in testUrls) {
      try {
        final response = await client
            .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(timeout);

        if (response.statusCode == 204) {
          stopwatch.stop();
          return stopwatch.elapsedMilliseconds;
        }
      } catch (e) {
        print('HTTP request failed for $url: $e');
        continue;
      }
    }

    client.close();
    return 0;
  } catch (e) {
    print('Error in _testServerDelay: $e');
    return 0;
  }
}

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
