import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/ui/theme/app_theme.dart';
import 'package:draftdown/ui/widgets/markdown_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders citations and latex formulas in MarkdownPreviewView', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    const markdown = '''
# Literature & Theory

According to [@moreno-mateosLongtermRestorationEcosystem2020], ecosystem recovery is non-linear.
Furthermore, as demonstrated by @holling1973resilience [p. 15], ecological systems absorb disturbance.

The energy-mass equivalence is expressed as \$E = mc^2\$.

The quadratic formula is given by:
\$\$\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$\$
''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPreviewView(markdown: markdown, controller: controller),
        ),
      ),
    );
    await tester.pump();

    // Verify LaTeX Math is rendered
    expect(find.byType(Math), findsWidgets);

    // Verify citations are rendered in-place as formatted academic citations
    expect(find.textContaining('Moreno-Mateos'), findsWidgets);
    expect(find.textContaining('Holling'), findsWidgets);

    // Verify bibliography section was generated cleanly
    expect(find.textContaining('References'), findsWidgets);
    expect(find.textContaining("Instance of 'CitationItem'"), findsNothing);
    expect(find.textContaining('Unknown author'), findsNothing);
  });

  testWidgets(
    'renders bibliography item with venue and DOI without interpolation defects',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();

      // Load a custom citation into bibliography
      final parsed = controller.bibliographyService.parseBibTeX('''
@article{moreno-mateosLongtermRestorationEcosystem2020,
  title = {The long-term restoration of ecosystem complexity},
  author = {Moreno-Mateos, David and Alberdi, Antton},
  journal = {Nature Ecology & Evolution},
  year = {2020},
  doi = {10.1038/s41559-020-1154-1}
}
''');
      controller.bibliographyService.setItems(parsed);

      const markdown = '[@moreno-mateosLongtermRestorationEcosystem2020]';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: markdown,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify no 'Instance of CitationItem' or 'Unknown author' in rendered output
      expect(find.textContaining("Instance of 'CitationItem'"), findsNothing);
      expect(find.textContaining('Unknown author'), findsNothing);
      expect(find.textContaining('Nature Ecology & Evolution'), findsWidgets);
      expect(find.textContaining('10.1038/s41559-020-1154-1'), findsWidgets);
    },
  );

  testWidgets(
    'renders numeric citations and numbered bibliography in MarkdownPreviewView',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      await controller.setCslStyle('ieee');

      const markdown = '''
