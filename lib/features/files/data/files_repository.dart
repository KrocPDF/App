import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/saved_document.dart';

class FilesRepository {
  static const String documentsFolder = 'KrocPDF_Documents';
  static const String indexFileName = 'documents_index.json';

  Future<Directory> getStorageDirectory() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocsDir.path}/$documentsFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _getIndexFile() async {
    final dir = await getStorageDirectory();
    return File('${dir.path}/$indexFileName');
  }

  Future<List<SavedDocument>> loadDocuments() async {
    final dir = await getStorageDirectory();
    final indexFile = await _getIndexFile();
    final Map<String, SavedDocument> indexedDocs = {};

    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        final List<dynamic> list = jsonDecode(content) as List<dynamic>;
        for (final item in list) {
          final doc = SavedDocument.fromJson(item as Map<String, dynamic>);
          if (File(doc.filePath).existsSync()) {
            indexedDocs[doc.filePath] = doc;
          }
        }
      } catch (_) {
        // Fallback to directory scan on parse error
      }
    }

    // Discover any unindexed or externally placed PDF files in the directory
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          if (!indexedDocs.containsKey(entity.path)) {
            final stat = entity.statSync();
            final fileName = entity.uri.pathSegments.last.replaceAll('.pdf', '');
            indexedDocs[entity.path] = SavedDocument(
              id: 'doc_${DateTime.now().microsecondsSinceEpoch}',
              title: fileName,
              filePath: entity.path,
              fileSizeBytes: stat.size,
              createdAt: stat.modified,
              pageCount: 1,
              sourceType: SavedDocumentSource.scan,
            );
          }
        }
      }
    } catch (_) {}

    final result = indexedDocs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Save cleaned index back
    await _saveIndex(result);
    return result;
  }

  Future<void> _saveIndex(List<SavedDocument> documents) async {
    try {
      final indexFile = await _getIndexFile();
      final jsonList = documents.map((e) => e.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<SavedDocument> addDocument({
    required String title,
    required String sourceFilePath,
    required int pageCount,
    SavedDocumentSource sourceType = SavedDocumentSource.scan,
    List<String> originalPages = const [],
  }) async {
    final dir = await getStorageDirectory();
    var cleanTitle = title.trim();
    if (cleanTitle.isEmpty) cleanTitle = 'Document';

    var destinationPath = '${dir.path}/$cleanTitle.pdf';
    var counter = 1;
    while (File(destinationPath).existsSync()) {
      destinationPath = '${dir.path}/${cleanTitle}_$counter.pdf';
      counter++;
    }

    final sourceFile = File(sourceFilePath);
    File finalFile;
    if (sourceFile.path != destinationPath) {
      finalFile = await sourceFile.copy(destinationPath);
    } else {
      finalFile = sourceFile;
    }

    final stat = await finalFile.stat();
    final newDoc = SavedDocument(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: destinationPath.split(Platform.pathSeparator).last.replaceAll('.pdf', ''),
      filePath: finalFile.path,
      fileSizeBytes: stat.size,
      createdAt: DateTime.now(),
      pageCount: pageCount,
      sourceType: sourceType,
      originalPagePaths: originalPages,
    );

    final currentDocs = await loadDocuments();
    final updatedList = [newDoc, ...currentDocs];
    await _saveIndex(updatedList);
    return newDoc;
  }

  Future<SavedDocument?> renameDocument(SavedDocument doc, String newTitle) async {
    final cleanTitle = newTitle.trim().replaceAll('.pdf', '');
    if (cleanTitle.isEmpty || cleanTitle == doc.title) return doc;

    final dir = await getStorageDirectory();
    final newPath = '${dir.path}/$cleanTitle.pdf';

    final oldFile = File(doc.filePath);
    if (!await oldFile.exists()) return null;

    final renamedFile = await oldFile.rename(newPath);
    final updatedDoc = doc.copyWith(
      title: cleanTitle,
      filePath: renamedFile.path,
    );

    final currentDocs = await loadDocuments();
    final index = currentDocs.indexWhere((e) => e.id == doc.id);
    if (index != -1) {
      currentDocs[index] = updatedDoc;
      await _saveIndex(currentDocs);
    }
    return updatedDoc;
  }

  Future<void> deleteDocument(SavedDocument doc) async {
    try {
      final file = File(doc.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    final currentDocs = await loadDocuments();
    currentDocs.removeWhere((e) => e.id == doc.id);
    await _saveIndex(currentDocs);
  }
}

class SavedFilesNotifier extends StateNotifier<List<SavedDocument>> {
  final FilesRepository _repository;

  SavedFilesNotifier(this._repository) : super(const []) {
    refresh();
  }

  Future<void> refresh() async {
    final docs = await _repository.loadDocuments();
    state = docs;
  }

  Future<SavedDocument> registerSavedPdf({
    required String title,
    required String tempPdfPath,
    required int pageCount,
    SavedDocumentSource sourceType = SavedDocumentSource.scan,
    List<String> originalPages = const [],
  }) async {
    final doc = await _repository.addDocument(
      title: title,
      sourceFilePath: tempPdfPath,
      pageCount: pageCount,
      sourceType: sourceType,
      originalPages: originalPages,
    );
    state = [doc, ...state.where((e) => e.id != doc.id)];
    return doc;
  }

  Future<void> rename(SavedDocument doc, String newTitle) async {
    final updated = await _repository.renameDocument(doc, newTitle);
    if (updated != null) {
      state = [
        for (final item in state)
          if (item.id == doc.id) updated else item,
      ];
    }
  }

  Future<void> delete(SavedDocument doc) async {
    await _repository.deleteDocument(doc);
    state = state.where((e) => e.id != doc.id).toList();
  }

  Future<void> checkExternalDeletions() async {
    final beforeCount = state.length;
    final valid = state.where((doc) => doc.exists).toList();
    if (valid.length != beforeCount) {
      state = valid;
      await _repository.loadDocuments();
    }
  }
}

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  return FilesRepository();
});

final savedFilesProvider =
    StateNotifierProvider<SavedFilesNotifier, List<SavedDocument>>((ref) {
  final repo = ref.watch(filesRepositoryProvider);
  return SavedFilesNotifier(repo);
});
