import 'dart:convert';

import 'package:blizzardping/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/model/v2ray_status.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ServerHeader extends StatelessWidget {
  final bool isActive;
  final bool isConnected;
  final bool isDark;
  final ColorScheme colors;
  final int ping;
  final String serverName;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // Add new callback

  const _ServerHeader({
    required this.isActive,
    required this.isConnected,
    required this.isDark,
    required this.colors,
    required this.ping,
    required this.serverName,
    required this.onDelete,
    required this.onEdit, // Add new parameter
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusIcon(
          isActive: isActive,
          isConnected: isConnected,
          isDark: isDark,
          colors: colors,
        ),
       
        Expanded(
          child: _ServerInfo(
            isActive: isActive,
            isConnected: isConnected,
            isDark: isDark,
            colors: colors,
            ping: ping,
            serverName: serverName,
          ),
        ),
        _ActionButtons(
          isDark: isDark,
          onDelete: onDelete,
          onEdit: onEdit, // Pass the callback
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isActive;
  final bool isConnected;
  final bool isDark;
  final ColorScheme colors;

  const _StatusIcon({
    required this.isActive,
    required this.isConnected,
    required this.isDark,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ServerCard._iconSize,
      height: ServerCard._iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getBackgroundColor(),
        border: Border.all(color: _getBorderColor(), width: 2),
      ),
      child: AnimatedSwitcher(
        duration: ServerCard._animDuration,
        child: Icon(
          _getIcon(),
          key: ValueKey('$isActive-$isConnected'),
          color: _getIconColor(),
          size: 28,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!isActive) {
      return isDark ? Colors.grey[800]!.withOpacity(0.3) : Colors.grey[100]!;
    }
    return isConnected
        ? colors.primary.withOpacity(0.15)
        : Colors.orange.withOpacity(0.15);
  }

  Color _getBorderColor() {
    if (!isActive) return Colors.transparent;
    return isConnected
        ? colors.primary.withOpacity(0.3)
        : Colors.orange.withOpacity(0.3);
  }

  IconData _getIcon() {
    if (!isActive) return Icons.cloud_outlined;
    return isConnected ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded;
  }

  Color _getIconColor() {
    if (!isActive) {
      return isDark ? Colors.grey[400]! : Colors.grey[600]!;
    }
    return isConnected ? colors.primary : Colors.orange;
  }
}

class _ServerInfo extends StatelessWidget {
  final bool isActive;
  final bool isConnected;
  final bool isDark;
  final ColorScheme colors;
  final String serverName;

  const _ServerInfo({
    required this.isActive,
    required this.isConnected,
    required this.isDark,
    required this.colors,
    required this.serverName,
    required int ping,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      serverName,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color:
            isActive
                ? colors.primary
                : Theme.of(context).textTheme.titleMedium?.color,
      ),
    );
  }
}

// ignore: unused_element
class _ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final bool isDark;

  const _ConnectionStatus({required this.isConnected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 14, color: _getStatusColor()),
          const SizedBox(width: 4),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    return isConnected ? Colors.green : Colors.orange;
  }

  IconData _getStatusIcon() {
    return isConnected ? Icons.check_circle_outline : Icons.pending_outlined;
  }

  String _getStatusText() {
    return isConnected ? 'Connected' : 'Selected';
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // Add new callback

  const _ActionButtons({
    required this.isDark,
    required this.onDelete,
    required this.onEdit, // Add new parameter
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 20, color: buttonColor),
          onPressed: onEdit,
          tooltip: 'Edit Configuration',
        ),
        IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: buttonColor,
          ),
          onPressed: onDelete,
          tooltip: 'Delete Server',
        ),
      ],
    );
  }
}

class _ServerStats extends StatelessWidget {
  final bool isDark;
  final V2RayStatus status;
  final int ping;