Foundational models include [@holling1973resilience] and [@hutchinson1957concluding].
Another reference to @holling1973resilience is cited here.
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: markdown,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify numeric citations in text
      expect(find.textContaining('[1]'), findsWidgets);
      expect(find.textContaining('[2]'), findsWidgets);

      // Verify references section with numbered entries
      expect(find.textContaining('References'), findsWidgets);
      expect(find.textContaining('Holling, C. S.'), findsWidgets);
      expect(find.textContaining('Hutchinson, G. E.'), findsWidgets);
    },
  );

  testWidgets(
    'renders more than 10 authors with first 6 and et al in standard APA bibliography format',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();

      final parsed = controller.bibliographyService.parseBibTeX('''
@article{zizka2019coordinatecleaner,
  title = {CoordinateCleaner: Automated cleaning of occurrence records from biological collection databases},
  author = {Zizka, Alexander and Silvestro, Daniele and Andermann, Tobias and Azevedo, Josué and Duarte Ritter, Camila and Edler, Daniel and Farooq, Harith and Herdean, Andrei and Ariza, María and Scharn, Ruud and Svantesson, Sten and Wengström, Niklas and Zizka, Vera and Antonelli, Alexandre},
  journal = {Methods in Ecology and Evolution},
  volume = {10},
  number = {5},
  pages = {744--751},
  year = {2019},
  doi = {10.1111/2041-210X.13152}
}
''');
      controller.bibliographyService.setItems(parsed);

      const markdown = '[@zizka2019coordinatecleaner]';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: markdown,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining(
          'Zizka, A., Silvestro, D., Andermann, T., Azevedo, J., Ritter, C. D., Edler, D., et al.',
        ),
        findsWidgets,
      );
      expect(find.textContaining('Farooq, H.'), findsNothing);
      expect(find.textContaining('Antonelli, A.'), findsNothing);
      expect(find.textContaining('10(5), 744–751'), findsWidgets);
      expect(
        find.textContaining('https://doi.org/10.1111/2041-210X.13152'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'renders floating word processor page layout with shadow, border, and paper constraints',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();

      const markdown =
          '# Document Title\n\nParagraph text for testing page presentation.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: markdown,
              controller: controller,
              isFullView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify CustomScrollView for virtualised page scrolling
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify DecoratedSliver page decoration with border and maxWidth: 850.0
      final pageSliverFinder = find.byWidgetPredicate((widget) {
        if (widget is DecoratedSliver && widget.decoration is BoxDecoration) {
          final dec = widget.decoration as BoxDecoration;
          return dec.border != null;
        }
        return false;
      });
      expect(pageSliverFinder, findsOneWidget);
      expect(
        tester
            .renderObject<RenderSliver>(pageSliverFinder)
            .constraints
            .crossAxisExtent,
        equals(850.0),
      );

      // Verify rendered content inside MarkdownBody
      expect(find.textContaining('Document Title'), findsOneWidget);
      expect(
        find.textContaining('Paragraph text for testing page presentation.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders local absolute image in MarkdownPreviewView', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('img_');
    final f = File('${temp.path}/t.png');
    f.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPreviewView(
            markdown: '![My Figure](${f.path} "Figure Title")',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Figure Title'), findsOneWidget);
    temp.deleteSync(recursive: true);
  });

  testWidgets(
    'renders local relative image using imageDirectory in MarkdownPreviewView',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('img_rel_');
      final f = File('${temp.path}/rel.png');
      f.writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: '![Relative Figure](rel.png "Relative Caption")',
              imageDirectory: temp.path,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('Relative Caption'), findsOneWidget);
      temp.deleteSync(recursive: true);
    },
  );

  testWidgets('renders data URI base64 image in MarkdownPreviewView', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreviewView(
            markdown: '![Data Pixel](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg== "Pixel Caption")',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Pixel Caption'), findsOneWidget);
  });

  testWidgets('converts and renders HTML img tags in MarkdownPreviewView', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('img_html_');
    final f = File('${temp.path}/html.png');
    f.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPreviewView(
            markdown: '<img src="html.png" alt="HTML Figure" title="HTML Title" width="300" height="180" />',
            imageDirectory: temp.path,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('HTML Title'), findsOneWidget);

    final sizedBoxFinder = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 300.0 && w.height == 180.0,
    );
    expect(sizedBoxFinder, findsOneWidget);

    temp.deleteSync(recursive: true);
  });

  testWidgets(
    'renders elegant placeholder when image is missing in MarkdownPreviewView',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: '![Missing Chart](nonexistent_chart.png)',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.textContaining('Image: Missing Chart'), findsOneWidget);
      expect(find.textContaining('nonexistent_chart.png'), findsOneWidget);
    },
  );

  testWidgets(
    'renders full width page in preview pane even when document is empty',
    (tester) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(markdown: '', isFullView: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Document is empty.'), findsOneWidget);

      // In split view (isFullView: false), desk horizontal padding is 16 on each side (32 total).
      // The page sliver should take full width of available space: 700 - 32 = 668.0.
      final pageSliverFinder = find.byWidgetPredicate(
        (w) =>
            w is DecoratedSliver &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null,
      );
      expect(pageSliverFinder, findsOneWidget);
      final crossAxisExtent = tester
          .renderObject<RenderSliver>(pageSliverFinder)
          .constraints
          .crossAxisExtent;
      expect(crossAxisExtent, equals(668.0));
    },
  );

  testWidgets(
    'renders visible checkbox in task lists in both light and dark modes',
    (tester) async {
      const markdown = '''
- [ ] Buy groceries
- [x] Finished task
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MarkdownPreviewView(markdown: markdown)),
        ),
      );
      await tester.pump();

      // Verify both blank and checked checkboxes are rendered cleanly
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.textContaining('Buy groceries'), findsOneWidget);
      expect(find.textContaining('Finished task'), findsOneWidget);

      final uncheckedIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_box_outline_blank),
      );
      expect(uncheckedIcon.color, isNotNull);
      // Unchecked checkbox icon must not be transparent or match dark surface
      expect(uncheckedIcon.color, isNot(equals(AppTheme.darkPreviewPage)));
    },
  );

  testWidgets(
    'clicking checkbox in preview updates markdown from [ ] to [x] and vice versa',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      const initialMarkdown = '''
# Checklist
- [ ] Task alpha
- [x] Task beta
''';
      controller.textController.text = initialMarkdown;
      controller.flushPendingRenderUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => MarkdownPreviewView(
                markdown: controller.previewMarkdown,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(controller.content, equals(initialMarkdown));

      // Tap the unchecked checkbox in the preview pane
      await tester.tap(find.byIcon(Icons.check_box_outline_blank));
      await tester.pump();

      // Markdown in the controller is updated from [ ] to [x]!
      expect(controller.content, contains('- [x] Task alpha'));
      expect(controller.previewMarkdown, contains('- [x] Task alpha'));
      // Both checkboxes are now checked
      expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));

      // Tap the first checkbox again to toggle back to [ ]
      await tester.tap(find.byIcon(Icons.check_box).first);
      await tester.pump();

      // Markdown in the controller is reverted back to [ ]
      expect(controller.content, contains('- [ ] Task alpha'));
      expect(controller.previewMarkdown, contains('- [ ] Task alpha'));
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
    },
  );

  test('EditorController findTaskCheckboxes correctly identifies task list items and skips code blocks', () {
    const text = '''
# Header
- [ ] Item 1
  * [x] Indented item 2
1. [ ] Ordered item 3
> - [x] Quoted item 4
```markdown
- [ ] This is in a code block
```
Normal text [ ] not a checkbox
''';

    final checkboxes = EditorController.findTaskCheckboxes(text);
    expect(checkboxes.length, equals(4));
    expect(checkboxes[0].isChecked, isFalse);
    expect(checkboxes[1].isChecked, isTrue);
    expect(checkboxes[2].isChecked, isFalse);
    expect(checkboxes[3].isChecked, isTrue);
  });

  testWidgets(
    'renders superscript and subscript using both Pandoc and HTML syntax in MarkdownPreviewView',
    (tester) async {
      const markdown = '''
Pandoc Author: David Y. Shen^1,2^
Pandoc Chemical: H~2~O
HTML Author: Alice Smith<sup>3,4</sup>
HTML Chemical: CO<sub>2</sub>
Strikethrough: ~~deleted text~~
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MarkdownPreviewView(markdown: markdown)),
        ),
      );
      await tester.pump();

      // The raw HTML tags and Pandoc delimiter markers should not be rendered as literal text
      expect(find.textContaining('<sup>'), findsNothing);
      expect(find.textContaining('</sup>'), findsNothing);
      expect(find.textContaining('<sub>'), findsNothing);
      expect(find.textContaining('</sub>'), findsNothing);
      expect(find.textContaining('^1,2^'), findsNothing);
      expect(find.textContaining('~2~'), findsNothing);

      // Superscript and subscript contents should be rendered
      expect(find.text('1,2'), findsOneWidget);
      expect(find.text('3,4'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));

      // Strikethrough text should still be present and not broken by subscript
      expect(find.textContaining('deleted text'), findsOneWidget);

      // Verify superscript and subscript widgets are shifted up/down via Transform
      final transformFinders = find.byType(Transform);
      expect(transformFinders, findsWidgets);
    },
  );

  testWidgets(
    'MarkdownPreviewView virtualises blocks with SliverAstMarkdownList and preserves checkbox indices',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      const markdown = '''
- [ ] First task

Some paragraph in between.

- [ ] Second task
''';
      controller.textController.text = markdown;
      controller.flushPendingRenderUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: controller.previewMarkdown,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverAstMarkdownList), findsOneWidget);

      final checkboxes = find.byIcon(Icons.check_box_outline_blank);
      expect(checkboxes, findsNWidgets(2));

      // Tap the second checkbox and verify only the second task is toggled
      await tester.tap(checkboxes.at(1));
      await tester.pump();

      expect(controller.content, contains('- [ ] First task'));
      expect(controller.content, contains('- [x] Second task'));
    },
  );

  testWidgets(
    'Inline citations and inline LaTeX merge into surrounding RichText without forcing line breaks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      const markdown =
          'Both sub-models evaluate (\$f(\\mathbf{X})\$), while persistence [@partel2011]. Next sentence.';
      controller.textController.text = markdown;
      controller.flushPendingRenderUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewView(
              markdown: controller.previewMarkdown,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // The paragraph should be merged into a single RichText (via Text.rich)
      // containing the surrounding text and WidgetSpans for inline math & citation.
      final mergedTextFinder = find.byWidgetPredicate((w) {
        if (w is RichText && w.text is TextSpan) {
          final plain = w.text.toPlainText();
          return plain.contains('Both sub-models evaluate (') &&
              plain.contains('), while persistence ') &&
              plain.contains('. Next sentence.');
        }
        return false;
      });
      expect(mergedTextFinder, findsOneWidget);
    },
  );
}
