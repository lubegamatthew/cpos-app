import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  /// GitHub repo: lubegamatthew/cpos-app
  static const String _downloadUrl =
      'https://github.com/lubegamatthew/cpos-app/releases/download/v1.0.0/possapp-v1.apk';

  static String? _currentVersion;

  /// Returns the cached version string, or null if it hasn't been fetched yet.
  static String? get currentVersion => _currentVersion;

  /// Returns the current app version, caching it.
  static Future<String> getCurrentVersionAsync() async {
    if (_currentVersion != null) return _currentVersion!;
    try {
      final pkg = await PackageInfo.fromPlatform();
      _currentVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      _currentVersion = '1.0.0+1'; // matches pubspec.yaml
    }
    return _currentVersion!;
  }

  /// Fetches the latest GitHub release for the CPOS app.
  static Future<Map<String, dynamic>?> _fetchLatestRelease() async {
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
      debugPrint('Failed to check for app updates: $e');
    }
    return null;
  }

  /// Converts a version string like "1.2.3" to an integer for easy comparison.
  static int _versionToInt(String version) {
    final parts = version.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final numbers = parts.map((p) => int.tryParse(p) ?? 0).toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers[0] * 10000 + numbers[1] * 100 + numbers[2];
  }

  /// Opens the APK download URL in the device's browser.
  static Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(_downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Shows the update dialog and returns true when an update is available.
  static Future<bool> checkForUpdate({BuildContext? context}) async {
    try {
      final raw = await getCurrentVersionAsync();
      final currentVersionParts = raw.split('+').first;
      final current = _versionToInt(currentVersionParts);

      final release = await _fetchLatestRelease();
      if (release == null) return false;

      final latestRaw = release['tag_name'] as String?;
      if (latestRaw == null) return false;
      final latest = _versionToInt(latestRaw);

      if (latest > current) {
        final notes = (release['body'] as String?) ?? '';
        if (context != null && context.mounted) {
          await _showUpdateDialog(context, latestRaw, notes);
        }
        return true;
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return false;
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String? releaseNotes,
  ) {
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
              if (releaseNotes != null && releaseNotes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseNotes,
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
              await _launchUpdateUrl();
            },
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
