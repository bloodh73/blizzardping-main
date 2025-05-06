import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final bool initialProxyOnly;
  final bool initialEnableIPv6;
  final bool initialEnableMux;
  final bool initialEnableHttpUpgrade;
  final String initialDefaultSubscriptionUrl;

  const SettingsScreen({
    Key? key,
    required this.initialProxyOnly,
    required this.initialEnableIPv6,
    required this.initialEnableMux,
    required this.initialEnableHttpUpgrade,
    required this.initialDefaultSubscriptionUrl,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _proxyOnly;
  late bool _enableIPv6;
  late bool _enableMux;
  late bool _enableHttpUpgrade;
  late TextEditingController _defaultSubController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _proxyOnly = widget.initialProxyOnly;
    _enableIPv6 = widget.initialEnableIPv6;
    _enableMux = widget.initialEnableMux;
    _enableHttpUpgrade = widget.initialEnableHttpUpgrade;
    _defaultSubController = TextEditingController(
      text: widget.initialDefaultSubscriptionUrl,
    );
  }

  @override
  void dispose() {
    _defaultSubController.dispose();
    super.dispose();
  }

  void _checkChanges() {
    setState(() {
      _hasChanges = _proxyOnly != widget.initialProxyOnly ||
          _enableIPv6 != widget.initialEnableIPv6 ||
          _enableMux != widget.initialEnableMux ||
          _enableHttpUpgrade != widget.initialEnableHttpUpgrade ||
          _defaultSubController.text != widget.initialDefaultSubscriptionUrl;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('proxy_only', _proxyOnly);
    await prefs.setBool('enable_ipv6', _enableIPv6);
    await prefs.setBool('enable_mux', _enableMux);
    await prefs.setBool('enable_http_upgrade', _enableHttpUpgrade);
    await prefs.setString('default_subscription_url', _defaultSubController.text.trim());

    // Return the updated settings to the previous screen
    if (mounted) {
      Navigator.pop(context, {
        'proxyOnly': _proxyOnly,
        'enableIPv6': _enableIPv6,
        'enableMux': _enableMux,
        'enableHttpUpgrade': _enableHttpUpgrade,
        'defaultSubscriptionUrl': _defaultSubController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Settings',
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: ListView(
        children: [
          // Connection Settings Card
          _buildSettingsCard(
            title: 'Connection Settings',
            icon: Icons.router_rounded,
            children: [
              _buildSwitchTile(
                title: 'Proxy Only',
                subtitle: 'Only redirect proxy traffic',
                value: _proxyOnly,
                onChanged: (value) {
                  setState(() {
                    _proxyOnly = value;
                  });
                  _checkChanges();
                },
                icon: Icons.alt_route_rounded,
              ),
              _buildSwitchTile(
                title: 'Enable IPv6',
                subtitle: 'Support IPv6 connections',
                value: _enableIPv6,
                onChanged: (value) {
                  setState(() {
                    _enableIPv6 = value;
                  });
                  _checkChanges();
                },
                icon: Icons.language_rounded,
              ),
            ],
          ),
          
          // Performance Settings Card
          _buildSettingsCard(
            title: 'Performance Settings',
            icon: Icons.speed_rounded,
            children: [
              _buildSwitchTile(
                title: 'Enable Mux',
                subtitle: 'Multiplex connections for better performance',
                value: _enableMux,
                onChanged: (value) {
                  setState(() {
                    _enableMux = value;
                  });
                  _checkChanges();
                },
                icon: Icons.merge_type_rounded,
              ),
              _buildSwitchTile(
                title: 'Enable HTTP Upgrade',
                subtitle: 'Use HTTP Upgrade for better connectivity',
                value: _enableHttpUpgrade,
                onChanged: (value) {
                  setState(() {
                    _enableHttpUpgrade = value;
                  });
                  _checkChanges();
                },
                icon: Icons.upgrade_rounded,
              ),
            ],
          ),
          
          // Subscription Settings Card
          _buildSettingsCard(
            title: 'Subscription Settings',
            icon: Icons.cloud_download_rounded,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Default Subscription URL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _defaultSubController,
                      decoration: InputDecoration(
                        hintText: 'Enter default subscription URL',
                        filled: true,
                        fillColor: isDark 
                            ? colors.surfaceVariant.withOpacity(0.3) 
                            : colors.surfaceVariant.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _defaultSubController.clear();
                            _checkChanges();
                          },
                        ),
                      ),
                      onChanged: (_) => _checkChanges(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // About Section
          _buildSettingsCard(
            title: 'About',
            icon: Icons.info_outline_rounded,
            children: [
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
                trailing: TextButton(
                  onPressed: () {
                    // Check for updates logic
                  },
                  child: const Text('Check for Updates'),
                ),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.shield_rounded),
                title: Text('Privacy Policy'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
              const ListTile(
                leading: Icon(Icons.description_rounded),
                title: Text('Terms of Service'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _hasChanges
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: colors.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      secondary: Icon(
        icon,
        color: value ? colors.primary : colors.onSurfaceVariant,
        size: 22,
      ),
      activeColor: colors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}