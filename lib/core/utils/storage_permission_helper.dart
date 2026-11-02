import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissionHelper {
  /// Checks and ensures storage permission if required.
  /// On Android 13+ (API 33+), system file picker (SAF) requires no runtime storage permissions.
  /// On Android <= 12 (API <= 32), permission_handler checks and requests Permission.storage.
  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 13+ (API 33+) uses system file picker (SAF) which requires no runtime storage permissions
      if (sdkInt >= 33) {
        return true;
      }
    } catch (_) {
      // If reading device info fails, allow the system file picker to launch directly
      return true;
    }

    // For Android <= 12 (SDK <= 32), check and request storage permission
    final status = await Permission.storage.status;
    if (status.isGranted) return true;
    final request = await Permission.storage.request();
    return request.isGranted;
  }
}

