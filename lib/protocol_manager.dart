import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProtocolManager extends StatefulWidget {
  const ProtocolManager({Key? key}) : super(key: key);

  @override
  State<ProtocolManager> createState() => _ProtocolManagerState();
}

class _ProtocolManagerState extends State<ProtocolManager> {
  bool _supportVmess = true;
  bool _supportVless = true;
  bool _supportShadowsocks = true;
  bool _enableIPv6 = false;
  bool _enableHttpUpgrade = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supportVmess = prefs.getBool('support_vmess') ?? true;
      _supportVless = prefs.getBool('support_vless') ?? true;
      _supportShadowsocks = prefs.getBool('support_shadowsocks') ?? true;
      _enableIPv6 = prefs.getBool('enable_ipv6') ?? false;
      _enableHttpUpgrade = prefs.getBool('enable_httpupgrade') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('support_vmess', _supportVmess);
    await prefs.setBool('support_vless', _supportVless);
    await prefs.setBool('support_shadowsocks', _supportShadowsocks);
    await prefs.setBool('enable_ipv6', _enableIPv6);
    await prefs.setBool('enable_httpupgrade', _enableHttpUpgrade);
  }

  Widget _buildSettingsSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protocol Settings'),
      ),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Supported Protocols',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _buildSettingsSwitch(
                  icon: Icons.security,
                  title: 'VMess',
                  subtitle: 'Support VMess protocol',
                  value: _supportVmess,
                  onChanged: (value) {
                    setState(() {
                      _supportVmess = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSettingsSwitch(
                  icon: Icons.security,
                  title: 'VLESS',
                  subtitle: 'Support VLESS protocol',
                  value: _supportVless,
                  onChanged: (value) {
                    setState(() {
                      _supportVless = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSettingsSwitch(
                  icon: Icons.security,
                  title: 'Shadowsocks',
                  subtitle: 'Support Shadowsocks protocol',
                  value: _supportShadowsocks,
                  onChanged: (value) {
                    setState(() {
                      _supportShadowsocks = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Connection Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _buildSettingsSwitch(
                  icon: Icons.network_wifi,
                  title: 'IPv6',
                  subtitle: 'Enable IPv6 support',
                  value: _enableIPv6,
                  onChanged: (value) {
                    setState(() {
                      _enableIPv6 = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSettingsSwitch(
                  icon: Icons.upgrade,
                  title: 'HTTP Upgrade',
                  subtitle: 'Enable HTTP Upgrade support',
                  value: _enableHttpUpgrade,
                  onChanged: (value) {
                    setState(() {
                      _enableHttpUpgrade = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




