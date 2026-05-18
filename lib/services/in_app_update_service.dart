import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import '../services/app_update_service.dart';

/// In-app update service:
/// 1. Optionally resolves the real APK URL from a GitHub release JSON
/// 2. Requests storage permission
/// 3. Downloads the APK to the public Downloads folder with byte progress
/// 4. Launches Android's native package installer via Intent
class InAppUpdateService {
  /// Downloads the APK and opens the system installer.
  ///
  /// Pass the [release] map from the GitHub API so the correct asset URL
  /// is resolved automatically — no hard-coded filename or tag needed.
  static Future<bool> downloadAndInstall({
    required void Function(int received, int total) onProgress,
    required Map<String, dynamic> release,
  }) async {
    final String apkUrl = AppUpdateService.resolveApkUrl(release);

    debugPrint('InAppUpdateService: downloading from $apkUrl');

    // ── 1. Storage permission ───────────────────────────────────────────
    final storageGranted = await perm.Permission.storage.request().isGranted;
    if (!storageGranted) {
      throw InAppUpdateFailed(
        'Storage permission is required to download the update.',
      );
    }

    final apkFile = File('/storage/emulated/0/Download/possapp-v1.apk');

    // ── 2. Pre-flight: skip download if APK already present ────────────
    if (await apkFile.exists()) {
      final existingSize = await apkFile.length();
      debugPrint('APK already exists on disk ($existingSize bytes), skipping download');
      return await _launchInstaller(apkFile.path);
    }

    // ── 3. Ensure Downloads directory exists ───────────────────────────
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // ── 4. Download ────────────────────────────────────────────────────
    final dio = Dio();
    try {
      await dio.download(
        apkUrl,
        apkFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received, total);
        },
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );
    } on DioException catch (e) {
      throw InAppUpdateFailed(_dioFriendlyError(e));
    } catch (e) {
      throw InAppUpdateFailed('Download failed: $e');
    }

    final fileSize = await apkFile.length();
    debugPrint('Download complete: $fileSize bytes');

    // ── 5. Open system APK installer ───────────────────────────────────
    return await _launchInstaller(apkFile.path);
  }

  /// Launches the APK file using the `apk` MIME type so Android routes
  /// directly to the package installer (not a file browser).
  static Future<bool> _launchInstaller(String apkPath) async {
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('OpenFilex [MIME]  type=${result.type}  msg=${result.message}');

    if (result.type == ResultType.done) return true;

    // Retry without explicit MIME in case the device rejects it
    final retry = await OpenFilex.open(apkPath);
    debugPrint('OpenFilex [retry]  type=${retry.type}  msg=${retry.message}');
    if (retry.type == ResultType.done) return true;

    throw InAppUpdateFailed(
      'Could not start the installer. APK saved at: $apkPath\n'
      'Error: ${retry.message}',
    );
  }

  /// Human-friendly error strings for Dio exceptions.
  static String _dioFriendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out.';
      case DioExceptionType.receiveTimeout:
        return 'Download timed out.';
      default:
        break;
    }
    if (e.response != null) {
      return 'HTTP ${e.response?.statusCode}.';
    }
    return e.message ?? 'Unknown download error.';
  }
}

/// Thrown by [InAppUpdateService] when the download or install step fails
/// so callers can present a friendly dialog instead of a stack trace.
class InAppUpdateFailed implements Exception {
  InAppUpdateFailed(this.message);
  final String message;

  @override
  String toString() => 'InAppUpdateFailed: $message';
}
