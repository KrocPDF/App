import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/files/data/files_repository.dart';

/// Enforces the throwaway expo demo expiry policy on the `expo-demo-build` branch.
///
/// Checks local device time against [expiryDate], detects clock-rollback tampering
/// via a persisted last-seen timestamp, permanently locks the app once expired,
/// and wipes all local document and cache directories.
class DemoGuard {
  DemoGuard._();

  /// Hardcoded demo expiry: December 31, 2026, 23:59:59 local device time (IST).
  /// Non-UTC DateTime ensures comparison uses the device's local clock.
  static final DateTime expiryDate = DateTime(2026, 12, 31, 23, 59, 59);

  static const String _prefExpiredKey = 'demo_guard_is_expired';
  static const String _prefLastSeenKey = 'demo_guard_last_seen_ms';

  /// Tolerance in ms for minor automatic NTP clock adjustments.
  static const int _rollbackToleranceMs = 5000;

  static final ValueNotifier<bool> expiredNotifier = ValueNotifier<bool>(false);

  static bool _isExpiredCached = false;
  static bool _wipeCompleted = false;

  /// Synchronous cached state for immediate widget tree / LaunchGate checks.
  static bool get isExpiredCached => _isExpiredCached;

  /// Evaluates expiry, persists lock state on expiry or clock rollback, and wipes
  /// all app data directories if expired.
  static Future<bool> isExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyExpired = prefs.getBool(_prefExpiredKey) ?? false;

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final lastSeenMs = prefs.getInt(_prefLastSeenKey);

    final bool clockRolledBack =
        lastSeenMs != null && nowMs < (lastSeenMs - _rollbackToleranceMs);
    final bool pastExpiryDate = !now.isBefore(expiryDate);

    if (alreadyExpired || clockRolledBack || pastExpiryDate) {
      if (!alreadyExpired) {
        await prefs.setBool(_prefExpiredKey, true);
      }
      _isExpiredCached = true;
      expiredNotifier.value = true;

      if (!_wipeCompleted) {
        await wipeAllAppData();
        _wipeCompleted = true;
      }
      return true;
    }

    if (lastSeenMs == null || nowMs > lastSeenMs) {
      await prefs.setInt(_prefLastSeenKey, nowMs);
    }
    _isExpiredCached = false;
    expiredNotifier.value = false;
    return false;
  }

  /// Deletes all files inside temporary, app documents (including KrocPDF_Documents),
  /// app support, and external app directories.
  static Future<void> wipeAllAppData() async {
    final dirs = <Directory>[];

    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      dirs.add(Directory('${appDocs.path}/${FilesRepository.documentsFolder}'));
      dirs.add(appDocs);
    } catch (_) {}

    try {
      dirs.add(await getApplicationSupportDirectory());
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        dirs.add(extDir);
      }
    } catch (_) {}

    for (final dir in dirs) {
      await _clearDirectoryContents(dir);
    }
  }

  static Future<void> _clearDirectoryContents(Directory dir) async {
    try {
      if (!await dir.exists()) {
        return;
      }
      await for (final entity in dir.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // Best-effort deletion: continue wiping remaining entries even if one is locked.
        }
      }
    } catch (_) {}
  }
}
