import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/models/citation_item.dart';
import 'package:draftdown/models/export_format.dart';
import 'package:draftdown/models/history_entry.dart';
import 'package:draftdown/services/bibliography_service.dart';
import 'package:draftdown/services/direct_export_service.dart';
import 'package:draftdown/services/pandoc_service.dart';
import 'package:draftdown/services/zotero_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    },
  );

  group('CitationItem Model', () {
    test('formats Pandoc bracketed citation correctly', () {
      const item = CitationItem(
        key: 'turing1950',
        title: 'Computing Machinery and Intelligence',
        authors: ['Alan M. Turing'],
        year: '1950',
      );

      expect(item.toPandocCitation(), equals('[@turing1950]'));
      expect(
        item.toPandocCitation(locator: 'p. 433'),
        equals('[@turing1950, p. 433]'),
      );
      expect(
        item.toPandocCitation(suppressAuthor: true),
        equals('[-@turing1950]'),
      );
      expect(
        item.toPandocCitation(inText: true),
        equals('@turing1950'),
      );
      expect(
        item.toPandocCitation(inText: true, locator: 'p. 433'),
        equals('@turing1950 [p. 433]'),
      );
    });

    test('formats multiple Pandoc citations correctly', () {
      const item1 = CitationItem(
        key: 'turing1950',
        title: 'Computing Machinery and Intelligence',
        authors: ['Alan M. Turing'],
        year: '1950',
      );
      const item2 = CitationItem(
        key: 'shannon1948',
        title: 'A Mathematical Theory of Communication',
        authors: ['Claude E. Shannon'],
        year: '1948',
      );
      const item3 = CitationItem(
        key: 'knuth1984',
        title: 'Literate Programming',
        authors: ['Donald E. Knuth'],
        year: '1984',
      );

      // Bracketed multiple citations
      expect(
        CitationItem.formatMultiple([item1, item2]),
        equals('[@turing1950; @shannon1948]'),
      );
      expect(
        CitationItem.formatMultiple([item1, item2], locator: 'p. 42'),
        equals('[@turing1950; @shannon1948, p. 42]'),
      );
      expect(
        CitationItem.formatMultiple([item1, item2], suppressAuthor: true),
        equals('[-@turing1950; -@shannon1948]'),
      );

      // In-text multiple citations
      expect(
        CitationItem.formatMultiple([item1, item2], inText: true),
        equals('@turing1950 and @shannon1948'),
      );
      expect(
        CitationItem.formatMultiple([item1, item2], inText: true, locator: 'p. 42'),
        equals('@turing1950 and @shannon1948 [p. 42]'),
      );
      expect(
        CitationItem.formatMultiple([item1, item2, item3], inText: true),
        equals('@turing1950, @shannon1948, and @knuth1984'),
      );
    });

    test('generates human-readable author year representation', () {
      const singleAuthor = CitationItem(
        key: 'knuth1984',
        title: 'Literate Programming',
        authors: ['Donald E. Knuth'],
        year: '1984',
      );
      expect(singleAuthor.formattedAuthorYear, equals('Knuth, 1984'));

      const twoAuthors = CitationItem(
        key: 'page_brin1998',
        title: 'Anatomy of a Search Engine',
        authors: ['Larry Page', 'Sergey Brin'],
        year: '1998',
      );
      expect(twoAuthors.formattedAuthorYear,
          equals('Page & Brin, 1998'));

      const multiAuthors = CitationItem(
        key: 'vaswani2017',
        title: 'Attention is all you need',
        authors: ['Ashish Vaswani', 'Noam Shazeer', 'Niki Parmar'],
        year: '2017',
      );
      expect(multiAuthors.formattedAuthorYear, equals('Vaswani et al., 2017'));
    });

    test('infers author and year from Better BibTeX citekey when metadata is absent', () {
      const itemWithoutAuthors = CitationItem(
        key: 'moreno-mateosLongtermRestorationEcosystem2020',
        title: 'The long-term restoration of ecosystems',
        authors: [],
        year: null,
      );

      expect(itemWithoutAuthors.shortAuthorSummary, equals('Moreno-Mateos et al.'));
      expect(itemWithoutAuthors.effectiveYear, equals('2020'));
      expect(itemWithoutAuthors.formattedAuthorYear, equals('Moreno-Mateos et al., 2020'));
    });

    test('renders bibliography authors correctly based on the 10/6 rule', () {
      // 1 author
      const single = CitationItem(
        key: 'turing1950',
        title: 'Computing Machinery and Intelligence',
        authors: ['Alan M. Turing'],
      );
      expect(single.bibliographyAuthorsSummary, equals('Alan M. Turing'));

      // 5 authors (<= 10: all shown)
      const five = CitationItem(
        key: 'five2020',
        title: 'Title',
        authors: ['A. Smith', 'B. Jones', 'C. Taylor', 'D. Brown', 'E. Wilson'],
      );
      expect(
        five.bibliographyAuthorsSummary,
        equals('A. Smith, B. Jones, C. Taylor, D. Brown, E. Wilson'),
      );

      // 10 authors (<= 10: all shown)
      const ten = CitationItem(
        key: 'ten2020',
        title: 'Title',
        authors: [
          'A1', 'A2', 'A3', 'A4', 'A5',
          'A6', 'A7', 'A8', 'A9', 'A10'
        ],
      );
      expect(
        ten.bibliographyAuthorsSummary,
        equals('A1, A2, A3, A4, A5, A6, A7, A8, A9, A10'),
      );

      // 11 authors (> 10: first 6 shown and et al.)
      const eleven = CitationItem(
        key: 'eleven2020',
        title: 'Title',
        authors: [
          'A1', 'A2', 'A3', 'A4', 'A5',
          'A6', 'A7', 'A8', 'A9', 'A10', 'A11'
        ],
      );
      expect(
        eleven.bibliographyAuthorsSummary,
        equals('A1, A2, A3, A4, A5, A6, et al.'),
      );

      // 14 authors (> 10: first 6 shown and et al.)
      const fourteen = CitationItem(
        key: 'fourteen2020',
        title: 'Title',
        authors: [
          'Author 1', 'Author 2', 'Author 3', 'Author 4', 'Author 5',
          'Author 6', 'Author 7', 'Author 8', 'Author 9', 'Author 10',
          'Author 11', 'Author 12', 'Author 13', 'Author 14'
        ],
      );
      expect(
        fourteen.bibliographyAuthorsSummary,
        equals('Author 1, Author 2, Author 3, Author 4, Author 5, Author 6, et al.'),
      );

      // Empty authors fallback
      const empty = CitationItem(
        key: 'anonymous2020',
        title: 'Title',
        authors: [],
      );
      expect(empty.bibliographyAuthorsSummary, equals('Anonymous'));
    });
  });

  group('HistoryEntry Model', () {
    test('serialises and deserialises correctly', () {
      final entry = HistoryEntry(
        path: r'C:\Users\User\Documents\Research.md',
        fileName: 'Research.md',
        lastOpened: DateTime(2026, 11, 2, 12, 0),
        fileSize: 4096,
      );

      final json = entry.toJson();
      final revived = HistoryEntry.fromJson(json);

      expect(revived.path, equals(entry.path));
      expect(revived.fileName, equals(entry.fileName));
      expect(revived.fileSize, equals(4096));
    });

    test('calculates relative timestamps correctly in British English', () {
      final now = DateTime.now();
      final justNow = HistoryEntry(
        path: 'test.md',
        fileName: 'test.md',
        lastOpened: now.subtract(const Duration(seconds: 15)),
      );
      expect(justNow.relativeTime, equals('Just now'));

      final minsAgo = HistoryEntry(
        path: 'test.md',
        fileName: 'test.md',
        lastOpened: now.subtract(const Duration(minutes: 5)),
      );
      expect(minsAgo.relativeTime, equals('5 minutes ago'));

      final hoursAgo = HistoryEntry(
        path: 'test.md',
        fileName: 'test.md',
        lastOpened: now.subtract(const Duration(hours: 3)),
      );
      expect(hoursAgo.relativeTime, equals('3 hours ago'));

      final yesterday = HistoryEntry(
        path: 'test.md',
        fileName: 'test.md',
        lastOpened: now.subtract(const Duration(days: 1)),
      );
      expect(yesterday.relativeTime, equals('Yesterday'));
    });
  });

  group('BibliographyService Parser', () {
    test('parses BibTeX entries accurately', () {
      final service = BibliographyService();
      const sampleBibTeX = '''
@article{shannon1948,
  title = {A Mathematical Theory of Communication},
  author = {Shannon, Claude E.},
  journal = {Bell System Technical Journal},
  year = {1948},
  volume = {27},
  pages = {379--423}
}

@book{russell2010,
  title = {Artificial Intelligence: A Modern Approach},
  author = {Stuart Russell and Peter Norvig},
  publisher = {Prentice Hall},
  year = {2010}
}
''';

      final items = service.parseBibTeX(sampleBibTeX);
      expect(items.length, equals(2));

      final shannon = items.firstWhere((i) => i.key == 'shannon1948');
      expect(shannon.title, equals('A Mathematical Theory of Communication'));
      expect(shannon.year, equals('1948'));
      expect(shannon.venue, equals('Bell System Technical Journal'));

      final russell = items.firstWhere((i) => i.key == 'russell2010');
      expect(russell.title, equals('Artificial Intelligence: A Modern Approach'));
      expect(russell.authors.length, equals(2));
      expect(russell.year, equals('2010'));
    });

    test('parses CSL JSON accurately', () {
      final service = BibliographyService();
      const sampleJson = '''
[
  {
    "id": "item1",
    "type": "article-journal",
    "title": "Quantum Supremacy Using a Programmable Superconducting Processor",
    "author": [
      { "family": "Arute", "given": "Frank" },
      { "family": "Arya", "given": "Kunal" }
    ],
    "container-title": "Nature",
    "issued": {
      "date-parts": [[2019, 10, 23]]
    }
  }
]
''';

      final items = service.parseCslJson(sampleJson);
      expect(items.length, equals(1));
      expect(items.first.key, equals('item1'));
      expect(items.first.year, equals('2019'));
      expect(items.first.venue, equals('Nature'));
    });

    test('parses nested braces and unquoted macros in BibTeX accurately', () {
      final service = BibliographyService();
      const sample = '''
@article{moreno-mateosLongtermRestorationEcosystem2020,
  title = {The {Long-term} restoration of ecosystems},
  author = {Moreno-Mateos, David and Alberdi, Antton and Morri{\\"e}n, Elly},
  month = may,
  year = 2020,
  journal = {Nature Ecology & Evolution}
}
''';
      final items = service.parseBibTeX(sample);
      expect(items.length, equals(1));
      final it = items[0];
      expect(it.key, equals('moreno-mateosLongtermRestorationEcosystem2020'));
      expect(it.year, equals('2020'));
      expect(it.authors, contains('David Moreno-Mateos'));
      expect(it.shortAuthorSummary, equals('Moreno-Mateos et al.'));
      expect(it.formattedAuthorYear, equals('Moreno-Mateos et al., 2020'));
    });
  });

  group('ExportFormat', () {
    test('provides all major academic formats', () {
      final formats = ExportFormat.supportedFormats;
      final ids = formats.map((f) => f.id).toList();

      expect(ids, contains('pdf'));
      expect(ids, contains('docx'));
      expect(ids, contains('html5'));
      expect(ids, contains('latex'));
      expect(ids, contains('epub'));
    });
  });

  group('Typography Preferences', () {
    test('updates editor monospace font and preview fonts', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();

      expect(controller.editorFontFamily, equals('Consolas'));
      expect(controller.isDualRenderFont, isFalse);
      expect(controller.effectiveRenderHeaderFont,
          equals(controller.renderBodyFont));

      await controller.updateTypography(
        editorFontFamily: 'Fira Code',
        isDualRenderFont: true,
        renderHeaderFont: 'Georgia',
        renderBodyFont: 'Inter',
      );

      expect(controller.editorFontFamily, equals('Fira Code'));
      expect(controller.isDualRenderFont, isTrue);
      expect(controller.renderHeaderFont, equals('Georgia'));
      expect(controller.renderBodyFont, equals('Inter'));
      expect(controller.effectiveRenderHeaderFont, equals('Georgia'));
    });
  });

  group('Bundled Pandoc Service', () {
    test('detects bundled pandoc binary in assets/bin and reports version', () async {
      final pandocService = PandocService();
      final isAvailable = await pandocService.isAvailable();
      expect(isAvailable, isTrue);
      expect(pandocService.isBundled, isTrue);
      final version = await pandocService.getVersion();
      expect(version, contains('3.6.3'));
    });
  });

  group('Citation Source Switching', () {
    test('switches between BibTeX and Zotero sources', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();

      expect(controller.citationSource, equals(CitationSource.bibtex));
      expect(controller.citations.isNotEmpty, isTrue);
      expect(controller.citations.any((c) => c.key.contains('turing')), isTrue);

      await controller.setCitationSource(CitationSource.zotero);
      expect(controller.citationSource, equals(CitationSource.zotero));
      expect(controller.zoteroCitations.isNotEmpty, isTrue);
      expect(
        controller.zoteroCitations.any((c) => c.key.contains('vaswani2017attention')),
        isTrue,
      );
    });

    test('switches document citation style between authorYear and numeric', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();

      expect(controller.citationStyle, equals(CitationStyle.authorYear));

      await controller.setCitationStyle(CitationStyle.numeric);
      expect(controller.citationStyle, equals(CitationStyle.numeric));

      await controller.setCitationStyle(CitationStyle.authorYear);
      expect(controller.citationStyle, equals(CitationStyle.authorYear));
    });

    test('formatSelection inserts enclosing templates and positions cursor at entrypoint when collapsed', () {
      final controller = EditorController();

      // Bold: inserts **** and positions cursor at index 2 (**|**)
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('**', '**');
      expect(controller.textController.text, equals('****'));
      expect(controller.textController.selection.baseOffset, equals(2));
      expect(controller.textController.selection.extentOffset, equals(2));

      // Italic: inserts ** and positions cursor at index 1 (*|*)
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('*', '*');
      expect(controller.textController.text, equals('**'));
      expect(controller.textController.selection.baseOffset, equals(1));
      expect(controller.textController.selection.extentOffset, equals(1));

      // Strikethrough: inserts ~~~~ and positions cursor at index 2 (~~|~~)
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('~~', '~~');
      expect(controller.textController.text, equals('~~~~'));
      expect(controller.textController.selection.baseOffset, equals(2));
      expect(controller.textController.selection.extentOffset, equals(2));

      // Inline code: inserts `` and positions cursor at index 1 (`|`)
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('`', '`');
      expect(controller.textController.text, equals('``'));
      expect(controller.textController.selection.baseOffset, equals(1));
      expect(controller.textController.selection.extentOffset, equals(1));

      // Blockquote: inserts single > and positions cursor at index 2 (> |)
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('> ', '');
      expect(controller.textController.text, equals('> '));
      expect(controller.textController.selection.baseOffset, equals(2));
      expect(controller.textController.selection.extentOffset, equals(2));

      // Heading 1: inserts single # and positions cursor at index 2 (# |)
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('# ');
      expect(controller.textController.text, equals('# '));
      expect(controller.textController.selection.baseOffset, equals(2));
      expect(controller.textController.selection.extentOffset, equals(2));

      // Link: inserts [](https://) and positions cursor at index 1 ([|](https://))
      controller.textController.text = '';
      controller.textController.selection = const TextSelection.collapsed(offset: 0);
      controller.formatSelection('[', '](https://)');
      expect(controller.textController.text, equals('[](https://)'));
      expect(controller.textController.selection.baseOffset, equals(1));
      expect(controller.textController.selection.extentOffset, equals(1));
    });

    test('formatSelection wraps selected text properly', () {
      final controller = EditorController();

      // Wrap bold
      controller.textController.text = 'important note';
      controller.textController.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
      controller.formatSelection('**', '**');
      expect(controller.textController.text, equals('**important** note'));

      // Wrap quote
      controller.textController.text = 'quoted words';
      controller.textController.selection = const TextSelection(baseOffset: 0, extentOffset: 12);
      controller.formatSelection('> ', '');
      expect(controller.textController.text, equals('> quoted words'));
    });

    test('ZoteroService provides distinct citekeys and titles from Zotero library', () async {
      final zoteroService = ZoteroService();
      final items = await zoteroService.getOrSearch('attention');

      expect(items.isNotEmpty, isTrue);
      expect(items.first.key, equals('vaswani2017attention'));
      expect(items.first.title, contains('Attention Is All You Need'));
      expect(items.first.authors, contains('Ashish Vaswani'));
      expect(items.first.toPandocCitation(), equals('[@vaswani2017attention]'));
    });

    test('insertCitations inserts formatted multiple citations into controller', () {
      final controller = EditorController();
      controller.textController.text = 'See ';
      controller.textController.selection =
          const TextSelection.collapsed(offset: 4);

      const item1 = CitationItem(
        key: 'turing1950',
        title: 'Computing Machinery and Intelligence',
        authors: ['Alan M. Turing'],
        year: '1950',
      );
      const item2 = CitationItem(
        key: 'shannon1948',
        title: 'A Mathematical Theory of Communication',
        authors: ['Claude E. Shannon'],
        year: '1948',
      );

      controller.insertCitations([item1, item2]);
      expect(controller.content, equals('See [@turing1950; @shannon1948]'));
    });
  });

  group('DetectedCitation Recognition and In-Place Editing', () {
    test('detects single bracketed citation when cursor is inside', () {
      const doc = 'Look at [@asdf] in detail.';
      final detected = DetectedCitation.findAt(doc, 10);
      expect(detected, isNotNull);
      expect(detected!.rawText, equals('[@asdf]'));
      expect(detected.keys, equals(['asdf']));
      expect(detected.startOffset, equals(8));
      expect(detected.endOffset, equals(15));
      expect(detected.inText, isFalse);
    });

    test('detects multiple comma-separated bracketed citations', () {
      const doc = 'Refer to [@asdfsdf, @asdfasdf, @ghjghj] for details.';
      final detected = DetectedCitation.findAt(doc, 25);
      expect(detected, isNotNull);
      expect(detected!.rawText, equals('[@asdfsdf, @asdfasdf, @ghjghj]'));
      expect(detected.keys, equals(['asdfsdf', 'asdfasdf', 'ghjghj']));
      expect(detected.startOffset, equals(9));
      expect(detected.endOffset, equals(39));
    });

    test('detects semicolon-separated citations with locator and suppressAuthor', () {
      const doc = 'As proved in [-@turing1950; @shannon1948, p. 42].';
      final detected = DetectedCitation.findAt(doc, 20);
      expect(detected, isNotNull);
      expect(detected!.rawText, equals('[-@turing1950; @shannon1948, p. 42]'));
      expect(detected.keys, equals(['turing1950', 'shannon1948']));
      expect(detected.suppressAuthor, isTrue);
      expect(detected.locator, equals('p. 42'));
    });

    test('detects in-text citation', () {
      const doc = 'According to @shannon1948 [p. 10], information is...';
      final detected = DetectedCitation.findAt(doc, 16);
      expect(detected, isNotNull);
      expect(detected!.keys, equals(['shannon1948']));
      expect(detected.inText, isTrue);
      expect(detected.locator, equals('p. 10'));
    });

    test('returns null when cursor is outside citation', () {
      const doc = 'Look at [@asdf] in detail.';
      final detected = DetectedCitation.findAt(doc, 2);
      expect(detected, isNull);
    });

    test('replaceCitation replaces existing citation in editor controller', () {
      final controller = EditorController();
      controller.textController.text = 'Study [@old1, @old2] now.';
      final detected = DetectedCitation.findAt(controller.content, 10)!;

      controller.replaceCitation(detected, '[@new1; @new2]');
      expect(controller.content, equals('Study [@new1; @new2] now.'));
    });
  });

  group('BibTeX Generation and Key Extraction', () {
    test('CitationItem.toBibtex() generates valid BibTeX entry', () {
      const item = CitationItem(
        key: 'vaswani2017attention',
        title: 'Attention Is All You Need',
        authors: ['Ashish Vaswani', 'Noam Shazeer'],
        year: '2017',
        venue: 'NeurIPS',
        itemType: 'inproceedings',
        doi: '10.48550/arXiv.1706.03762',
      );

      final bib = item.toBibtex();
      expect(bib, contains('@inproceedings{vaswani2017attention,'));
      expect(bib, contains('title = {Attention Is All You Need}'));
      expect(bib, contains('author = {Ashish Vaswani and Noam Shazeer}'));
      expect(bib, contains('year = {2017}'));
      expect(bib, contains('booktitle = {NeurIPS}'));
      expect(bib, contains('doi = {10.48550/arXiv.1706.03762}'));
    });

    test('CitationItem.extractCitedKeys extracts multiple keys correctly', () {
      const md =
          'Comparing [@vaswani2017attention; @kaplan2020scaling; @devlin2019bert] with @knuth1984literate.';
      final keys = CitationItem.extractCitedKeys(md);

      expect(keys, contains('vaswani2017attention'));
      expect(keys, contains('kaplan2020scaling'));
      expect(keys, contains('devlin2019bert'));
      expect(keys, contains('knuth1984literate'));
      expect(keys.length, equals(4));
    });

    test('ExportOptions.copyWith works as expected', () {
      const options = ExportOptions(
        format: ExportFormat(
          type: ExportFormatType.docx,
          id: 'docx',
          name: 'Microsoft Word',
          extension: 'docx',
          pandocWriter: 'docx',
          description: 'Docx file',
          icon: Icons.description,
        ),
        targetPath: 'output.docx',
      );

      expect(options.pageSize, equals('a4'));
      expect(options.marginSize, equals('medium'));
      final updated = options.copyWith(
        bibliographyPath: 'custom.bib',
        pageSize: 'letter',
        marginSize: 'thin',
      );
      expect(updated.bibliographyPath, equals('custom.bib'));
      expect(updated.targetPath, equals('output.docx'));
      expect(updated.format.type, equals(ExportFormatType.docx));
      expect(updated.pageSize, equals('letter'));
      expect(updated.marginSize, equals('thin'));
    });
  });

  group('Export Bibliography Consolidation', () {
    test('prepareExportBibliography generates temporary bib file for cited Zotero keys', () async {
      final controller = EditorController();
      controller.textController.text =
          '[@vaswani2017attention; @kaplan2020scaling; @devlin2019bert]';

      final tempBib = await controller.prepareExportBibliography(
        markdownText: controller.content,
      );

      expect(tempBib, isNotNull);
      final bibContent = await tempBib!.readAsString();
      expect(bibContent, contains('vaswani2017attention'));
      expect(bibContent, contains('kaplan2020scaling'));
      expect(bibContent, contains('devlin2019bert'));

      // Clean up temporary file
      await tempBib.delete();
    });
  });

  group('DirectExportService (HTML and PDF Preview-Fidelity Export)', () {
    test('generateHtmlDocument applies preview typography, deep green code, and normal references', () async {
      final controller = EditorController();
      await controller.updateTypography(
        editorFontFamily: 'Fira Code',
        renderBodyFont: 'Inter',
        renderHeaderFont: 'Merriweather',
        isDualRenderFont: true,
      );
      controller.textController.text = '''# Research Note

Deep learning architectures were surveyed by [@vaswani2017attention].

```python
def forward(x):
    return x * 2
```
''';

      final service = controller.directExportService;
      final html = service.generateHtmlDocument(
        markdown: controller.content,
        controller: controller,
      );

      // Verify configured preview fonts
      expect(html, contains('--body-font: \'Inter\''));
      expect(html, contains('--header-font: \'Merriweather\''));
      expect(html, contains('--code-font: \'Fira Code\''));

      // Verify code block styling (deep green text, transparent background)
      expect(html, contains('#166534'));
      expect(html, contains('background: transparent !important'));

      // Verify citations in normal weight and colour
      expect(html, contains('<span class="citation">'));
      expect(html, contains('font-weight: normal !important'));

      // Verify auto-generated References heading and bibliography entry
      expect(html, contains('References'));
      expect(html, contains('Attention Is All You Need'));
    });

    test('generateHtmlDocument formats citations and bibliography numerically when in numeric mode', () async {
      final controller = EditorController();
      await controller.setCitationStyle(CitationStyle.numeric);
      controller.textController.text =
          'Pioneering work [@turing1950computing] led to transformers [@vaswani2017attention].';

      final service = controller.directExportService;
      final html = service.generateHtmlDocument(
        markdown: controller.content,
        controller: controller,
      );

      // Verify numeric citation formatting
      expect(html, contains('<span class="citation">[1]</span>'));
      expect(html, contains('<span class="citation">[2]</span>'));

      // Verify numbered bibliography entries in HTML <ol> list
      expect(html, contains('<ol>'));
      expect(html, contains('<li><strong>Alan M. Turing</strong> (1950). <em>Computing Machinery and Intelligence</em>'));
      expect(html, contains('<li><strong>Ashish Vaswani'));
    });

    test('DirectExportService finds browser executable on this environment', () async {
      final controller = EditorController();
      final service = controller.directExportService;
      final browser = await service.findBrowserExecutable();
      // On Windows 10/11, Edge is standard
      expect(browser, isNotNull);
    });

    test('DirectExportService generateHtmlDocument supports A4 and Letter page sizes', () {
      final controller = EditorController();
      final service = controller.directExportService;

      final htmlA4Default = service.generateHtmlDocument(
        markdown: '# Title',
        controller: controller,
      );
      expect(htmlA4Default, contains('size: A4 portrait;'));

      final htmlLetter = service.generateHtmlDocument(
        markdown: '# Title',
        controller: controller,
        pageSize: 'letter',
      );
      expect(htmlLetter, contains('size: letter portrait;'));
    });

    test('DirectExportService resolvePageMargin and generateHtmlDocument support medium, thin, and thick margins', () {
      expect(DirectExportService.resolvePageMargin('medium'), equals('1in'));
      expect(DirectExportService.resolvePageMargin('thin'), equals('0.5in'));
      expect(DirectExportService.resolvePageMargin('thick'), equals('1in 1.25in'));

      final controller = EditorController();
      final service = controller.directExportService;

      final htmlMedium = service.generateHtmlDocument(
        markdown: '# Document',
        controller: controller,
        marginSize: 'medium',
      );
      expect(htmlMedium, contains('margin: 1in;'));

      final htmlThin = service.generateHtmlDocument(
        markdown: '# Document',
        controller: controller,
        marginSize: 'thin',
      );
      expect(htmlThin, contains('margin: 0.5in;'));

      final htmlThick = service.generateHtmlDocument(
        markdown: '# Document',
        controller: controller,
        marginSize: 'thick',
      );
      expect(htmlThick, contains('margin: 1in 1.25in;'));
    });
  });

  group('Diacritic-Insensitive Citation Search', () {
    test('normalizeForSearch strips accents, umlauts, cedillas, and ligatures', () {
      expect(CitationItem.normalizeForSearch('pärtel'), equals('partel'));
      expect(CitationItem.normalizeForSearch('Pärtel'), equals('partel'));
      expect(CitationItem.normalizeForSearch('Schrödinger'), equals('schrodinger'));
      expect(CitationItem.normalizeForSearch('García-Bellido'), equals('garcia-bellido'));
      expect(CitationItem.normalizeForSearch('François'), equals('francois'));
      expect(CitationItem.normalizeForSearch('Poincaré'), equals('poincare'));
      expect(CitationItem.normalizeForSearch('Björn'), equals('bjorn'));
      expect(CitationItem.normalizeForSearch('Erdős'), equals('erdos'));
      expect(CitationItem.normalizeForSearch('Müller'), equals('muller'));
      expect(CitationItem.normalizeForSearch('Strauß'), equals('strauss'));
      // Unicode decomposed combining marks
      expect(CitationItem.normalizeForSearch('pa\u0308rtel'), equals('partel'));
    });

    test('BibliographyService matches items without requiring accent characters', () {
      final service = BibliographyService();
      const testItem1 = CitationItem(
        key: 'partel2002dark',
        title: 'Dark diversity and plant species coexistence',
        authors: ['Meelis Pärtel', 'Martin Zobel'],
        year: '2002',
      );
      const testItem2 = CitationItem(
        key: 'schrodinger1935cat',
        title: 'Die gegenwärtige Situation in der Quantenmechanik',
        authors: ['Erwin Schrödinger'],
        year: '1935',
      );
      const testItem3 = CitationItem(
        key: 'garcia2018gene',
        title: 'CRISPR Cas9 editing mechanisms',
        authors: ['Elena García', 'Juan López'],
        year: '2018',
      );

      service.setItems([testItem1, testItem2, testItem3]);

      // Querying without accents
      final partelResults = service.search('partel');
      expect(partelResults.length, equals(1));
      expect(partelResults.first.key, equals('partel2002dark'));

      final schrodingerResults = service.search('schrodinger');
      expect(schrodingerResults.length, equals(1));
      expect(schrodingerResults.first.key, equals('schrodinger1935cat'));

      final garciaResults = service.search('garcia');
      expect(garciaResults.length, equals(1));
      expect(garciaResults.first.key, equals('garcia2018gene'));

      // Querying with accents
      final accentedSearch = service.search('pärtel');
      expect(accentedSearch.length, equals(1));
      expect(accentedSearch.first.key, equals('partel2002dark'));

      // Multi-word and token matching
      final multiToken = service.search('meelis dark');
      expect(multiToken.length, equals(1));
      expect(multiToken.first.key, equals('partel2002dark'));
    });
  });
}
