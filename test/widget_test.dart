import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdwriter/controllers/editor_controller.dart';
import 'package:mdwriter/models/citation_item.dart';
import 'package:mdwriter/main.dart';
import 'package:mdwriter/ui/theme/app_theme.dart';
import 'package:mdwriter/ui/widgets/citation_dialog.dart';
import 'package:mdwriter/ui/widgets/editor_view.dart';
import 'package:mdwriter/ui/widgets/export_dialog.dart';
import 'package:mdwriter/ui/widgets/settings_dialog.dart';
import 'package:mdwriter/ui/widgets/toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MDWriterApp smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));

    expect(find.text('MDWriter'), findsWidgets);
  });

  testWidgets('Markdown editor text field uses monospace font',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));

    final editorTextFieldFinder = find.descendant(
      of: find.byType(EditorView),
      matching: find.byType(TextField),
    );
    expect(editorTextFieldFinder, findsOneWidget);

    final textField = tester.widget<TextField>(editorTextFieldFinder);
    expect(textField.style?.fontFamily, equals(AppTheme.editorFontFamily));
    expect(textField.style?.fontFamilyFallback,
        equals(AppTheme.editorFontFamilyFallback));
  });

  testWidgets('EditorView updates monospace font when typography changes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));

    final editorTextFieldFinder = find.descendant(
      of: find.byType(EditorView),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(editorTextFieldFinder).style?.fontFamily,
      equals('Consolas'),
    );

    await controller.updateTypography(editorFontFamily: 'Courier New');
    await tester.pump();

    expect(
      tester.widget<TextField>(editorTextFieldFinder).style?.fontFamily,
      equals('Courier New'),
    );
  });

  testWidgets('Line numbers gutter synchronises when editor is scrolled',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    // Populate with 200 lines to ensure a long scrollable document
    controller.textController.text =
        List.generate(200, (i) => 'Line ${i + 1}: Paragraph content here').join('\n');

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));

    expect(controller.scrollController.hasClients, isTrue);
    expect(controller.scrollController.offset, equals(0.0));

    // Scroll down by 500 pixels
    controller.scrollController.jumpTo(500.0);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify offset is maintained and gutter custom paint reflects the offset
    expect(controller.scrollController.offset, equals(500.0));
    final customPaintFinder = find.descendant(
      of: find.byType(EditorView),
      matching: find.byType(CustomPaint),
    );
    expect(customPaintFinder, findsWidgets);
  });

  testWidgets('Citation dialog switches between BibTeX and Zotero sources',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: CitationDialog(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();

    // Default source is BibTeX
    expect(find.text('BibTeX (.bib)'), findsWidgets);
    expect(find.text('Zotero'), findsOneWidget);
    expect(find.text('@turing1950computing'), findsOneWidget);

    // Click Zotero source button
    await tester.tap(find.text('Zotero'));
    await tester.pumpAndSettle();

    // Should display Zotero citation keys and titles
    expect(find.text('@vaswani2017attention'), findsOneWidget);
    expect(find.text('Attention Is All You Need'), findsWidgets);

    // Select the Zotero item and insert
    await tester.tap(find.text('@vaswani2017attention'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insert Citation'));
    await tester.pumpAndSettle();

    // Verify controller inserted Zotero citation key
    expect(controller.textController.text, contains('[@vaswani2017attention]'));
  });

  testWidgets('Sidebar history item renders without assertion errors',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);
    await controller.historyService.recordFileOpen('test.md');

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify history item is rendered without assertion errors
    expect(find.text('test.md'), findsWidgets);
  });

  testWidgets(
      'Citation dialog keyboard navigation: search, arrows, space/enter select and apply',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: CitationDialog(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Immediately type a search query without clicking
    await tester.enterText(find.byType(TextField).first, 'turing');
    await tester.pumpAndSettle();

    // Verify turing item is shown
    expect(find.text('@turing1950computing'), findsWidgets);

    // Press Enter to select the entry
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // The search field should now be cleared
    final searchField = tester.widget<TextField>(find.byType(TextField).first);
    expect(searchField.controller?.text, isEmpty);

    // Selected basket should now display the citation
    expect(find.text('Selected (1):'), findsOneWidget);

    // 2. Search for a second citation
    await tester.enterText(find.byType(TextField).first, 'shannon');
    await tester.pumpAndSettle();
    expect(find.text('@shannon1948mathematical'), findsWidgets);

    // Press Enter to select the second entry
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Selected (2):'), findsOneWidget);
    expect(searchField.controller?.text, isEmpty);

    // 3. Search for a third citation (verifying 3+ citations can be selected without closing)
    await tester.enterText(find.byType(TextField).first, 'restoration');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Selected (3):'), findsOneWidget);
    expect(searchField.controller?.text, isEmpty);

    // 4. Press Enter on blank search query to apply all 3 citations
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // All 3 citations applied to editor controller in bracketed Pandoc format
    expect(
        controller.content,
        equals(
            '[@turing1950computing; @shannon1948mathematical; @moreno-mateosLongtermRestorationEcosystem2020]'));
  });

  testWidgets(
      'Citation dialog does not auto-select first citation, hides selected item from list, and confirms on Enter',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    bool dialogClosed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (_) => CitationDialog(controller: controller),
            );
            dialogClosed = true;
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Open dialogue
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CitationDialog), findsOneWidget);

    // 1. Verify nothing is selected initially
    expect(find.text('Selected (1):'), findsNothing);

    // Pressing Enter when no item is highlighted does NOT automatically select
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(dialogClosed, isFalse);
    expect(find.text('Selected (1):'), findsNothing);

    // 2. Press Down Arrow to navigate to and highlight the first citation
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Press Enter to select the highlighted entry
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Dialogue remains open, citation is added to Selected (1):
    expect(dialogClosed, isFalse);
    expect(find.text('Selected (1):'), findsOneWidget);

    // The selected item is now hidden from the available list
    // (chips show @turing1950computing in the basket, but not as an unselected available item)

    // 3. Press Enter again on blank query with cleared selection to apply
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
    expect(controller.content, contains('[@turing1950computing]'));
  });

  testWidgets(
      'Citation dialog closes on Escape key',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    bool dialogClosed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (_) => CitationDialog(controller: controller),
            );
            dialogClosed = true;
          },
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Open dialogue
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CitationDialog), findsOneWidget);

    // Press Escape to dismiss dialogue
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
    expect(controller.content, isEmpty);
  });

  testWidgets(
      'Citation dialog renders very long citation keys without layout overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    // Add a citation with an exceptionally long citekey
    controller.bibliographyService.setItems([
      const CitationItem(
        key:
            'galatowitschPredictingRestorationOutcomesBasedOnOrganisationalFrameworks2020',
        title:
            'Predicting restoration outcomes based on organizational frameworks',
        authors: ['Susan Galatowitsch', 'Julia Bohnen'],
        year: '2020',
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: Scaffold(
        body: CitationDialog(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify it renders cleanly without throwing RenderFlex overflow errors
    expect(tester.takeException(), isNull);
    expect(find.byType(CitationDialog), findsOneWidget);
  });

  testWidgets(
      'Citation dialog recognises existing citation at cursor and updates in-place',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);
    controller.textController.text =
        'Study [@asdfsdf, @asdfasdf, @ghjghj] carefully.';
    // Set cursor at index 20 (middle of citation)
    controller.textController.selection =
        const TextSelection.collapsed(offset: 20);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: CitationDialog(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify dialogue recognises it as an edit session
    expect(find.text('Edit Literature Citation'), findsOneWidget);
    expect(find.text('Selected (3):'), findsOneWidget);
    expect(find.text('@asdfsdf'), findsWidgets);
    expect(find.text('@asdfasdf'), findsWidgets);
    expect(find.text('@ghjghj'), findsWidgets);
    expect(find.text('Update Citations (3)'), findsOneWidget);

    // Apply update
    await tester.tap(find.text('Update Citations (3)'));
    await tester.pumpAndSettle();

    // Document text updated in-place with standardized Pandoc formatting
    expect(controller.content,
        equals('Study [@asdfsdf; @asdfasdf; @ghjghj] carefully.'));
  });

  testWidgets(
      'Export dialog displays page size dropdown with A4 by default and allows selecting Letter',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: ExportDialog(
          controller: controller,
          onOpenSettings: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Pandoc details are hidden and user-friendly labels are displayed
    expect(find.text('Export Document'), findsOneWidget);
    expect(find.text('Export Document with Pandoc'), findsNothing);
    expect(find.textContaining('Pandoc executable was not detected'), findsNothing);
    expect(find.text('Include Citations & References'), findsOneWidget);
    expect(find.text('Standalone Document'), findsOneWidget);
    expect(find.text('Table of Contents'), findsOneWidget);
    expect(find.text('Advanced Options'), findsOneWidget);

    // Verify PDF is selected by default and Page Size dropdown is visible with A4
    expect(find.text('Page Size:'), findsOneWidget);
    final dropdownFinder = find.byKey(const ValueKey('page-size-dropdown'));
    expect(dropdownFinder, findsOneWidget);
    expect(find.text('A4'), findsOneWidget);

    // Tap the dropdown to open it and select Letter
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    expect(find.text('Letter').last, findsOneWidget);
    await tester.tap(find.text('Letter').last);
    await tester.pumpAndSettle();

    // Verify Letter is now selected
    expect(find.text('Letter'), findsOneWidget);

    // Verify Margins dropdown is visible for PDF and defaults to Medium
    expect(find.text('Margins:'), findsOneWidget);
    final marginDropdownFinder = find.byKey(const ValueKey('margin-size-dropdown'));
    expect(marginDropdownFinder, findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);

    // Tap margins dropdown and select Thin
    await tester.tap(marginDropdownFinder);
    await tester.pumpAndSettle();

    expect(find.text('Thin').last, findsOneWidget);
    await tester.tap(find.text('Thin').last);
    await tester.pumpAndSettle();
    expect(find.text('Thin'), findsOneWidget);

    // Tap margins dropdown and select Thick
    await tester.tap(marginDropdownFinder);
    await tester.pumpAndSettle();

    expect(find.text('Thick').last, findsOneWidget);
    await tester.tap(find.text('Thick').last);
    await tester.pumpAndSettle();
    expect(find.text('Thick'), findsOneWidget);

    // Switch to non-PDF format (Microsoft Word) and verify PDF-only options are hidden
    await tester.tap(find.text('Microsoft Word'));
    await tester.pumpAndSettle();

    expect(find.text('Page Size:'), findsNothing);
    expect(find.text('Margins:'), findsNothing);
    expect(find.byKey(const ValueKey('page-size-dropdown')), findsNothing);
    expect(find.byKey(const ValueKey('margin-size-dropdown')), findsNothing);

    // Switch back to PDF Document and verify they reappear
    await tester.tap(find.text('PDF Document'));
    await tester.pumpAndSettle();

    expect(find.text('Page Size:'), findsOneWidget);
    expect(find.text('Margins:'), findsOneWidget);
  });

  testWidgets(
      'Editor waits 1.5 seconds of typing inactivity before automatically updating the render, with centred views and right-aligned export',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);
    controller.newFile();

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));
    await tester.pump();

    // Initially unmodified: no manual update render button
    expect(controller.isModified, isFalse);
    expect(find.byKey(const ValueKey('update-render-button')), findsNothing);

    final editorTextFieldFinder = find.descendant(
      of: find.byType(EditorView),
      matching: find.byType(TextField),
    );

    // First typing entry
    await tester.enterText(editorTextFieldFinder, '# Initial Heading\n\nFirst typed line.');
    await tester.pump();

    // File is now modified: update render button is completely removed
    expect(controller.isModified, isTrue);
    expect(find.byKey(const ValueKey('update-render-button')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));

    // Editor content has updated immediately, but render has not yet updated after 1.0s
    expect(controller.content, equals('# Initial Heading\n\nFirst typed line.'));
    expect(controller.previewMarkdown, isEmpty);
    expect(controller.isRenderPending, isTrue);

    // Type again at 1.0s (before the 1.5s window completes) to verify timer resets
    await tester.enterText(
      editorTextFieldFinder,
      '# Initial Heading\n\nFirst typed line. Second typed sentence.',
    );

    // 1.0 second after the second entry (2.0s total elapsed, but only 1.0s idle): still waiting
    await tester.pump(const Duration(milliseconds: 1000));
    expect(controller.previewMarkdown, isEmpty);
    expect(controller.isRenderPending, isTrue);

    // Complete the remaining 0.5s of the 1.5s inactivity period: automatically updates
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.isRenderPending, isFalse);
    expect(
      controller.previewMarkdown,
      equals('# Initial Heading\n\nFirst typed line. Second typed sentence.'),
    );

    // Verify top bar layout: 3 view modes centred in toolbar, export on the far right
    expect(find.byType(SegmentedButton<EditorViewMode>), findsOneWidget);
    final toolbarCenter = tester.getCenter(find.byType(AppToolbar));
    final segmentedCenter = tester.getCenter(find.byType(SegmentedButton<EditorViewMode>));
    expect(segmentedCenter.dx, closeTo(toolbarCenter.dx, 1.0));

    // Settings and colour mode are to the left of the export button, collectively right-aligned
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Export'), findsOneWidget);

    final settingsRight = tester.getTopRight(find.byIcon(Icons.settings_outlined)).dx;
    final themeRight = tester.getTopRight(find.byIcon(Icons.dark_mode_outlined)).dx;
    final exportLeft = tester.getTopLeft(find.widgetWithText(FilledButton, 'Export')).dx;

    expect(settingsRight, lessThan(themeRight));
    expect(themeRight, lessThan(exportLeft));

    // Top bar does not have redundant citation button
    expect(find.widgetWithText(FilledButton, 'Citation'), findsNothing);

    // 2nd row formatting bar contains the highlighted @ citation button and super/subscript buttons
    expect(find.byIcon(Icons.alternate_email), findsOneWidget);
    expect(find.byIcon(Icons.superscript), findsOneWidget);
    expect(find.byIcon(Icons.subscript), findsOneWidget);

    // Test superscript button insertion (Pandoc ^text^ style)
    await tester.tap(find.byIcon(Icons.superscript));
    await tester.pump();
    expect(controller.content, contains('^^'));

    // Test subscript button insertion (Pandoc ~text~ style)
    await tester.tap(find.byIcon(Icons.subscript));
    await tester.pump();
    expect(controller.content, contains('~~'));

    // Flush debounce timer before teardown
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets(
      'Settings dialog displays colour scheme dropdown and switches dark mode palettes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: true,
    ));
    await tester.pump();

    // Open Settings dialog via SettingsDialog widget
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: Scaffold(
        body: SettingsDialog(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();

    final schemeDropdown = find.byKey(const ValueKey('colour-scheme-dropdown'));
    expect(schemeDropdown, findsOneWidget);
    expect(find.text('Slate Navy (Default Dark)'), findsOneWidget);

    // Open dropdown and select Dracula (Dark)
    await tester.tap(schemeDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Dracula (Dark)').last, findsOneWidget);
    expect(find.text('Tokyo Night (Dark)').last, findsOneWidget);
    expect(find.text('Catppuccin Mocha (Dark)').last, findsOneWidget);
    expect(find.text('Nord Polar Night (Dark)').last, findsOneWidget);

    await tester.tap(find.text('Dracula (Dark)').last);
    await tester.pumpAndSettle();

    expect(controller.darkSchemeId, equals('dracula'));
    expect(controller.isDarkMode, isTrue);
    expect(AppTheme.activeDarkScheme.id, equals('dracula'));
  });

  testWidgets(
      'Editor scrolling is preserved and seamless while background rendering occurs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);
    controller.newFile();

    await tester.pumpWidget(MDWriterApp(
      controller: controller,
      initialDarkMode: false,
    ));
    await tester.pump();

    final editorTextFieldFinder = find.descendant(
      of: find.byType(EditorView),
      matching: find.byType(TextField),
    );

    // Enter a long multi-line text to allow scrolling
    final buffer = StringBuffer();
    for (int i = 1; i <= 200; i++) {
      buffer.writeln('Line $i: Content for testing smooth scrolling during background renders.');
    }
    await tester.enterText(editorTextFieldFinder, buffer.toString());
    await tester.pump();

    // Scroll down in the editor
    await tester.drag(editorTextFieldFinder, const Offset(0, -300));
    await tester.pump();

    final scrollOffsetBeforeRender = controller.scrollController.offset;
    expect(scrollOffsetBeforeRender, greaterThan(100.0));

    // Advance clock past the 1.5-second debounce window to trigger background render
    await tester.pump(const Duration(milliseconds: 1600));

    // The scroll offset in the editor is completely preserved!
    expect(controller.scrollController.offset, equals(scrollOffsetBeforeRender));

    // Scrolling down further continues seamlessly without jumping or resetting
    await tester.drag(editorTextFieldFinder, const Offset(0, -200));
    await tester.pump();

    expect(controller.scrollController.offset, greaterThan(scrollOffsetBeforeRender));
  });
}
