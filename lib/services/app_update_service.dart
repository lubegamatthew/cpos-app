import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  // ── Constants ─────────────────────────────────────────────────────
  static const String _repoOwner  = 'lubegamatthew';
  static const String _repoName   = 'cpos-app';
  static const String _fallbackUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/download/v1.0.4/app-release.apk';

  // ── Cached version string ──────────────────────────────────────────
  static String? _currentVersion;

  /// Returns the cached version string, or null if not yet fetched.
  static String? get currentVersion => _currentVersion;

  // ── Android MethodChannel ──────────────────────────────────────────
  static const MethodChannel _channel =
      MethodChannel('com.example.cpos/version');

  // ── Build-time safety net ──────────────────────────────────────────
  /// Updated alongside `pubspec.yaml`.  Both are in sync:
  ///   pubspec.yaml → version: 1.0.7
  ///   _buildVersionGuard → '1.0.7+0'
  static const String _buildVersionGuard = '1.0.7+0';

  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns `x.y.z+build` for the currently installed APK.
  ///
  /// Resolution order (first success wins):
  ///   1. `PackageInfo.fromPlatform()` — standard plugin path
  ///   2. Android `MethodChannel` — reads `PackageManager.getPackageInfo()`
  ///   3. `pubspec.yaml` from the asset bundle
  ///   4. `_buildVersionGuard` — compile-time safety net
  static Future<String> getCurrentVersionAsync() async {
    if (_currentVersion != null) return _currentVersion!;
    _currentVersion = await _resolveVersion();
    return _currentVersion!;
  }

  static Future<String> _resolveVersion() async {
    // ── Strategy 1: PackageInfo ─────────────────────────────────────
    try {
      final pkg = await PackageInfo.fromPlatform()
          .timeout(const Duration(milliseconds: 500));
      final v = pkg.version.trim();
      final b = pkg.buildNumber.trim();
      if (v.isNotEmpty && v != '0.0.0' && v != '0.0') {
        debugPrint('[Version] PackageInfo: $v+$b');
        return '$v+$b';
      }
    } catch (e) {
      debugPrint('[Version] PackageInfo: $e');
    }

    // ── Strategy 2: Android MethodChannel ───────────────────────────
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getVersionInfo',
      );
      if (data != null) {
        final vn = (data['versionName'] as String?) ?? '';
        if (vn.isNotEmpty) {
          final vc = (data['versionCode'] as int?) ?? 0;
          debugPrint('[Version] Android channel: $vn+$vc');
          return '$vn+$vc';
        }
      }
    } catch (e) {
      debugPrint('[Version] Android channel: $e');
    }

    // ── Strategy 3: pubspec.yaml ────────────────────────────────────
    try {
      final raw = await rootBundle.loadString('pubspec.yaml');
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.startsWith('version:')) {
          final v = t.substring('version:'.length).trim();
          if (v.isNotEmpty) {
            debugPrint('[Version] pubspec.yaml: $v');
            return v;
          }
        }
      }
    } catch (e) {
      debugPrint('[Version] pubspec.yaml: $e');
    }

    // ── Strategy 4: safety net ──────────────────────────────────────
    debugPrint('[Version] safety net: $_buildVersionGuard');
    return _buildVersionGuard;
  }

  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns only the `x.y.z` part, with `+build` and leading `v` stripped.
  /// Safe to call before or after `getCurrentVersionAsync()`.
  static String getVersionName() {
    final cached = _currentVersion;
    return (cached ?? _buildVersionGuard)
        .split('+')
        .first
        .replaceFirst(RegExp(r'^v'), '');
  }

  /// Returns true when `latest` is strictly newer than the installed version.
  static bool isOlderThan(String latest) {
    final currentPart = _currentVersion?.split('+').first ?? '';
    return _versionToInt(currentPart) < _versionToInt(latest);
  }

  /// Strips a leading `v` from a GitHub tag: `"v1.0.7"` → `"1.0.7"`.
  static String stripVTag(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  // ═══════════════════════════════════════════════════════════════════════════

  static int _versionToInt(String version) {
    final parts = version.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final numbers = parts.map((p) => int.tryParse(p) ?? 0).toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers[0] * 10000 + numbers[1] * 100 + numbers[2];
  }

  // ═══════════════════════════════════════════════════════════════════════════

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

  /// Scans [release] assets for the first `.apk` and returns its
  /// `browser_download_url`.  Falls back to [_fallbackUrl].
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
      final url = assets.first['browser_download_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    return _fallbackUrl;
  }

  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> _launchUpdateUrl({String? url}) async {
    final uri = Uri.parse(url ?? _fallbackUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks whether a newer version is available on GitHub.
  /// If [context] is given the update dialog is shown automatically.
  /// Returns true when an update is available.
  static Future<bool> checkForUpdate({BuildContext? context}) async {
    try {
      final raw        = await getCurrentVersionAsync();
      final currentInt = _versionToInt(raw.split('+').first);

      final release = await _fetchLatestRelease();
      if (release == null) return false;

      final latestRaw = release['tag_name'] as String?;
      if (latestRaw == null) return false;
      final latestInt = _versionToInt(latestRaw);

      if (latestInt > currentInt) {
        final notes   = (release['body'] as String?) ?? '';
        final apkUrl  = resolveApkUrl(release);
        if (context != null && context.mounted) {
          await _showUpdateDialog(
            context,
            stripVTag(latestRaw),
            notes,
            apkUrl: apkUrl,
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('AppUpdateService: check failed — $e');
    }
    return false;
  }

  /// Lightweight check that returns structured state instead of opening
  /// a dialog.  The full release JSON is available under `_release` so
  /// the download step can resolve the exact APK URL without a second call.
  static Future<Map<String, dynamic>> checkForUpdateSimple() async {
    try {
      final currentRaw = await getCurrentVersionAsync();
      final currentInt = _versionToInt(currentRaw.split('+').first);

      final release = await _fetchLatestRelease();
      if (release == null) return {'available': false};

      final latestRaw = (release['tag_name'] as String?) ?? '';
      final latestInt = _versionToInt(latestRaw);

      return {
        'available':     latestInt > currentInt,
        'latestTag':     latestRaw,
        'latestVersion': stripVTag(latestRaw),
        'releaseNotes':  (release['body'] as String?) ?? '',
        'apkUrl':        resolveApkUrl(release),
        '_release':      release,
      };
    } catch (e) {
      debugPrint('AppUpdateService: checkForUpdateSimple failed — $e');
      return {'available': false};
    }
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
                  'Update now to get the latest features and bug fixes.'),
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
