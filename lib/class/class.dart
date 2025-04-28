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
  final Function(String) onSubscriptionSelected;
  final String currentSubscriptionUrl;

  const SubscriptionManager({
    super.key,
    required this.onSubscriptionSelected,
    required this.currentSubscriptionUrl,
  });

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Info Card
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
            child:
                _subscriptions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      itemCount: _subscriptions.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final subscription = _subscriptions[index];
                        final isSelected =
                            subscription.url == widget.currentSubscriptionUrl;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.outline.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                        : Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.rss_feed,
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              subscription.name,
                              style: TextStyle(
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              subscription.url,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.8)
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Active',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed:
                                      () => _editSubscription(
                                        subscription,
                                        index,
                                      ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _showDeleteDialog(index),
                                ),
                              ],
                            ),
                            onTap: () {
                              widget.onSubscriptionSelected(subscription.url);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubscription,
        icon: const Icon(Icons.add),
        label: const Text('Add Subscription'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            onPressed: _addSubscription,
            icon: const Icon(Icons.add),
            label: const Text('Add Subscription'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                const Text('Delete Subscription'),
              ],
            ),
            content: const Text(
              'Are you sure you want to delete this subscription?',
            ),
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
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() {
                    _subscriptions.removeAt(index);
                  });
                  await _saveSubscriptions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _editSubscription(Subscription subscription, int index) {
    _nameController.text = subscription.name;
    _urlController.text = subscription.url;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Edit Subscription'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _nameController.clear();
                  _urlController.clear();
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.isNotEmpty &&
                      _urlController.text.isNotEmpty) {
                    setState(() {
                      _subscriptions[index] = Subscription(
                        name: _nameController.text,
                        url: _urlController.text,
                      );
                    });
                    await _saveSubscriptions();

                    if (widget.currentSubscriptionUrl == subscription.url) {
                      widget.onSubscriptionSelected(_urlController.text);
                    }

                    _nameController.clear();
                    _urlController.clear();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _addSubscription() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Add Subscription'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _nameController.clear();
                  _urlController.clear();
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.isNotEmpty &&
                      _urlController.text.isNotEmpty) {
                    setState(() {
                      _subscriptions.add(
                        Subscription(
                          name: _nameController.text,
                          url: _urlController.text,
                        ),
                      );
                    });
                    await _saveSubscriptions();
                    _nameController.clear();
                    _urlController.clear();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString('subscriptions') ?? '[]';
    final List<dynamic> subscriptionsList = json.decode(subscriptionsJson);
    setState(() {
      _subscriptions =
          subscriptionsList.map((item) => Subscription.fromJson(item)).toList();
    });
  }

  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = json.encode(
      _subscriptions.map((sub) => sub.toJson()).toList(),
    );
    await prefs.setString('subscriptions', subscriptionsJson);
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
