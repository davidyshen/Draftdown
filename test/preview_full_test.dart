import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:mdwriter/controllers/editor_controller.dart';
import 'package:mdwriter/ui/widgets/markdown_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders citations and latex formulas in MarkdownPreviewView', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    const markdown = '''
# Literature & Theory

According to [@moreno-mateosLongtermRestorationEcosystem2020], ecosystem recovery is non-linear.
Furthermore, as demonstrated by @turing1950computing [p. 433], computing machinery exhibits intelligence.

The energy-mass equivalence is expressed as \$E = mc^2\$.

The quadratic formula is given by:
\$\$\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$\$
''';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: markdown,
          controller: controller,
        ),
      ),
    ));
    await tester.pump();

    // Verify LaTeX Math is rendered
    expect(find.byType(Math), findsWidgets);

    // Verify citations are rendered in-place as formatted academic citations
    expect(find.textContaining('Moreno-Mateos'), findsWidgets);
    expect(find.textContaining('Turing'), findsWidgets);

    // Verify bibliography section was generated cleanly
    expect(find.textContaining('References'), findsWidgets);
    expect(find.textContaining("Instance of 'CitationItem'"), findsNothing);
    expect(find.textContaining('Unknown author'), findsNothing);
  });

  testWidgets('renders bibliography item with venue and DOI without interpolation defects', (tester) async {
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

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: markdown,
          controller: controller,
        ),
      ),
    ));
    await tester.pump();

    // Verify no 'Instance of CitationItem' or 'Unknown author' in rendered output
    expect(find.textContaining("Instance of 'CitationItem'"), findsNothing);
    expect(find.textContaining('Unknown author'), findsNothing);
    expect(find.textContaining('Nature Ecology & Evolution'), findsWidgets);
    expect(find.textContaining('10.1038/s41559-020-1154-1'), findsWidgets);
  });

  testWidgets('renders floating word processor page layout with shadow, border, and paper constraints',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    const markdown = '# Document Title\n\nParagraph text for testing page presentation.';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: markdown,
          controller: controller,
          isFullView: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify paper constraints: ConstrainedBox with maxWidth: 850
    final constrainedBoxFinder = find.byWidgetPredicate((widget) {
      if (widget is ConstrainedBox) {
        return widget.constraints.maxWidth == 850.0;
      }
      return false;
    });
    expect(constrainedBoxFinder, findsOneWidget);

    // Verify SingleChildScrollView for continuous page scrolling
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Verify paper Container decoration with border and drop shadow
    final paperContainerFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final dec = widget.decoration as BoxDecoration;
        return dec.border != null &&
            dec.boxShadow != null &&
            dec.boxShadow!.isNotEmpty;
      }
      return false;
    });
    expect(paperContainerFinder, findsWidgets);

    // Verify rendered content inside MarkdownBody
    expect(find.textContaining('Document Title'), findsOneWidget);
    expect(find.textContaining('Paragraph text for testing page presentation.'), findsOneWidget);
  });

  testWidgets('renders local absolute image in MarkdownPreviewView', (tester) async {
    final temp = Directory.systemTemp.createTempSync('img_');
    final f = File('${temp.path}/t.png');
    f.writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: '![My Figure](${f.path} "Figure Title")',
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Figure Title'), findsOneWidget);
    temp.deleteSync(recursive: true);
  });

  testWidgets('renders local relative image using imageDirectory in MarkdownPreviewView', (tester) async {
    final temp = Directory.systemTemp.createTempSync('img_rel_');
    final f = File('${temp.path}/rel.png');
    f.writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: '![Relative Figure](rel.png "Relative Caption")',
          imageDirectory: temp.path,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Relative Caption'), findsOneWidget);
    temp.deleteSync(recursive: true);
  });

  testWidgets('renders data URI base64 image in MarkdownPreviewView', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: '![Data Pixel](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg== "Pixel Caption")',
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Pixel Caption'), findsOneWidget);
  });

  testWidgets('converts and renders HTML img tags in MarkdownPreviewView', (tester) async {
    final temp = Directory.systemTemp.createTempSync('img_html_');
    final f = File('${temp.path}/html.png');
    f.writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: '<img src="html.png" alt="HTML Figure" title="HTML Title" width="300" height="180" />',
          imageDirectory: temp.path,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('HTML Title'), findsOneWidget);

    final sizedBoxFinder = find.byWidgetPredicate((w) => w is SizedBox && w.width == 300.0 && w.height == 180.0);
    expect(sizedBoxFinder, findsOneWidget);

    temp.deleteSync(recursive: true);
  });

  testWidgets('renders elegant placeholder when image is missing in MarkdownPreviewView', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MarkdownPreviewView(
          markdown: '![Missing Chart](nonexistent_chart.png)',
        ),
      ),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.textContaining('Image: Missing Chart'), findsOneWidget);
    expect(find.textContaining('nonexistent_chart.png'), findsOneWidget);
  });
}
