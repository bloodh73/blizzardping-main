import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  String currentServer = "Server not selected";
  double downloadSpeed = 0.0;
  double uploadSpeed = 0.0;
  int ping = 0;
  List<V2RayServer> servers = [];
  bool isLoading = false;
  final TextEditingController _subscriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    setState(() {
      isLoading = true;
    });

    try {
      print("Starting to load saved data..."); // لاگ جدید

      // Load saved servers first
      await _loadSavedServers();
      print("Servers loaded: ${servers.length}"); // لاگ جدید

      // Then load saved subscription
      await _loadSavedSubscription();
      print("Subscription loaded"); // لاگ جدید

      // Finally load last selected server
      await _loadLastSelectedServer();
      print("Last selected server: $currentServer"); // لاگ جدید
    } catch (e) {
      print("Error in _loadSavedData: $e"); // لاگ جدید
      _showSnackBar('Error loading saved data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSavedServers() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final serversJson = prefs.getString('saved_servers');
      print("Raw saved servers data: $serversJson"); // لاگ جدید

      if (serversJson != null && serversJson.isNotEmpty) {
        final List<dynamic> serversList = json.decode(serversJson);
        print("Decoded servers list length: ${serversList.length}"); // لاگ جدید

        final List<V2RayServer> loadedServers =
            serversList
                .map(
                  (item) => V2RayServer.fromJson(item as Map<String, dynamic>),
                )
                .toList();

        print("Converted servers length: ${loadedServers.length}"); // لاگ جدید

        setState(() {
          servers = loadedServers;
        });

        print("Final servers state length: ${servers.length}"); // لاگ جدید
      } else {
        print("No saved servers found"); // لاگ جدید
      }
    } catch (e) {
      print("Error in _loadSavedServers: $e"); // لاگ جدید
      _showSnackBar('Error loading saved servers: $e');
    }
  }

  Future<void> _loadLastSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastServer = prefs.getString('last_selected_server');
    if (lastServer != null && lastServer.isNotEmpty) {
      setState(() {
        currentServer = lastServer;
      });
    }
  }

  Future<void> _loadSavedSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionUrl = prefs.getString('subscription_url') ?? '';
    if (subscriptionUrl.isNotEmpty) {
      _subscriptionController.text = subscriptionUrl;
      await _fetchServers(subscriptionUrl);
    }
  }

  Future<void> _saveSubscription(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_url', url);
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Subscription URL'),
            content: TextField(
              controller: _subscriptionController,
              decoration: const InputDecoration(
                hintText: 'Enter subscription URL',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final url = _subscriptionController.text.trim();
                  if (url.isNotEmpty) {
                    Navigator.pop(context);
                    await _saveSubscription(url);
                    await _fetchServers(url);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _fetchServers(String url) async {
    setState(() {
      isLoading = true;
    });

    try {
      print("Fetching servers from URL: $url"); // لاگ جدید
      final response = await http.get(Uri.parse(url));

      print("Response status code: ${response.statusCode}"); // لاگ جدید
      if (response.statusCode == 200) {
        final newServers = _parseSubscription(response.body);
        print("Parsed servers count: ${newServers.length}"); // لاگ جدید

        if (newServers.isNotEmpty) {
          setState(() {
            servers = newServers;
          });
          print("Saving ${newServers.length} servers"); // لاگ جدید
          await _saveServers(servers);
          _showSnackBar('Successfully loaded ${servers.length} servers');
        } else {
          print("No valid servers found in subscription"); // لاگ جدید
          _showSnackBar('No valid servers found in subscription');
        }
      } else {
        print("Failed to fetch servers: ${response.statusCode}"); // لاگ جدید
        _showSnackBar('Failed to fetch servers: ${response.statusCode}');
      }
    } catch (e) {
      print("Error in _fetchServers: $e"); // لاگ جدید
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<V2RayServer> _parseSubscription(String content) {
    try {
      print("Starting to parse subscription content"); // Debug log
      final decoded = utf8.decode(base64.decode(content));
      print("Decoded content: $decoded"); // Debug log
      
      final lines = decoded.split('\n').where((line) => line.trim().isNotEmpty);
      print("Found ${lines.length} non-empty lines"); // Debug log
      
      final List<V2RayServer> parsedServers = [];

      for (var line in lines) {
        try {
          print("Parsing line: $line"); // Debug log
          final server = V2RayServer.fromV2RayURL(line.trim());
          print("Successfully parsed server: ${server.remark}"); // Debug log
          parsedServers.add(server);
        } catch (e) {
          print('Error parsing server line: $e'); // Debug log
        }
      }

      print("Successfully parsed ${parsedServers.length} servers"); // Debug log
      return parsedServers;
    } catch (e) {
      print('Error parsing subscription: $e'); // Debug log
      _showSnackBar('Error parsing subscription');
      return [];
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveLastSelectedServer(String serverName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_server', serverName);
  }

  void _selectServer() {
    if (servers.isEmpty) {
      _showSnackBar('No servers available. Please add subscription first.');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Server',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: servers.length,
                    itemBuilder: (context, index) {
                      final server = servers[index];
                      return ListTile(
                        leading: const Icon(Icons.cloud),
                        title: Text(server.remark),
                        subtitle: Text('${server.address}:${server.port}'),
                        onTap: () async {
                          setState(() {
                            currentServer = server.remark;
                          });
                          await _saveLastSelectedServer(server.remark);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building widget. Servers count: ${servers.length}"); // لاگ جدید
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blizzard Ping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            onPressed: _showSubscriptionDialog,
          ),
          IconButton(
            icon: const Icon(Icons.cloud),
            onPressed: servers.isEmpty ? null : _selectServer,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (servers.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No servers available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _showSubscriptionDialog,
                    child: const Text('Add Subscription'),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentServer,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isConnected
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                    ),
                    child: Icon(
                      isConnected ? Icons.cloud_done : Icons.cloud_off,
                      size: 80,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        icon: Icons.download,
                        title: 'Download',
                        value: '${downloadSpeed.toStringAsFixed(1)} MB/s',
                      ),
                      _buildStatCard(
                        icon: Icons.upload,
                        title: 'Upload',
                        value: '${uploadSpeed.toStringAsFixed(1)} MB/s',
                      ),
                      _buildStatCard(
                        icon: Icons.speed,
                        title: 'Ping',
                        value: '$ping ms',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton:
          currentServer != "Server not selected"
              ? FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    isConnected = !isConnected;
                    // اینجا کد اتصال واقعی اضافه شود
                  });
                },
                icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
                label: Text(isConnected ? 'Disconnect' : 'Connect'),
                backgroundColor: isConnected ? Colors.red : Colors.green,
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

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
      remark: json['remark'] as String,
      address: json['address'] as String,
      port: json['port'] as int,
      config: json['config'] as String,
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

  factory V2RayServer.fromV2RayURL(String url) {
    // اینجا لاجیک پارس کردن URL را قرار دهید
    // این یک نمونه ساده است
    final uri = Uri.parse(url);
    return V2RayServer(
      remark: uri.fragment,
      address: uri.host,
      port: uri.port,
      config: url,
    );
  }
}

Future<void> _saveServers(List<V2RayServer> serverList) async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final serversJson = json.encode(
      serverList
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

    print("Saving servers JSON: $serversJson"); // لاگ جدید
    await prefs.setString('saved_servers', serversJson);
    print("Servers saved successfully"); // لاگ جدید
  } catch (e) {
    print("Error saving servers: $e"); // لاگ جدید
  }
}


