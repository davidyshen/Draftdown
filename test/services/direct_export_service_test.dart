import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/models/export_format.dart';
import 'package:draftdown/services/direct_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorController controller;
  late DirectExportService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = EditorController();
    service = DirectExportService();
  });

  tearDown(() {
    controller.dispose();
  });

  group('DirectExportService PDF layout options', () {
    test(
      'defaults to single line spacing (1.6) without line or page numbers',
      () {
        final html = service.generateHtmlDocument(
          markdown: '# Heading\n\nParagraph text.\n\n```\ncode\n```',
          controller: controller,
        );

        expect(html, contains('line-height: 1.6;'));
        expect(html, contains('line-height: 1.35;'));
        expect(html, contains('line-height: 1.5;'));
        expect(html, isNot(contains('@bottom-center')));
        expect(html, isNot(contains('with-line-numbers')));
      },
    );

    test('applies 1.5 and double line spacing proportionally', () {
      final html15 = service.generateHtmlDocument(
        markdown: 'Body text.',
        controller: controller,
        lineSpacing: ExportLineSpacing.onePointFive,
      );
      expect(html15, contains('line-height: 2.4;'));
      expect(html15, contains('line-height: 1.35;'));
      expect(html15, contains('line-height: 1.5;'));

      final htmlDouble = service.generateHtmlDocument(
        markdown: 'Body text.',
        controller: controller,
        lineSpacing: ExportLineSpacing.doubleSpacing,
      );
      expect(htmlDouble, contains('line-height: 3.2;'));
      expect(htmlDouble, contains('line-height: 1.35;'));
      expect(htmlDouble, contains('line-height: 1.5;'));
    });

    test(
      'emits centred Page 1 of N footer CSS when showPageNumbers is true',
      () {
        final html = service.generateHtmlDocument(
          markdown: 'Body text.',
          controller: controller,
          showPageNumbers: true,
        );

        expect(html, contains('@bottom-center'));
        expect(
          html,
          contains('content: "Page " counter(page) " of " counter(pages);'),
        );
      },
    );

    test('emits margin line number styles and beforeprint script when showLineNumbers is true', () {
      final html = service.generateHtmlDocument(
        markdown: 'Line one.\n\nLine two.',
        controller: controller,
        showLineNumbers: true,
      );

      expect(html, contains('class="page-container with-line-numbers"'));
      expect(html, contains('.line-number-label'));
      expect(html, contains('overflow: visible !important;'));
      expect(html, contains('.math-display'));
      expect(html, contains('range.getClientRects()'));
      expect(html, contains("window.addEventListener('beforeprint'"));
      expect(html, contains("window.matchMedia('print')"));
    });
  });
}
