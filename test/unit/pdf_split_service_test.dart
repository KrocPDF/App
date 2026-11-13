import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/services/pdf_split_service.dart';
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
  group('SplitOutputFile metrics', () {
    test('formats byte sizes accurately', () {
      const small = SplitOutputFile(
        outputPath: '/tmp/a.pdf',
        fileName: 'a.pdf',
        fileSizeBytes: 512,
        pageCount: 1,
        pageNumbers: [1],
      );
      const kb = SplitOutputFile(
        outputPath: '/tmp/b.pdf',
        fileName: 'b.pdf',
        fileSizeBytes: 2048,
        pageCount: 2,
        pageNumbers: [1, 2],
      );
      const mb = SplitOutputFile(
        outputPath: '/tmp/c.pdf',
        fileName: 'c.pdf',
        fileSizeBytes: 2 * 1024 * 1024,
        pageCount: 10,
        pageNumbers: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );

      expect(small.formattedSize, equals('512 B'));
      expect(kb.formattedSize, equals('2.0 KB'));
      expect(mb.formattedSize, equals('2.00 MB'));
    });
  });

  group('SplitRangeValidator parsing & validation', () {
    test('parses custom ranges correctly', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 10,
        customRangesInput: '1-3, 5, 8-10',
        prefix: 'Report',
      );

      expect(res.isValid, isTrue);
      expect(res.groups.length, equals(3));
      expect(res.groups[0].pageNumbers, equals([1, 2, 3]));
      expect(res.groups[0].suggestedFileName, equals('Report_pages_1-3.pdf'));
      expect(res.groups[1].pageNumbers, equals([5]));
      expect(res.groups[1].suggestedFileName, equals('Report_page_5.pdf'));
      expect(res.groups[2].pageNumbers, equals([8, 9, 10]));
      expect(res.groups[2].suggestedFileName, equals('Report_pages_8-10.pdf'));
    });

    test('detects gaps and formats omitted pages', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 15,
        customRangesInput: '1-3, 10-12',
      );

      expect(res.isValid, isTrue);
      expect(res.missingPages, equals([4, 5, 6, 7, 8, 9, 13, 14, 15]));
      expect(res.hasSignificantGap, isTrue);
      expect(res.formatMissingRanges(), equals('4–9, 13–15'));
    });

    test('does not flag insignificant gaps (1-2 pages omitted)', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 6,
        customRangesInput: '1-3, 5-6',
      );

      expect(res.isValid, isTrue);
      expect(res.missingPages, equals([4]));
      expect(res.hasSignificantGap, isFalse);
    });

    test('rejects out of bounds page numbers', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 5,
        customRangesInput: '1-3, 6-8',
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('exceeds document page count of 5'));
    });

    test('rejects inverted ranges (start > end)', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 10,
        customRangesInput: '5-2',
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('cannot be greater than end page'));
    });

    test('rejects invalid syntax', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 10,
        customRangesInput: '1--4',
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Invalid range syntax'));
    });

    test('validates Every N Pages splitting with remainder', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.everyNPages,
        totalPages: 11,
        everyN: 4,
        prefix: 'Document',
      );

      expect(res.isValid, isTrue);
      expect(res.groups.length, equals(3));
      expect(res.groups[0].pageNumbers, equals([1, 2, 3, 4]));
      expect(res.groups[1].pageNumbers, equals([5, 6, 7, 8]));
      expect(res.groups[2].pageNumbers, equals([9, 10, 11]));
      expect(res.missingPages, isEmpty);
    });

    test('validates Equal Parts splitting with remainder distribution', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.equalParts,
        totalPages: 10,
        equalParts: 3,
        prefix: 'Doc',
      );

      expect(res.isValid, isTrue);
      expect(res.groups.length, equals(3));
      expect(res.groups[0].pageNumbers.length, equals(4)); // 10 ~/ 3 + 1
      expect(res.groups[1].pageNumbers.length, equals(3));
      expect(res.groups[2].pageNumbers.length, equals(3));
      expect(res.missingPages, isEmpty);
    });

    test('validates Extract All Pages', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.extractAll,
        totalPages: 4,
        prefix: 'Doc',
      );

      expect(res.isValid, isTrue);
      expect(res.groups.length, equals(4));
      for (int i = 0; i < 4; i++) {
        expect(res.groups[i].pageNumbers, equals([i + 1]));
      }
    });

    test('enforces 50-file hard cap', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.extractAll,
        totalPages: 55,
      );

      expect(res.isValid, isFalse);
      expect(res.exceedsHardCap, isTrue);
      expect(res.errorMessage, contains('maximum 50 allowed'));
    });

    test('flags 15+ confirmation threshold', () {
      final res = SplitRangeValidator.validate(
        mode: SplitMode.extractAll,
        totalPages: 20,
      );

      expect(res.isValid, isTrue);
      expect(res.requiresCountConfirmation, isTrue);
    });
  });

  group('PdfSplitService execution & integrity', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kroc_split_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('splits PDF using custom ranges and verifies output integrity', () async {
      final pdf = await _createTestPdf(tempDir, 'sample.pdf', pageCount: 8);
      const service = PdfSplitService();

      final validation = SplitRangeValidator.validate(
        mode: SplitMode.customRanges,
        totalPages: 8,
        customRangesInput: '1-3, 5, 7-8',
        prefix: 'custom_split',
      );

      final stages = <String>[];
      final result = await service.splitPdf(
        inputPath: pdf.path,
        groups: validation.groups,
        outputDirectory: tempDir.path,
        onProgress: (stage, _) => stages.add(stage),
      );

      expect(result.files.length, equals(3));
      expect(result.totalSourcePages, equals(8));
      expect(stages.isNotEmpty, isTrue);

      // Part 1: pages 1-3
      final doc1 = sf.PdfDocument(inputBytes: File(result.files[0].outputPath).readAsBytesSync());
      expect(doc1.pages.count, equals(3));
      doc1.dispose();

      // Part 2: page 5
      final doc2 = sf.PdfDocument(inputBytes: File(result.files[1].outputPath).readAsBytesSync());
      expect(doc2.pages.count, equals(1));
      doc2.dispose();

      // Part 3: pages 7-8
      final doc3 = sf.PdfDocument(inputBytes: File(result.files[2].outputPath).readAsBytesSync());
      expect(doc3.pages.count, equals(2));
      doc3.dispose();
    });

    test('inspectPdf correctly identifies pages and encryption', () async {
      final unencrypted = await _createTestPdf(tempDir, 'plain.pdf', pageCount: 4);
      final encrypted = await _createTestPdf(
        tempDir,
        'secret.pdf',
        pageCount: 3,
        userPassword: 'pass',
      );

      const service = PdfSplitService();

      final res1 = await service.inspectPdf(unencrypted.path);
      expect(res1.pageCount, equals(4));
      expect(res1.isEncrypted, isFalse);

      final res2 = await service.inspectPdf(encrypted.path);
      expect(res2.isEncrypted, isTrue);

      final res3 = await service.inspectPdf(encrypted.path, password: 'pass');
      expect(res3.pageCount, equals(3));
      expect(res3.isEncrypted, isFalse);
    });
  });
}
