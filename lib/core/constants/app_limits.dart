class AppLimits {
  AppLimits._();

  /// Maximum file size allowed for local on-device processing (100 MB).
  static const int maxLocalFileBytes = 100 * 1024 * 1024;

  /// Formatted limit string in megabytes for user-facing UI labels.
  static String get formattedLimitMb {
    final mb = maxLocalFileBytes / (1024 * 1024);
    return '${mb.toInt()} MB';
  }
}
