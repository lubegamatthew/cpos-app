import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '—';
  bool _checking = false;
  bool _updateAvailable = false;
  String? _latestVersion;

  static const String _downloadUrl =
      'https://github.com/lubegamatthew/cpos-app/releases/download/v1.0.0/possapp-v1.apk';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await AppUpdateService.getCurrentVersionAsync();
    if (mounted) setState(() => _version = v);
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checking = true);
    try {
      final currentRaw = await AppUpdateService.getCurrentVersionAsync();
      final versionToInt = _versionToInt(currentRaw.split('+').first);

      final release = await _fetchLatestRelease();
      if (release == null) {
        _showSnack('Could not reach update server. Try again later.');
        return;
      }

      final latestRaw = (release['tag_name'] as String?) ?? '';
      final latest = _versionToInt(latestRaw);

      if (latest > versionToInt) {
        final notes = (release['body'] as String?) ?? '';
        setState(() {
          _updateAvailable = true;
          _latestVersion = latestRaw;
        });
        await _showUpdateDialog(latestRaw, notes);
      } else {
        setState(() => _updateAvailable = false);
        if (mounted) _showSnack('You\'re already on the latest version.');
      }
    } catch (e) {
      _showSnack('Update check failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  int _versionToInt(String version) {
    final parts = version.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final numbers = parts.map((p) => int.tryParse(p) ?? 0).toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers[0] * 10000 + numbers[1] * 100 + numbers[2];
  }

  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    try {
      final resp = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/lubegamatthew/cpos-app/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('API error: $e');
    }
    return null;
  }

  Future<void> _showUpdateDialog(String latestVersion, String? notes) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('Update Available'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version ($latestVersion) is available. '
                'Please update to get the latest features and bug fixes.',
              ),
              const SizedBox(height: 16),
              if (notes != null && notes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.parse(_downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.point_of_sale_outlined,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CPOS',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Point of Sale System',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInfoRow('Version', _version),
                  const SizedBox(height: 8),
                  _buildInfoRow('Latest Release', _latestVersion ?? 'Unknown'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            color: _updateAvailable
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _updateAvailable
                            ? Icons.system_update
                            : Icons.check_circle,
                        color: _updateAvailable
                            ? Theme.of(context).colorScheme.primary
                            : Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _updateAvailable ? 'Update Available' : 'Up to Date',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _updateAvailable
                        ? 'A newer version ($_latestVersion) is ready. '
                            'Update now for the latest features and fixes.'
                        : 'You are running the latest version ($_version).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _updateAvailable
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.7)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _checking
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _checkForUpdate,
                            icon: Icon(
                              _updateAvailable
                                  ? Icons.download
                                  : Icons.refresh_outlined,
                            ),
                            label: Text(
                              _updateAvailable
                                  ? 'Update Now'
                                  : 'Check for Update',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _updateAvailable
                                  ? null
                                  : Colors.green,
                              foregroundColor: _updateAvailable
                                  ? null
                                  : Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.attach_money_outlined,
            title: 'Currency',
            subtitle: 'UGX',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'CPOS v$_version',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
