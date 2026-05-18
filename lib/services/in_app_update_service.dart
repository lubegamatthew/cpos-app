import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

/// In-app update service:
/// 1. Requests storage permission
/// 2. Downloads the APK to the public Downloads folder with byte progress
/// 3. Launches Android's native package installer via Intent
class InAppUpdateService {
  static const String _downloadUrl =
      'https://github.com/lubegamatthew/cpos-app/releases/download/v1.0.0/possapp-v1.apk';

  /// Downloads the APK and opens the system installer.
  /// [onProgress] is called with [received] / [total] on each byte chunk.
  static Future<bool> downloadAndInstall({
    required void Function(int received, int total) onProgress,
  }) async {
    // ── 1. Storage permission ───────────────────────────────────────────
    final storageGranted = await perm.Permission.storage.request().isGranted;
    if (!storageGranted) {
      throw InAppUpdateFailed(
        'Storage permission is required to download the update.',
      );
    }

    // ── 2. Pre-flight: check APK already downloaded ────────────────────
    final apkFile = File('/storage/emulated/0/Download/possapp-v1.apk');
    if (await apkFile.exists()) {
      final existingSize = await apkFile.length();
      debugPrint('APK already exists ($existingSize bytes), skipping download');
      return await _launchInstaller(apkFile.path);
    }

    // ── 3. Ensure the Downloads directory exists ───────────────────────
    final downloadsDir = Directory(
      '/storage/emulated/0/Download',
    );
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // ── 4. Download APK ────────────────────────────────────────────────
    final dio = Dio();
    try {
      await dio.download(
        _downloadUrl,
        apkFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received, total);
        },
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );
    } on DioException catch (e) {
      throw InAppUpdateFailed(_dioError(e));
    } catch (e) {
      throw InAppUpdateFailed('Download failed: $e');
    }

    debugPrint('Download complete: ${await apkFile.length()} bytes');
    return await _launchInstaller(apkFile.path);
  }

  /// Opens the APK using the correct file-type MIME so Android routes
  /// straight to the package installer rather than an arbitrary file viewer.
  static Future<bool> _launchInstaller(String apkPath) async {
    // `application/vnd.android.package-archive` is the registered MIME for .apk
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );

    debugPrint('OpenFilex result type: ${result.type} message: ${result.message}');

    if (result.type == ResultType.done) {
      return true;
    }

    // Try a plain intent without specifying intent-type
    final result2 = await OpenFilex.open(apkPath);
    if (result2.type == ResultType.done) {
      return true;
    }

    throw InAppUpdateFailed(
      'Could not open the APK installer. '
      'The APK was saved to: $apkPath\n'
      'Error: ${result2.message}',
    );
  }

  static String _dioError(DioException e) {
    if (e.type == DioExceptionType.connectionError) return 'No internet.';
    if (e.type == DioExceptionType.connectionTimeout) return 'Connection timed out.';
    if (e.type == DioExceptionType.receiveTimeout) return 'Download timed out.';
    if (e.response != null) return 'HTTP ${e.response?.statusCode}.';
    return e.message ?? 'Unknown error.';
  }
}

/// Thrown by [InAppUpdateService] when the download or install step fails.
class InAppUpdateFailed implements Exception {
  InAppUpdateFailed(this.message);
  final String message;

  @override
  String toString() => 'InAppUpdateFailed: $message';
}
