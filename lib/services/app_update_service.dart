import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  /// GitHub repo owner and name — change here if you fork/rename.
  static const String _repoOwner = 'lubegamatthew';
  static const String _repoName  = 'cpos-app';

  /// Fallback guard URL (updated alongside each release).
  static const String _fallbackUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/download/v1.0.4/app-release.apk';

  static String? _currentVersion;

  /// Returns the cached version string, or null if it hasn't been fetched yet.
  static String? get currentVersion => _currentVersion;

  /// Returns the current app version string, caching it.
  static Future<String> getCurrentVersionAsync() async {
    if (_currentVersion != null) return _currentVersion!;
    try {
      final pkg = await PackageInfo.fromPlatform();
      _currentVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      _currentVersion = '1.0.0+1';   // matches pubspec.yaml
    }
    return _currentVersion!;
  }

  /// HTTP GET the latest GitHub release and return the decoded JSON body.
  static Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    try {
      final resp = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('AppUpdateService: fetch failed — $e');
    }
    return null;
  }

  /// Scans [release] assets for the first `.apk` file and returns its
  /// `browser_download_url`. Falls back to [_fallbackUrl] if none found.
  static String resolveApkUrl(Map<String, dynamic> release) {
    final assets = release['assets'] as List?;
    if (assets != null && assets.isNotEmpty) {
      for (final a in assets) {
        final name = (a['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk')) {
          final url = a['browser_download_url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
      // No .apk extension match — take the first asset URL
      final first = assets.first;
      final url = first['browser_download_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    return _fallbackUrl;
  }

  /// Converts a dotted version string like "1.2.3" to an integer for
  /// easy numeric comparison.  v-prefix and build metadata are stripped.
  static int _versionToInt(String version) {
    final parts = version.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final numbers = parts.map((p) => int.tryParse(p) ?? 0).toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers[0] * 10000 + numbers[1] * 100 + numbers[2];
  }

  /// Opens the APK download URL in the system browser.
  static Future<void> _launchUpdateUrl({String? url}) async {
    final uri = Uri.parse(url ?? _fallbackUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Checks whether a newer version is available on GitHub.
  /// If [context] is supplied the update dialog is shown automatically.
  /// Returns true when an update is available.
  static Future<bool> checkForUpdate({BuildContext? context}) async {
    try {
      final raw          = await getCurrentVersionAsync();
      final currentInt   = _versionToInt(raw.split('+').first);
      final apkUrlRef    = <String?>[null];   // pass resolved URL to dialog

      final release = await _fetchLatestRelease();
      if (release == null) return false;

      final latestRaw = release['tag_name'] as String?;
      if (latestRaw == null) return false;
      final latestInt = _versionToInt(latestRaw);

      if (latestInt > currentInt) {
        final notes = (release['body'] as String?) ?? '';
        apkUrlRef[0] = resolveApkUrl(release);  // resolve once, share with dialog
        if (context != null && context.mounted) {
          await _showUpdateDialog(
            context,
            latestRaw,
            notes,
            apkUrl: apkUrlRef[0],
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('AppUpdateService: check failed — $e');
    }
    return false;
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String? releaseNotes, {
    String? apkUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                'Update now to get the latest features and bug fixes.',
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _launchUpdateUrl(url: apkUrl);
            },
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
