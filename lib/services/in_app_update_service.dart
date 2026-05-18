import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

class InAppUpdateService {
  static const String _downloadUrl =
      'https://github.com/lubegamatthew/cpos-app/releases/download/v1.0.0/possapp-v1.apk';

  /// Downloads the APK and launches the installer, reporting progress via [onProgress].
  /// Returns true when the installer was successfully launched.
  static Future<bool> downloadAndInstall({
    required void Function(int received, int total) onProgress,
  }) async {
    // 1. Storage permission (needed to write the APK to external storage)
    final storageGranted = await perm.Permission.storage.request().isGranted;
    if (!storageGranted) {
      throw 'Storage permission is required to download and install the update.';
    }

    // 2. Determine APK save path in the public Downloads folder
    final Directory downloadsDir = Directory(
      '/storage/emulated/0/Download',
    );
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final apkFile = File('${downloadsDir.path}/possapp-v1.apk');

    // 3. Download with Dio (shows real byte-level progress)
    final dio = Dio();
    try {
      await dio.download(
        _downloadUrl,
        apkFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received, total);
        },
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );
    } on DioException catch (e) {
      throw 'Download failed: ${_friendlyHttpError(e)}';
    } catch (e) {
      throw 'Download failed: $e';
    }

    // 4. Open the APK with the system package installer
    final result = await OpenFilex.open(apkFile.path);

    if (result.type == ResultType.done) {
      return true;
    }

    // Fallback: if direct open failed, try the known concept
    try {
      if (result.type == ResultType.fileNotFound && await apkFile.exists()) {
        throw 'Installer could not open the file. Try installing manually from: ${apkFile.path}';
      }
    } catch (_) {}

    throw 'Could not launch the installer: ${result.message}. '
        'The APK was saved to: ${apkFile.path}';
  }

  static String _friendlyHttpError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timed out.';
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'Download timed out.';
    }
    if (e.response != null) {
      return 'HTTP ${e.response?.statusCode ?? 'error'}.';
    }
    return e.message ?? 'Unknown error.';
  }
}