  const _ServerStats({
    required this.isDark,
    required this.status,
    required this.ping,
  });

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          icon: Icons.arrow_downward_rounded,
          label: 'Download',
          value: _formatSpeed(status.downloadSpeed),
          color: Colors.green,
        ),
        _buildStatItem(
          icon: Icons.arrow_upward_rounded,
          label: 'Upload',
          value: _formatSpeed(status.uploadSpeed),
          color: Colors.blue,
        ),
        _buildStatItem(
          icon: Icons.speed_rounded,
          label: 'Latency',
          value: ping > 0 ? '$ping ms' : '-',
          color: _getPingColor(ping),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getPingColor(int ping) {
    if (ping == 0) return Colors.grey;
    if (ping < 700) return Colors.green;
    if (ping < 1000) return Colors.orange;
    return Colors.red;
  }
}

class SubscriptionManager extends StatefulWidget {
  final String currentSubscriptionUrl;
  final Function(String) onSubscriptionSelected;
  final Function(List<Subscription>)? onSubscriptionsChanged;
  final Subscription? newSubscription;
  final bool autoAdd; // اضافه کردن پارامتر جدید

  const SubscriptionManager({
    Key? key,
    required this.currentSubscriptionUrl,
    required this.onSubscriptionSelected,
    this.onSubscriptionsChanged,
    this.newSubscription,
    this.autoAdd = false, // مقدار پیش‌فرض false
  }) : super(key: key);

  @override
  State<SubscriptionManager> createState() => _SubscriptionManagerState();
}

class _SubscriptionManagerState extends State<SubscriptionManager> {
  List<Subscription> _subscriptions = [];
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
    
    // اگر سابسکریپشن جدید وجود داشت و autoAdd فعال بود
    if (widget.newSubscription != null && widget.autoAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveSubscription(
          widget.newSubscription!.name,
          widget.newSubscription!.url,
        );
      });
    }
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString('subscriptions') ?? '[]';
    print('Loaded JSON: $subscriptionsJson'); // برای دیباگ
    
    try {
      final List<dynamic> subscriptionsList = json.decode(subscriptionsJson);
      setState(() {
        _subscriptions = subscriptionsList
            .map((item) => Subscription.fromJson(item))
            .toList();
      });
      
      print('Loaded ${_subscriptions.length} subscriptions'); // برای دیباگ
      for (var sub in _subscriptions) {
        print('Subscription: ${sub.name} - ${sub.url}'); // برای دیباگ
      }
    } catch (e) {
      print('Error loading subscriptions: $e'); // برای دیباگ
    }
  }

  Future<void> _saveSubscription(String name, String url) async {
    if (name.isEmpty || url.isEmpty) return;

    // چک کردن تکراری نبودن URL
    if (_subscriptions.any((sub) => sub.url == url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This subscription URL already exists'),
        ),
      );
      return;
    }

    final newSubscription = Subscription(name: name, url: url);
    
    setState(() {
      _subscriptions.add(newSubscription);
    });

    await _saveSubscriptions();
    widget.onSubscriptionSelected(url);
    widget.onSubscriptionsChanged?.call(_subscriptions);
  }

  Future<void> _deleteSubscription(int index) async {
    setState(() {
      _subscriptions.removeAt(index);
    });

    await _saveSubscriptions();
    widget.onSubscriptionsChanged?.call(_subscriptions);
  }

  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = json.encode(
      _subscriptions.map((sub) => sub.toJson()).toList()
    );
    await prefs.setString('subscriptions', subscriptionsJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Manage your subscription sources here',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Subscriptions List
          Expanded(
            child: _subscriptions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _subscriptions.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final subscription = _subscriptions[index];
                      final isSelected = subscription.url == widget.currentSubscriptionUrl;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.rss_feed,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(subscription.name),
                          subtitle: Text(
                            subscription.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSubscription(index),
                          ),
                          selected: isSelected,
                          onTap: () {
                            widget.onSubscriptionSelected(subscription.url);
                            Navigator.pop(context, true);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    _nameController.clear();
    _urlController.clear();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter subscription name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'Enter subscription URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveSubscription(
                _nameController.text.trim(),
                _urlController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rss_feed,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Subscriptions Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first subscription to get started',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Subscription'),
          ),
        ],
      ),
    );
  }
}

