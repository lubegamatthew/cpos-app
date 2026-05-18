import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../services/in_app_update_service.dart';
import '../services/sync_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '—';
  bool _checkingVersion = false;
  bool _updateAvailable = false;
  String? _latestVersion;
  bool _downloading = false;
  double _downloadProgress = 0;
  String _statusText = '';
  bool _syncing = false;
  String _syncMessage = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadLatestVersion();
  }

  Future<void> _loadVersion() async {
    await AppUpdateService.getCurrentVersionAsync();
    if (!mounted) return;
    setState(() => _version = AppUpdateService.getVersionName());
  }

  Future<void> _loadLatestVersion() async {
    try {
      final result = await AppUpdateService.checkForUpdateSimple();
      if (!mounted) return;
      setState(() {
        _latestVersion   = (result['latestVersion'] as String?) ?? 'Unknown';
        _updateAvailable = result['available'] as bool? ?? false;
      });
    } catch (e) {
      debugPrint('Failed to load latest version: $e');
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingVersion = true;
      _downloadProgress = 0;
      _statusText = '';
    });

    final result = await AppUpdateService.checkForUpdateSimple();
    final available = result['available'] as bool? ?? false;

    if (!mounted) return;
    setState(() => _checkingVersion = false);

    if (!available) {
      _showSnack('You\'re already on the latest version.');
      setState(() => _updateAvailable = false);
      return;
    }

    final latest       = (result['latestVersion'] as String?) ?? '';
    final releaseNotes = (result['releaseNotes'] as String?) ?? '';

    setState(() {
      _updateAvailable = true;
      _latestVersion   = latest;
    });

    if (mounted) {
      await _showUpdateDialog(latest, releaseNotes);
    }
  }

  Future<void> _performUpdate() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _statusText = 'Downloading update…';
    });

    final result = await AppUpdateService.checkForUpdateSimple();
    final releaseMap = result['_release'] as Map<String, dynamic>;

    try {
      await InAppUpdateService.downloadAndInstall(
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
        release: releaseMap,
      );
      if (mounted) {
        setState(() => _statusText = 'Installation starting…');
      }
    } on InAppUpdateFailed catch (e) {
      if (mounted) {
        debugPrint('Update failed: ${e.message}');
        if (e.message.contains('Installer could not open')) {
          _showSnack(e.message);
        } else {
          _showCloseDialog('Update Failed', e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Update error: $e');
        _showCloseDialog('Update Failed', e.toString());
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _showUpdateDialog(
    String latestVersion,
    String? notes,
  ) async {
    if (!mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
                  'Update now to get the latest features and bug fixes.'),
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
                    child: Text(notes, style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _dismissUpdateDialog(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (mounted) Navigator.of(dialogContext).pop();
              _performUpdate();
            },
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _dismissUpdateDialog() {
    if (mounted) {
      Navigator.maybePop(context).ignore();
    }
  }

  void _showCloseDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
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

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing    = true;
      _syncMessage = 'Starting sync…';
    });

    try {
      final changed = await SyncService.sync(
        onStatus: (text) {
          if (mounted) setState(() => _syncMessage = text);
        },
      );
      if (mounted) {
        setState(() => _syncMessage = changed
            ? 'Sync complete — remote changes applied.'
            : 'Sync complete — everything is already up to date.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncMessage = 'Sync failed: $e');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool downloading = _downloading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── App Info card ───────────────────────────────────────────
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
                              color:
                                  Theme.of(context).colorScheme.primaryContainer,
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
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Point of Sale System',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
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
                      _buildInfoRow(
                        'Latest Release',
                        _latestVersion ?? 'Unknown',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Update card ──────────────────────────────────────────────
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
                              _updateAvailable
                                  ? 'Update Available'
                                  : 'Up to Date',
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
                            ? _statusText.isNotEmpty
                                ? _statusText
                                : 'A newer version ($_latestVersion) is ready. '
                                    'Tap Update Now to install the latest version.'
                            : 'You are running the latest version ($_version).',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _updateAvailable
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withValues(alpha: 0.85)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _checkingVersion
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : downloading
                                ? Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6, left: 4,
                                          ),
                                          child: Text(
                                            'Downloading… '
                                            '${(_downloadProgress * 100).toStringAsFixed(0)} %',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: _downloadProgress,
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  )
                                : FilledButton.icon(
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
                                  ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Sync card ──────────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _syncing
                                ? Icons.sync
                                : Icons.cloud_sync_outlined,
                            color: _syncing
                                ? Theme.of(context).colorScheme.primary
                                : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sync Data',
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
                        _syncMessage.isNotEmpty
                            ? _syncMessage
                            : 'Push local changes to the server and pull '
                                'remote records that are missing locally.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _syncing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Syncing…'),
                                ],
                              )
                            : FilledButton.icon(
                                onPressed: _sync,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync Now'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Misc settings ────────────────────────────────────────────
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

/// Thrown when the download or install fails so callers can show a friendly dialog.
class InAppUpdateFailed implements Exception {
  InAppUpdateFailed(this.message);
  final String message;
}
