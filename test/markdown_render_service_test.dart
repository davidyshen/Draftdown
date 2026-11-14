import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdwriter/controllers/editor_controller.dart';
import 'package:mdwriter/models/citation_item.dart';
import 'package:mdwriter/services/markdown_render_service.dart';
import 'package:mdwriter/ui/widgets/markdown_preview.dart';

void main() {
  group('MarkdownRenderService', () {
    test('renders empty document indicator for empty or blank input', () {
      final payload = MarkdownRenderPayload(
        renderId: 1,
        rawMarkdown: '   \n  ',
        citations: const [],
        citationStyle: CitationStyle.authorYear,
      );

      final result = MarkdownRenderService.executeMarkdownRender(payload);
      expect(result.renderId, equals(1));
      expect(result.processedMarkdown, equals('_Document is empty._'));
      expect(result.numericIndices, isEmpty);
    });

    test('normalises task checkboxes, incomplete bullets, and spaces', () {
      const raw = '''
- [ ] 
*   
*    Indented text
''';
      final payload = MarkdownRenderPayload(
        renderId: 2,
        rawMarkdown: raw,
        citations: const [],
        citationStyle: CitationStyle.authorYear,
      );

      final result = MarkdownRenderService.executeMarkdownRender(payload);
      expect(result.processedMarkdown, contains('\u00A0'));
      expect(result.processedMarkdown, contains(r'\*'));
    });

    test('converts HTML img tags to Markdown syntax outside code blocks', () {
      const raw = '''
<img src="chart.png" alt="My Chart" width="400" height="250" />

```html
<img src="code.png" />
```
''';
      final payload = MarkdownRenderPayload(
        renderId: 3,
        rawMarkdown: raw,
        citations: const [],
        citationStyle: CitationStyle.authorYear,
      );

      final result = MarkdownRenderService.executeMarkdownRender(payload);
      expect(result.processedMarkdown, contains('![My Chart](chart.png#400x250)'));
      // Code block content should remain intact
      expect(result.processedMarkdown, contains('<img src="code.png" />'));
    });

    test('extracts, sorts, and builds bibliography in Author-Year citation style', () {
      final citations = <CitationItem>[
        const CitationItem(
          key: 'turing1950',
          itemType: 'article',
          title: 'Computing Machinery and Intelligence',
          authors: ['Alan M. Turing'],
          year: '1950',
          venue: 'Mind',
        ),
        const CitationItem(
          key: 'shannon1948',
          itemType: 'article',
          title: 'A Mathematical Theory of Communication',
          authors: ['Claude E. Shannon'],
          year: '1948',
          venue: 'Bell System Technical Journal',
        ),
      ];

      const raw = '''
# Theory
As demonstrated by @turing1950 and earlier in [@shannon1948].
''';
      final payload = MarkdownRenderPayload(
        renderId: 4,
        rawMarkdown: raw,
        citations: citations,
        citationStyle: CitationStyle.authorYear,
      );

      final result = MarkdownRenderService.executeMarkdownRender(payload);
      expect(result.processedMarkdown, contains('### References'));
      // In author-year, Shannon (S) appears before Turing (T)
      final shannonIdx = result.processedMarkdown.indexOf('Claude E. Shannon');
      final turingIdx = result.processedMarkdown.indexOf('Alan M. Turing');
      expect(shannonIdx, lessThan(turingIdx));
    });

    test('extracts, numbers, and builds bibliography in Numeric citation style', () {
      final citations = <CitationItem>[
        const CitationItem(
          key: 'turing1950',
          itemType: 'article',
          title: 'Computing Machinery and Intelligence',
          authors: ['Alan M. Turing'],
          year: '1950',
          venue: 'Mind',
        ),
        const CitationItem(
          key: 'shannon1948',
          itemType: 'article',
          title: 'A Mathematical Theory of Communication',
          authors: ['Claude E. Shannon'],
          year: '1948',
          venue: 'Bell System Technical Journal',
        ),
      ];

      // Turing cited first, Shannon cited second
      const raw = '''
# Foundations
First [@turing1950], then [@shannon1948].
''';
      final payload = MarkdownRenderPayload(
        renderId: 5,
        rawMarkdown: raw,
        citations: citations,
        citationStyle: CitationStyle.numeric,
      );

      final result = MarkdownRenderService.executeMarkdownRender(payload);
      expect(result.numericIndices['turing1950'], equals(1));
      expect(result.numericIndices['shannon1948'], equals(2));
      expect(result.processedMarkdown, contains('1. **Alan M. Turing** (1950).'));
      expect(result.processedMarkdown, contains('2. **Claude E. Shannon** (1948).'));
    });

    test('asynchronous render dispatch completes and returns payload result', () async {
      final service = MarkdownRenderService();
      final payload = MarkdownRenderPayload(
        renderId: 42,
        rawMarkdown: '# Async Test\nContent',
        citations: const [],
        citationStyle: CitationStyle.authorYear,
      );

      final result = await service.render(payload);
      expect(result.renderId, equals(42));
      expect(result.processedMarkdown, equals('# Async Test\nContent'));
    });

    testWidgets('EditorController decouples user typing so typing continues while render is in flight', (tester) async {
      // Create a controlled render completer so we can hold the background render in-flight
      late MarkdownRenderPayload capturedPayload1;
      late void Function(MarkdownRenderResult) completeRender1;

      final controller = EditorController(
        renderDebounceDuration: const Duration(milliseconds: 1500),
        renderService: MarkdownRenderService(
          runner: (payload) {
            capturedPayload1 = payload;
            final completer = Completer<MarkdownRenderResult>();
            completeRender1 = completer.complete;
            return completer.future;
          },
        ),
      );
      addTearDown(controller.dispose);
      controller.newFile();

      // Mount widget so focusNode has context (simulating mounted editor)
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: controller.focusNode,
            child: const SizedBox(),
          ),
        ),
      ));

      // User types first text
      controller.textController.text = 'First draft';

      // Advance clock past 1.5s idle window to trigger debounce and snapshot
      await tester.pump(const Duration(milliseconds: 1600));

      // Background render is now in-flight with snapshot 'First draft'
      expect(controller.isBackgroundRendering, isTrue);
      expect(capturedPayload1.rawMarkdown, equals('First draft'));

      // While background render is STILL in-flight, user continues typing!
      controller.textController.text = 'First draft with second thought';
      await tester.pump();

      // Editor content has updated immediately without waiting
      expect(controller.content, equals('First draft with second thought'));
      // A new debounce timer is active
      expect(controller.isRenderPending, isTrue);

      // Now complete the background render for the first snapshot
      completeRender1(MarkdownRenderResult(
        renderId: capturedPayload1.renderId,
        rawMarkdown: capturedPayload1.rawMarkdown,
        processedMarkdown: 'First draft',
        numericIndices: const {},
      ));
      await tester.pump();

      // Preview displays the rendered first draft while editor holds the newer text
      expect(controller.previewMarkdown, equals('First draft'));
      expect(controller.content, equals('First draft with second thought'));

      // Advance to clear the active timer for the second typing event
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('EditorController discards stale out-of-order renders', (tester) async {
      final completers = <int, Completer<MarkdownRenderResult>>{};

      final controller = EditorController(
        renderDebounceDuration: const Duration(milliseconds: 50),
        renderService: MarkdownRenderService(
          runner: (payload) {
            final completer = Completer<MarkdownRenderResult>();
            completers[payload.renderId] = completer;
            return completer.future;
          },
        ),
      );
      addTearDown(controller.dispose);
      controller.newFile();

      // Mount widget so focusNode has context
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: controller.focusNode,
            child: const SizedBox(),
          ),
        ),
      ));

      // Trigger first render
      controller.textController.text = 'Version 1';
      await tester.pump(const Duration(milliseconds: 70));
      expect(completers.containsKey(1), isTrue);

      // Trigger second render
      controller.textController.text = 'Version 2';
      await tester.pump(const Duration(milliseconds: 70));
      expect(completers.containsKey(2), isTrue);

      // Resolve version 2 FIRST (e.g. newer render finished before older)
      completers[2]!.complete(MarkdownRenderResult(
        renderId: 2,
        rawMarkdown: 'Version 2',
        processedMarkdown: 'Rendered Version 2',
        numericIndices: const {},
      ));
      await tester.pump();
      expect(controller.previewMarkdown, equals('Rendered Version 2'));

      // Now resolve version 1 LATER (stale older render)
      completers[1]!.complete(MarkdownRenderResult(
        renderId: 1,
        rawMarkdown: 'Version 1',
        processedMarkdown: 'Rendered Version 1',
        numericIndices: const {},
      ));
      await tester.pump();

      // Preview must NOT be overwritten by the stale older render!
      expect(controller.previewMarkdown, equals('Rendered Version 2'));
    });

    testWidgets('MarkdownPreviewView consumes controller.astNodes directly without main-thread re-processing', (tester) async {
      final controller = EditorController(
        renderDebounceDuration: const Duration(milliseconds: 50),
      );
      addTearDown(controller.dispose);
      controller.newFile();

      // Create a document with citations, checkboxes, math, and headers
      final docText = '''
# Fast Document
- [ ] Task item
According to @turing1950computing, machinery computes.
Formula: \$E=mc^2\$.
''';

      controller.textController.text = docText;
      controller.flushPendingRenderUpdate();

      expect(controller.astNodes, isNotNull);
      expect(controller.previewMarkdown, contains('References'));

      // Mount MarkdownPreviewView using controller
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownPreviewView(
            markdown: controller.previewMarkdown,
            controller: controller,
          ),
        ),
      ));
      await tester.pump();

      // Verify AstMarkdownBody received the pre-parsed AST nodes directly
      final astFinder = find.byType(AstMarkdownBody);
      expect(astFinder, findsOneWidget);
      final astWidget = tester.widget<AstMarkdownBody>(astFinder);
      expect(astWidget.astNodes, isNotNull);
      expect(astWidget.astNodes, equals(controller.astNodes));
    });
  });
}