class LogViewer extends StatelessWidget {
  final List<String> logs;

  const LogViewer({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final String allLogs = logs.join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final String allLogs = logs.join('\n');
              Share.share(allLogs, subject: 'V2Ray Application Logs');
            },
          ),
        ],
      ),
      body:
          logs.isEmpty
              ? const Center(child: Text('No logs available'))
              : ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class ServerCard extends StatelessWidget {
  static const double _cardRadius = 20;
  static const double _iconSize = 52;
  static const Duration _animDuration = Duration(milliseconds: 300);

  final V2RayServer server;
  final String currentServer;
  final ValueNotifier<V2RayStatus> v2rayStatus;
  final Map<String, int> pingResults;
  final Map<String, bool> isPingLoading; // Added isPingLoading parameter
  final bool isLoading;
  final Function(V2RayServer) onSelect;
  final VoidCallback onDelete;
  final Future<void> Function(V2RayServer)?
  onConnect; // Add onConnect parameter
  final VoidCallback onEdit; // Add new callback

  const ServerCard({
    super.key,
    required this.server,
    required this.currentServer,
    required this.pingResults,
    required this.isPingLoading, // Added isPingLoading parameter
    required this.isLoading,
    required this.onSelect,
    required this.onDelete,
    required this.v2rayStatus,
    this.onConnect, // Initialize onConnect
    required this.onEdit, // Add new parameter
  });

  bool get _isActive => server.remark == currentServer;
  bool get _isConnected => v2rayStatus.value.state == 'CONNECTED';
  int get _ping => pingResults[server.remark] ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedScale(
        scale: isLoading ? 0.98 : 1.0,
        duration: _animDuration,
        child: _ServerCardContent(
          isActive: _isActive,
          isConnected: _isConnected,
          isDark: isDark,
          colors: colors,
          ping: _ping,
          onTap: isLoading ? null : () => onSelect(server),
          serverName: server.remark,
          onDelete: onDelete,
          onEdit: onEdit, // Pass the callback
          child: _buildMainContent(isDark, colors),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark, ColorScheme colors) {
    return Column(
      children: [
        _ServerHeader(
          isActive: _isActive,
          isConnected: _isConnected,
          isDark: isDark,
          colors: colors,
          ping: _ping,
          serverName: server.remark,
          onDelete: onDelete,
          onEdit: onEdit, // Pass the callback
        ),
        if (_isActive) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<V2RayStatus>(
            valueListenable: v2rayStatus,
            builder: (context, status, _) {
              return _ServerStats(isDark: isDark, status: status, ping: _ping);
            },
          ),
        ],
      ],
    );
  }
}

class _ServerCardContent extends StatelessWidget {
  final bool isActive;
  final bool isConnected;
  final bool isDark;
  final ColorScheme colors;
  final int ping;
  final VoidCallback? onTap;
  final String serverName;
  final VoidCallback onDelete;
  final Widget child;

  const _ServerCardContent({
    required this.isActive,
    required this.isConnected,
    required this.isDark,
    required this.colors,
    required this.ping,
    required this.onTap,
    required this.serverName,
    required this.onDelete,
    required this.child,
    required VoidCallback onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ServerCard._cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(ServerCard._cardRadius),
            border: Border.all(color: _getBorderColor(), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _getShadowColor(),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (isActive) {
      return isDark
          ? colors.primary.withOpacity(0.15)
          : colors.primary.withOpacity(0.08);
    }
    return isDark ? Colors.grey[900]!.withOpacity(0.3) : Colors.white;
  }

  Color _getBorderColor() {
    return isActive
        ? colors.primary.withOpacity(isDark ? 0.5 : 0.3)
        : Colors.grey.withOpacity(0.1);
  }

  Color _getShadowColor() {
    return isActive
        ? colors.primary.withOpacity(0.1)
        : Colors.black.withOpacity(0.03);
  }
}








