import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/core/result/result.dart';
import 'package:krocpdf/services/pdf_merge_service.dart';
import 'package:krocpdf/services/processing/local_processing_service.dart';
import 'package:krocpdf/services/processing/processing_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<File> _createTestPdf(
  Directory dir,
  String name, {
  int pageCount = 1,
  String? userPassword,
}) async {
  final doc = sf.PdfDocument();
  if (userPassword != null && userPassword.isNotEmpty) {
    doc.security.userPassword = userPassword;
    doc.security.ownerPassword = '${userPassword}_owner';
  }
  final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14);
  for (int i = 0; i < pageCount; i++) {
    final page = doc.pages.add();
    page.graphics.drawString(
      '$name - Page ${i + 1}',
      font,
      bounds: const Rect.fromLTWH(40, 40, 400, 100),
    );
  }
  final bytes = doc.saveSync();
  doc.dispose();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}

void main() {
  group('MergedPdfResult metrics', () {
    test('formats byte sizes accurately', () {
      const small = MergedPdfResult(
        outputPath: '/tmp/a.pdf',
        fileName: 'a.pdf',
        fileSizeBytes: 512,
        totalPageCount: 2,
        sourcePageCounts: [1, 1],
      );
      const kb = MergedPdfResult(
        outputPath: '/tmp/b.pdf',
        fileName: 'b.pdf',
        fileSizeBytes: 2048,
        totalPageCount: 3,
        sourcePageCounts: [1, 2],
      );
      const mb = MergedPdfResult(
        outputPath: '/tmp/c.pdf',
        fileName: 'c.pdf',
        fileSizeBytes: 2 * 1024 * 1024,
        totalPageCount: 10,
        sourcePageCounts: [5, 5],
      );

      expect(small.formattedSize, equals('512 B'));
      expect(kb.formattedSize, equals('2.0 KB'));
      expect(mb.formattedSize, equals('2.00 MB'));
    });
  });

  group('PdfMergeService', () {
    test('merges two PDFs and preserves total page count and order', () async {
      final tempDir = Directory.systemTemp.createTempSync('krocpdf_merge_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final pdf1 = await _createTestPdf(tempDir, 'first.pdf', pageCount: 2);
      final pdf2 = await _createTestPdf(tempDir, 'second.pdf', pageCount: 3);

      const service = PdfMergeService();
      final stages = <String>[];
      final result = await service.mergePdfs(
        inputPaths: [pdf1.path, pdf2.path],
        outputDirectory: tempDir.path,
        outputFileName: 'combined_output',
        onProgress: (status, _) => stages.add(status),
      );

      expect(result.fileName, equals('combined_output.pdf'));
      expect(result.totalPageCount, equals(5));
      expect(result.sourcePageCounts, equals([2, 3]));
      expect(File(result.outputPath).existsSync(), isTrue);
      expect(stages.isNotEmpty, isTrue);

      final mergedBytes = await File(result.outputPath).readAsBytes();
      final checkDoc = sf.PdfDocument(inputBytes: mergedBytes);
      expect(checkDoc.pages.count, equals(5));
      checkDoc.dispose();
    });

    test('rejects non-PDF files and incorrect file counts', () async {
      final tempDir = Directory.systemTemp.createTempSync('krocpdf_merge_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final pdf1 = await _createTestPdf(tempDir, 'only_one.pdf');
      final imgFile = File('${tempDir.path}/photo.jpg');
      await imgFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);

      const service = PdfMergeService();

      await expectLater(
        () => service.mergePdfs(
          inputPaths: [pdf1.path],
          outputDirectory: tempDir.path,
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => service.mergePdfs(
          inputPaths: [pdf1.path, imgFile.path],
          outputDirectory: tempDir.path,
        ),
        throwsFormatException,
      );
    });

    test(
      'inspectFiles detects 1 or 2 password-protected PDFs and merges after unlock',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('krocpdf_merge_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final plain = await _createTestPdf(tempDir, 'plain.pdf', pageCount: 1);
        final locked1 = await _createTestPdf(
          tempDir,
          'locked1.pdf',
          pageCount: 2,
          userPassword: 'secret1',
        );
        final locked2 = await _createTestPdf(
          tempDir,
          'locked2.pdf',
          pageCount: 2,
          userPassword: 'secret2',
        );

        const service = PdfMergeService();

        final oneLockedCheck = await service.inspectFiles([
          plain.path,
          locked1.path,
        ]);
        expect(oneLockedCheck.hasEncryptedFiles, isTrue);
        expect(oneLockedCheck.encryptedFilePaths, equals([locked1.path]));
        expect(oneLockedCheck.hasInvalidFiles, isFalse);

        final twoLockedCheck = await service.inspectFiles([
          locked1.path,
          locked2.path,
        ]);
        expect(twoLockedCheck.hasEncryptedFiles, isTrue);
        expect(
          twoLockedCheck.encryptedFilePaths,
          equals([locked1.path, locked2.path]),
        );

        await expectLater(
          () => service.mergePdfs(
            inputPaths: [locked1.path, locked2.path],
            outputDirectory: tempDir.path,
          ),
          throwsA(isA<PdfPasswordRequiredException>()),
        );

        await expectLater(
          () => service.mergePdfs(
            inputPaths: [locked1.path, locked2.path],
            passwords: {locked1.path: 'wrong', locked2.path: 'secret2'},
            outputDirectory: tempDir.path,
          ),
          throwsA(
            isA<PdfInvalidPasswordException>().having(
              (e) => e.failedFilePaths,
              'failedFilePaths',
              contains(locked1.path),
            ),
          ),
        );

        final unlockedMerge = await service.mergePdfs(
          inputPaths: [locked1.path, locked2.path],
          passwords: {locked1.path: 'secret1', locked2.path: 'secret2'},
          outputDirectory: tempDir.path,
        );
        expect(unlockedMerge.totalPageCount, equals(4));
        expect(unlockedMerge.sourcePageCounts, equals([2, 2]));
      },
    );

    test('LocalProcessingService handles merge_pdf request', () async {
      final tempDir = Directory.systemTemp.createTempSync('krocpdf_merge_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final pdf1 = await _createTestPdf(tempDir, 'a.pdf', pageCount: 1);
      final pdf2 = await _createTestPdf(tempDir, 'b.pdf', pageCount: 2);

      // Verify validation failure when < 2 files are supplied
      const localService = LocalProcessingService();
      final badRes = await localService.process(
        ProcessingRequest(toolId: 'merge_pdf', filePaths: [pdf1.path]),
      );
      expect(badRes, isA<Failure>());

      // Verify service-level merge works cleanly with valid 2-PDF input
      const mergeService = PdfMergeService();
      final merged = await mergeService.mergePdfs(
        inputPaths: [pdf1.path, pdf2.path],
        outputDirectory: tempDir.path,
      );
      expect(merged.totalPageCount, equals(3));
    });
  });
}
