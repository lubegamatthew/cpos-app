import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  /// GitHub repo owner and name — update if you rename/fork.
  static const String _repoOwner = 'lubegamatthew';
  static const String _repoName  = 'cpos-app';

  /// Guard URL — keep in sync with each release.
  static const String _fallbackUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/download/v1.0.4/app-release.apk';

  static String? _currentVersion;

  /// Returns the cached version string, or null if it hasn't been fetched yet.
  static String? get currentVersion => _currentVersion;

  // ── Android MethodChannel ────────────────────────────────────────
  static const MethodChannel _channel = MethodChannel(
    'com.example.cpos/version',
  );

  /// Android side of the version channel (reads `versionName`/`versionCode`
  /// from the running APK's `PackageInfo` — no plugin required).
  static Future<_VersionInfo?> _getVersionFromAndroid() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getVersionInfo',
      );
      if (data == null) return null;
      return _VersionInfo(
        versionName: (data['versionName'] as String?) ?? '',
        versionCode: (data['versionCode'] as int?) ?? 0,
      );
    } on MissingPluginException catch (e) {
      debugPrint('[Version] channel not registered: $e');
    } on PlatformException catch (e) {
      debugPrint('[Version] PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[Version] channel error: $e');
    }
    return null;
  }

  /// Reads `version:` from the pubspec bundled in the APK.
  static Future<String?> _getVersionFromPubspec() async {
    try {
      final raw = await rootBundle.loadString('pubspec.yaml');
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.startsWith('version:')) {
          return t.substring('version:'.length).trim();
        }
      }
    } catch (e) {
      debugPrint('[Version] pubspec.yaml: $e');
    }
    return null;
  }

  /// Returns "x.y.z+build" for the currently running APK.
  ///
  /// Try order:
  ///   1. `PackageInfo.fromPlatform()`  — standard plugin
  ///   2. Android MethodChannel                   — 0-plugin, always reads the APK manifest
  ///   3. `pubspec.yaml` in asset bundle          — not listed in assets but present after `flutter pub get`
  ///   4. Safety-net string — update when you cut a release
  static Future<String> getCurrentVersionAsync() async {
    if (_currentVersion != null) return _currentVersion!;
    _currentVersion = await _resolveVersion();
    return _currentVersion!;
  }

  static Future<String> _resolveVersion() async {
    // ── 1. PackageInfo plugin ──────────────────────────────────────
    try {
      final pkg = await PackageInfo.fromPlatform().timeout(
        const Duration(milliseconds: 500),
      );
      final v = pkg.version.trim();
      final b = pkg.buildNumber.trim();
      if (v.isNotEmpty && v != '0.0.0' && v != '0.0') {
        debugPrint('[Version] PackageInfo: $v+$b');
        return '$v+$b';
      }
    } catch (e) {
      debugPrint('[Version] PackageInfo failed: $e');
    }

    // ── 2. Android MethodChannel ───────────────────────────────────
    final android = await _getVersionFromAndroid();
    if (android != null && android.versionName.isNotEmpty) {
      final vt = _versionToInt(android.versionName);
      if (vt > 0) {
        debugPrint(
          '[Version] Android channel: '
          '${android.versionName}+${android.versionCode}',
        );
        return '${android.versionName}+${android.versionCode}';
      }
    }

    // ── 3. pubspec.yaml from asset bundle ──────────────────────────
    final pubspecStr = await _getVersionFromPubspec();
    if (pubspecStr != null) {
      final parts = pubspecStr.split('+');
      final vt = _versionToInt(parts.isNotEmpty ? parts[0] : pubspecStr);
      if (vt > 0) {
        final vn = parts.isNotEmpty ? parts[0] : pubspecStr;
        final bn = parts.length > 1 ? parts[1] : '0';
        debugPrint('[Version] pubspec.yaml: $vn+$bn');
        return '$vn+$bn';
      }
    }

    // ── 4. Ultimate safety net ─────────────────────────────────────
    debugPrint('[Version] all strategies failed, returning safety-net value');
    return _safetyNetVersion();
  }

  /// Build-time safety net.
  ///
  /// **Never leave this stale.**  When you cut a release, bump BOTH
  /// `pubspec.yaml` version:and this field.
  static String _safetyNetVersion() => '1.0.0+0';

  static int _versionToInt(String version) {
    final parts = version.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final numbers = parts.map((p) => int.tryParse(p) ?? 0).toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers[0] * 10000 + numbers[1] * 100 + numbers[2];
  }

  // ── Network / release helpers ───────────────────────────────────

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

  static Future<void> _launchUpdateUrl({String? url}) async {
    final uri = Uri.parse(url ?? _fallbackUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<bool> checkForUpdate({BuildContext? context}) async {
    try {
      final raw         = await getCurrentVersionAsync();
      final currentInt  = _versionToInt(raw.split('+').first);

      final release = await _fetchLatestRelease();
      if (release == null) return false;

      final latestRaw = release['tag_name'] as String?;
      if (latestRaw == null) return false;
      final latestInt = _versionToInt(latestRaw);

      if (latestInt > currentInt) {
        final notes = (release['body'] as String?) ?? '';
        final apkUrl = resolveApkUrl(release);
        if (context != null && context.mounted) {
          await _showUpdateDialog(context, latestRaw, notes, apkUrl: apkUrl);
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

/// Holds version name + version code from `PackageInfo` / the Android channel.
class _VersionInfo {
  _VersionInfo({required this.versionName, required this.versionCode});
  final String versionName;
  final int versionCode;
}
