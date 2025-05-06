import 'dart:convert';
import 'package:blizzardping/main.dart';
import 'package:flutter/material.dart';

class EditServerScreen extends StatefulWidget {
  final V2RrayServer server;
  final Function(V2RrayServer) onSave;

  const EditServerScreen({
    Key? key,
    required this.server,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditServerScreen> createState() => _EditServerScreenState();
}

class _EditServerScreenState extends State<EditServerScreen> {
  late TextEditingController remarkController;
  late TextEditingController addressController;
  late TextEditingController portController;
  late TextEditingController configController;
  bool _hasChanges = false;
  bool _isAdvancedExpanded = false;

  @override
  void initState() {
    super.initState();
    remarkController = TextEditingController(text: widget.server.remark);
    addressController = TextEditingController(text: widget.server.address);
    portController = TextEditingController(text: widget.server.port.toString());
    configController = TextEditingController(text: widget.server.config);

    // Listen for changes to detect if user has modified anything
    remarkController.addListener(_checkChanges);
    addressController.addListener(_checkChanges);
    portController.addListener(_checkChanges);
    configController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final hasChanges = remarkController.text != widget.server.remark ||
        addressController.text != widget.server.address ||
        portController.text != widget.server.port.toString() ||
        configController.text != widget.server.config;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    remarkController.dispose();
    addressController.dispose();
    portController.dispose();
    configController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    try {
      // Validate JSON config
      json.decode(configController.text);

      // Validate port
      final port = int.tryParse(portController.text);
      if (port == null || port < 1 || port > 65535) {
        _showError('Port must be between 1 and 65535');
        return;
      }

      // Validate other fields
      if (remarkController.text.trim().isEmpty) {
        _showError('Server name cannot be empty');
        return;
      }
      if (addressController.text.trim().isEmpty) {
        _showError('Server address cannot be empty');
        return;
      }

      final updatedServer = V2RrayServer(
        remark: remarkController.text.trim(),
        address: addressController.text.trim(),
        port: port,
        config: configController.text.trim(),
      );

      widget.onSave(updatedServer);
      Navigator.pop(context);
    } catch (e) {
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _formatJsonConfig() {
    try {
      final jsonObj = json.decode(configController.text);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObj);
      configController.text = prettyJson;
    } catch (e) {
      _showError('Invalid JSON format');
    }
  }

  void _showJsonEditorDialog() {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.code, color: colors.onPrimary, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Configuration',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 18,
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
                          final jsonObj = json.decode(configController.text);
                          final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObj);
                          configController.text = prettyJson;
                        } catch (e) {
                          Navigator.pop(context);
                          _showError('Invalid JSON format');
                        }
                      },
                      tooltip: 'Format JSON',
                    ),
                  ],
                ),
              ),
              
              // Editor
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextField(
                    controller: configController,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 2,
                        ),
                      ),
                      hintText: 'Enter JSON configuration',
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                    ),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
              
              // Buttons
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: colors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: colors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colors.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Server'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Server Info Card
              _buildCard(
                title: 'Server Information',
                icon: Icons.dns_rounded,
                children: [
                  _buildInputField(
                    controller: remarkController,
                    label: 'Server Name',
                    hint: 'Enter a name for this server',
                    icon: Icons.label_rounded,
                  ),
                  _buildInputField(
                    controller: addressController,
                    label: 'Server Address',
                    hint: 'Enter server hostname or IP',
                    icon: Icons.link_rounded,
                  ),
                  _buildInputField(
                    controller: portController,
                    label: 'Port',
                    hint: 'Enter port number (1-65535)',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              
              // Advanced Settings Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    // Header with expand/collapse
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isAdvancedExpanded = !_isAdvancedExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.code_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Advanced Configuration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _isAdvancedExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Expandable content
                    if (_isAdvancedExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'JSON Configuration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.format_align_left,
                                        color: colors.primary,
                                        size: 20,
                                      ),
                                      onPressed: _formatJsonConfig,
                                      tooltip: 'Format JSON',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _showJsonEditorDialog,
                                      icon: const Icon(Icons.edit_rounded, size: 18),
                                      label: const Text('Edit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        foregroundColor: colors.onPrimary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                configController.text.length > 150
                                    ? '${configController.text.substring(0, 150)}...'
                                    : configController.text,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Save Button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _hasChanges ? _saveChanges : null,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    disabledBackgroundColor: 
                        isDark ? Colors.grey[700] : Colors.grey[300],
                    disabledForegroundColor:
                        isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

