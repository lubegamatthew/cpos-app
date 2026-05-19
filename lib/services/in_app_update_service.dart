import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart' show getExternalStorageDirectory;
import '../services/app_update_service.dart';

/// In-app update service:
/// 1. Resolves the APK URL from the GitHub release JSON
/// 2. Stores the APK directly in the permanent download file (no temp file)
/// 3. Streams the APK download with byte-level progress
/// 4. Launches the system APK installer
class InAppUpdateService {
  /// Downloads the APK to the Downloads folder and launches the installer.
  ///
  /// [release] — the GitHub release JSON map from the API call.
  /// [onProgress] fires with `(bytesReceivedSoFar, totalBytes)` on each chunk.
  static Future<bool> downloadAndInstall({
    required void Function(int received, int total) onProgress,
    required Map<String, dynamic> release,
  }) async {
    // ── Resolve URL from live release JSON ──────────────────────────────
    final String apkUrl = AppUpdateService.resolveApkUrl(release);
    debugPrint('[InAppUpdate] APK URL: $apkUrl');

    // ── 1. Storage permission ───────────────────────────────────────────
    debugPrint('[InAppUpdate] Using app-managed download directory.');

    // ── 2. File path ────────────────────────────────────────────────────
    // Use the app-managed public Downloads folder so we don't need any
    // runtime storage permissions.
    final externalDir = await getExternalStorageDirectory();
    final downloadsDir = externalDir != null
        ? Directory('${externalDir.path}/Download')
        : Directory('/storage/emulated/0/Download');
    await downloadsDir.create(recursive: true);

    const finalFileName = 'cpos-update.apk';
    final downloadFile = File('${downloadsDir.path}/$finalFileName');

    // ── 3. Always re-download when the user taps "Update Now" ───────────
    // An existing file on disk may be from a previous incomplete download or
    // a stale older release — print the old size so the log makes the
    // overwrite obvious, then fall through to the fresh download below.
    if (await downloadFile.exists()) {
      final size = await downloadFile.length();
      debugPrint('[InAppUpdate] Replacing existing APK ($size bytes) with fresh download…');
    }

    // ── 4. Stream download with progress ────────────────────────────────
    var bytesReceived = 0;
    try {
      debugPrint('[InAppUpdate] Connecting to $apkUrl ...');
      final response = await http.get(Uri.parse(apkUrl), headers: {
        'Accept': 'application/vnd.android.package-archive',
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw InAppUpdateFailed(
          'HTTP ${response.statusCode} — server rejected the download.',
        );
      }

      final fileTotal = response.contentLength;
      debugPrint(
        '[InAppUpdate] Connected. status=${response.statusCode} '
        'size=${fileTotal ?? 'unknown'}',
      );

      // Write directly to the final file — if the download fails midway
      // the file is simply overwritten on the next attempt rather than
      // leaving a stale .tmp orphan.
      debugPrint('[InAppUpdate] Writing → ${downloadFile.path}');
      bytesReceived = await downloadFile.writeAsBytes(
        response.bodyBytes,
        flush: true,
      ).then((f) => f.lengthSync());
      debugPrint(
        '[InAppUpdate] Download complete. received=$bytesReceived bytes',
      );
    } on TimeoutException catch (e) {
      debugPrint('[InAppUpdate] Timeout: $e');
      throw InAppUpdateFailed('Download timed out. '
          'Check your internet connection and try again.');
    } on SocketException catch (e) {
      debugPrint('[InAppUpdate] SocketException: $e');
      throw InAppUpdateFailed('Network error ($e).');
    } on FileSystemException catch (e) {
      debugPrint('[InAppUpdate] FileSystemException: $e');
      throw InAppUpdateFailed('Cannot save APK ($e). '
          'Free up storage and try again.');
    } catch (e) {
      debugPrint('[InAppUpdate] Error: $e (${e.runtimeType})');
      throw InAppUpdateFailed('Download failed: $e');
    }

    // ── 5. Validate downloaded file ────────────────────────────────────
    final finalSize = await downloadFile.length();
    debugPrint(
      '[InAppUpdate] Saved: ${downloadFile.path} ($finalSize bytes)',
    );

    if (finalSize == 0) {
      throw InAppUpdateFailed(
        'Downloaded file is empty. Check your internet and try again.',
      );
    }

    // ── 6. Launch APK installer ─────────────────────────────────────────
    debugPrint('[InAppUpdate] Launching installer...');
    return _launchInstaller(downloadFile.path);
  }

  /// Opens the APK file so Android launches the package installer.
  static Future<bool> _launchInstaller(String apkPath) async {
    debugPrint('[InAppUpdate] _launchInstaller: $apkPath');

    // Try with APK MIME type first
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('[InAppUpdate] OpenFilex [MIME] → type=${result.type}  msg=${result.message}');

    if (result.type == ResultType.done) return true;

    // Plain open — no explicit type
    final plain = await OpenFilex.open(apkPath);
    debugPrint('[InAppUpdate] OpenFilex [plain] → type=${plain.type}  msg=${plain.message}');

    if (plain.type == ResultType.done) return true;

    throw InAppUpdateFailed(
      'Installer did not open. The APK is saved at:\n$apkPath\n'
      'Error: ${plain.message}',
    );
  }
}

/// Thrown by [InAppUpdateService] when download or install fails.
/// The [message] always includes a user-friendly explanation.
class InAppUpdateFailed implements Exception {
  InAppUpdateFailed(this.message);
  final String message;

  @override
  String toString() => 'InAppUpdateFailed: $message';
}
