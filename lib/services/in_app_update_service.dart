import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart' show getExternalStorageDirectory;
import '../services/app_update_service.dart';

/// In-app update service:
/// 1. Resolves the APK URL from the GitHub release JSON
/// 2. Requests storage permission
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
    // No runtime permission needed: path_provider gives us the
    // app-managed directory where the app can always read and write.
    debugPrint('[InAppUpdate] Using app-managed download directory.');

    // ── 2. File paths ───────────────────────────────────────────────────
    // Use the app-managed public Downloads folder so we don't need any
    // runtime storage permissions.  Falls back to a compiled-in path if
    // path_provider returns null (should never happen on a real device).
    final externalDir = await getExternalStorageDirectory();
    final downloadsDir = externalDir != null
        ? Directory('${externalDir.path}/Download')
        : Directory('/storage/emulated/0/Download');
    await downloadsDir.create(recursive: true);

    const finalFileName = 'cpos-update.apk';
    const tempFileName  = 'cpos-update.apk.tmp';
    final downloadFile   = File('${downloadsDir.path}/$finalFileName');
    final downloadTmpFile = File('${downloadsDir.path}/$tempFileName');
    final client    = http.Client();

    // ── 3. Already downloaded — launch installer directly ───────────────
    if (await downloadFile.exists()) {
      final size = await downloadFile.length();
      debugPrint('[InAppUpdate] APK already on disk ($size bytes)');
      return _launchInstaller(downloadFile.path);
    }

    // ── 4. POST / GET with streaming response ───────────────────────────
    int? fileTotal;
    try {
      debugPrint('[InAppUpdate] Connecting to $apkUrl ...');
      final response = await client.send(
        http.Request('GET', Uri.parse(apkUrl))
          ..headers['Accept'] = 'application/vnd.android.package-archive',
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw InAppUpdateFailed(
          'HTTP ${response.statusCode} — server rejected the download.',
        );
      }

      fileTotal = response.contentLength;
      debugPrint(
        '[InAppUpdate] Connected. status=${response.statusCode} '
        'size=${fileTotal ?? 'unknown'}',
      );

      // ── 5. Stream → temp file with byte-level progress ───────────────
      debugPrint('[InAppUpdate] Writing stream → ${downloadTmpFile.path}');
      var bytesReceived = 0;
      final sink = downloadTmpFile.openWrite();

      await for (final List<int> chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        onProgress(bytesReceived, fileTotal ?? bytesReceived);
      }

      await sink.close();
      debugPrint(
        '[InAppUpdate] Stream complete. received=$bytesReceived bytes',
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
      debugPrint('[InAppUpdate] Download error: $e (${e.runtimeType})');
      throw InAppUpdateFailed('Download failed: $e');
    } finally {
      client.close();
    }

    // ── 6. Validate temp file before renaming ───────────────────────────
    final tmpLength = await downloadTmpFile.length();
    debugPrint('[InAppUpdate] Temp file size: $tmpLength bytes');

    if (tmpLength == 0) {
      debugPrint('[InAppUpdate] ERROR — downloaded file is empty');
      throw InAppUpdateFailed(
        'Downloaded file is empty. Check your internet and try again.',
      );
    }

    // Rename only after download is fully verified
    await downloadTmpFile.rename(downloadFile.path);
    debugPrint(
      '[InAppUpdate] Saved: ${downloadFile.path} '
      '(${await downloadFile.length()} bytes)',
    );

    // ── 7. Launch APK installer ─────────────────────────────────────────
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
