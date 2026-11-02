import 'dart:io';

enum SavedDocumentSource {
  scan,
  convert,
  merge,
  split,
  compress,
  importFile,
}

class SavedDocument {
  final String id;
  final String title;
  final String filePath;
  final int fileSizeBytes;
  final DateTime createdAt;
  final int pageCount;
  final SavedDocumentSource sourceType;
  final List<String> originalPagePaths;

  const SavedDocument({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileSizeBytes,
    required this.createdAt,
    this.pageCount = 1,
    this.sourceType = SavedDocumentSource.scan,
    this.originalPagePaths = const [],
  });

  bool get exists => File(filePath).existsSync();

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  SavedDocument copyWith({
    String? title,
    String? filePath,
    int? fileSizeBytes,
    DateTime? createdAt,
    int? pageCount,
    SavedDocumentSource? sourceType,
    List<String>? originalPagePaths,
  }) {
    return SavedDocument(
      id: id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      pageCount: pageCount ?? this.pageCount,
      sourceType: sourceType ?? this.sourceType,
      originalPagePaths: originalPagePaths ?? this.originalPagePaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'pageCount': pageCount,
      'sourceType': sourceType.name,
      'originalPagePaths': originalPagePaths,
    };
  }

  factory SavedDocument.fromJson(Map<String, dynamic> json) {
    return SavedDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      pageCount: json['pageCount'] as int? ?? 1,
      sourceType: SavedDocumentSource.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => SavedDocumentSource.scan,
      ),
      originalPagePaths: (json['originalPagePaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
