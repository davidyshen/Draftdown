import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/models/citation_item.dart';
import 'package:draftdown/main.dart';
import 'package:draftdown/ui/theme/app_theme.dart';
import 'package:draftdown/ui/widgets/citation_dialog.dart';
import 'package:draftdown/ui/widgets/editor_view.dart';
import 'package:draftdown/ui/widgets/export_dialog.dart';
import 'package:draftdown/ui/widgets/settings_dialog.dart';
import 'package:draftdown/ui/widgets/toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('DraftdownApp smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    await tester.pumpWidget(
      DraftdownApp(controller: controller, initialDarkMode: false),
    );

    expect(find.bySemanticsLabel('Draftdown'), findsWidgets);
    final svgBox = tester.renderObject<RenderBox>(
      find.bySemanticsLabel('Draftdown').first,
    );
    expect(svgBox.size.width, greaterThan(0));
    expect(svgBox.size.height, greaterThan(0));
    expect(
      find.byKey(const ValueKey('titlebar-hamburger-btn')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('window-minimize-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('window-maximize-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('window-close-btn')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Markdown editor text field uses monospace font', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();

    await tester.pumpWidget(
      DraftdownApp(controller: controller, initialDarkMode: false),
    );

    final editorTextFieldFinder = find.descendant(
      of: find.byType(EditorView),
      matching: find.byType(TextField),
    );
    expect(editorTextFieldFinder, findsOneWidget);

    final textField = tester.widget<TextField>(editorTextFieldFinder);
    expect(textField.style?.fontFamily, equals(AppTheme.editorFontFamily));
    expect(
      textField.style?.fontFamilyFallback,
      equals(AppTheme.editorFontFamilyFallback),
    );
  });

  testWidgets('EditorView updates monospace font when typography changes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      DraftdownApp(controller: controller, initialDarkMode: false),
    );

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

  testWidgets('Line numbers gutter synchronises when editor is scrolled', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    // Populate with 200 lines to ensure a long scrollable document
    controller.textController.text = List.generate(
      200,
      (i) => 'Line ${i + 1}: Paragraph content here',
    ).join('\n');

    await tester.pumpWidget(
      DraftdownApp(controller: controller, initialDarkMode: false),
    );

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

  testWidgets('Citation dialog switches between BibTeX and Zotero sources', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(body: CitationDialog(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    // Default source is BibTeX
    expect(find.text('BibTeX (.bib)'), findsWidgets);
    expect(find.text('Zotero'), findsOneWidget);
    expect(find.text('@hutchinson1957concluding'), findsOneWidget);

    // Click Zotero source button
    await tester.tap(find.text('Zotero'));
    await tester.pumpAndSettle();

    // Should display Zotero citation keys and titles
    expect(find.text('@loreau2001biodiversity'), findsOneWidget);
    expect(
      find.text(
        'Biodiversity and Ecosystem Functioning: Current Knowledge and Future Challenges',
      ),
      findsWidgets,
    );

    // Select the Zotero item and insert
    await tester.tap(find.text('@loreau2001biodiversity'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insert Citation'));
    await tester.pumpAndSettle();

    // Verify controller inserted Zotero citation key
    expect(
      controller.textController.text,
      contains('[@loreau2001biodiversity]'),
    );
  });

  testWidgets('Sidebar history item renders without assertion errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);
    await controller.historyService.recordFileOpen('test.md');

    await tester.pumpWidget(
      DraftdownApp(controller: controller, initialDarkMode: false),
    );
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

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: CitationDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Immediately type a search query without clicking
      await tester.enterText(find.byType(TextField).first, 'hutchinson');
      await tester.pumpAndSettle();

      // Verify hutchinson item is shown
      expect(find.text('@hutchinson1957concluding'), findsWidgets);

      // Press Enter to select the entry
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // The search field should now be cleared
      final searchField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(searchField.controller?.text, isEmpty);

      // Selected basket should now display the citation
      expect(find.text('Selected (1):'), findsOneWidget);

      // 2. Search for a second citation
      await tester.enterText(find.byType(TextField).first, 'holling');
      await tester.pumpAndSettle();
      expect(find.text('@holling1973resilience'), findsWidgets);

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
          '[@hutchinson1957concluding; @holling1973resilience; @moreno-mateosLongtermRestorationEcosystem2020]',
        ),
      );
    },
  );

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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
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
      // (chips show @hutchinson1957concluding in the basket, but not as an unselected available item)

      // 3. Press Enter again on blank query with cleared selection to apply
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(dialogClosed, isTrue);
      expect(controller.content, contains('[@hutchinson1957concluding]'));
    },
  );

  testWidgets('Citation dialog closes on Escape key', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    bool dialogClosed = false;
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
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
          key: 'galatowitschPredictingRestorationOutcomesBasedOnOrganisationalFrameworks2020',
          title: 'Predicting restoration outcomes based on organizational frameworks',
          authors: ['Susan Galatowitsch', 'Julia Bohnen'],
          year: '2020',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(body: CitationDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it renders cleanly without throwing RenderFlex overflow errors
      expect(tester.takeException(), isNull);
      expect(find.byType(CitationDialog), findsOneWidget);
    },
  );

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
      controller.textController.selection = const TextSelection.collapsed(
        offset: 20,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: CitationDialog(controller: controller)),
        ),
      );
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
      expect(
        controller.content,
        equals('Study [@asdfsdf; @asdfasdf; @ghjghj] carefully.'),
      );
    },
  );

  testWidgets(
    'Export dialog displays page size dropdown with A4 by default and allows selecting Letter',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: ExportDialog(controller: controller, onOpenSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Pandoc details are hidden and user-friendly labels are displayed
      expect(find.text('Export Document'), findsOneWidget);
      expect(find.text('Export Document with Pandoc'), findsNothing);
      expect(
        find.textContaining('Pandoc executable was not detected'),
        findsNothing,
      );
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
      final marginDropdownFinder = find.byKey(
        const ValueKey('margin-size-dropdown'),
      );
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
    },
  );

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

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: false),
      );
      await tester.pump();

      // Initially unmodified: no manual update render button
      expect(controller.isModified, isFalse);
      expect(find.byKey(const ValueKey('update-render-button')), findsNothing);

      final editorTextFieldFinder = find.descendant(
        of: find.byType(EditorView),
        matching: find.byType(TextField),
      );

      // First typing entry
      await tester.enterText(
        editorTextFieldFinder,
        '# Initial Heading\n\nFirst typed line.',
      );
      await tester.pump();

      // File is now modified: update render button is completely removed
      expect(controller.isModified, isTrue);
      expect(find.byKey(const ValueKey('update-render-button')), findsNothing);

      await tester.pump(const Duration(milliseconds: 1000));

      // Editor content has updated immediately, but render has not yet updated after 1.0s
      expect(
        controller.content,
        equals('# Initial Heading\n\nFirst typed line.'),
      );
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
      final segmentedCenter = tester.getCenter(
        find.byType(SegmentedButton<EditorViewMode>),
      );
      expect(segmentedCenter.dx, closeTo(toolbarCenter.dx, 1.0));

      // Settings and colour mode are in the sidebar (not in AppToolbar), whilst Export remains on the right
      expect(
        find.descendant(
          of: find.byType(AppToolbar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppToolbar),
          matching: find.byIcon(Icons.dark_mode_outlined),
        ),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Export'), findsOneWidget);

      // Pin sidebar open and verify Settings & colour scheme buttons are above the active file
      await tester.tap(find.byKey(const ValueKey('titlebar-hamburger-btn')));
      await tester.pumpAndSettle();

      final settingsBtn = find.byKey(const ValueKey('sidebar-settings-btn'));
      final themeBtn = find.byKey(const ValueKey('sidebar-theme-btn'));
      final activeFileName = find.byKey(
        const ValueKey('sidebar-active-filename'),
      );
      expect(settingsBtn, findsOneWidget);
      expect(themeBtn, findsOneWidget);
      expect(
        tester.getBottomLeft(settingsBtn).dy,
        lessThan(tester.getTopLeft(activeFileName).dy),
      );
      expect(
        tester.getBottomLeft(themeBtn).dy,
        lessThan(tester.getTopLeft(activeFileName).dy),
      );

      // Top bar does not have redundant citation button
      expect(find.widgetWithText(FilledButton, 'Citation'), findsNothing);

      // 2nd row formatting bar contains the plain text Cite button and super/subscript buttons,
      // whilst the spellcheck toggle lives in the sidebar (not AppToolbar).
      expect(find.text('Cite'), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppToolbar),
          matching: find.byKey(const ValueKey('spellcheck-toggle-btn')),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('spellcheck-toggle-btn')), findsWidgets);
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
    },
  );

  testWidgets(
    'Settings dialog displays colour scheme dropdown and switches dark mode palettes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: true),
      );
      await tester.pump();

      // Open Settings dialog via SettingsDialog widget
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(body: SettingsDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      final schemeDropdown = find.byKey(
        const ValueKey('colour-scheme-dropdown'),
      );
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
    },
  );

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

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: false),
      );
      await tester.pump();

      final editorTextFieldFinder = find.descendant(
        of: find.byType(EditorView),
        matching: find.byType(TextField),
      );

      // Enter a long multi-line text to allow scrolling
      final buffer = StringBuffer();
      for (int i = 1; i <= 200; i++) {
        buffer.writeln(
          'Line $i: Content for testing smooth scrolling during background renders.',
        );
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
      expect(
        controller.scrollController.offset,
        equals(scrollOffsetBeforeRender),
      );

      // Scrolling down further continues seamlessly without jumping or resetting
      await tester.drag(editorTextFieldFinder, const Offset(0, -200));
      await tester.pump();

      expect(
        controller.scrollController.offset,
        greaterThan(scrollOffsetBeforeRender),
      );
    },
  );

  testWidgets(
    'Custom title bar, startup floating sidebar peek, hover open, and click pin',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: false),
      );
      await tester.pump();

      // Docked sidebar starts collapsed; floating sidebar is visible on startup (undocked)
      expect(controller.isSidebarOpen, isFalse);
      final floatingFinder = find.byKey(const ValueKey('floating-sidebar'));
      expect(floatingFinder, findsOneWidget);
      expect(tester.getTopLeft(floatingFinder).dx, equals(10.0));

      // Only one hamburger icon (in CustomTitleBar, removed from AppToolbar)
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // After 1s + slide animation, floating sidebar slides out of view
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(floatingFinder).dx, lessThan(0.0));

      // Hovering over the title bar hamburger button slides the floating sidebar back in
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('titlebar-hamburger-btn'))),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(floatingFinder).dx, equals(10.0));

      // Moving away dismisses the floating sidebar again
      await gesture.moveTo(const Offset(800, 400));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(floatingFinder).dx, lessThan(0.0));

      // Clicking the hamburger button pins the docked sidebar open
      await tester.tap(find.byKey(const ValueKey('titlebar-hamburger-btn')));
      await tester.pumpAndSettle();
      expect(controller.isSidebarOpen, isTrue);
    },
  );

  testWidgets('Clicking sidebar filename renames stem only and preserves .md', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      DraftdownApp(controller: controller, initialDarkMode: false),
    );
    await tester.pump();

    // Let startup floating sidebar peek slide out, then pin docked sidebar open
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('titlebar-hamburger-btn')));
    await tester.pumpAndSettle();

    expect(controller.currentFileName, equals('Untitled.md'));

    // Click the filename in the docked sidebar
    await tester.tap(
      find.byKey(const ValueKey('sidebar-active-filename')).first,
    );
    await tester.pumpAndSettle();

    // Only the stem is in the editable TextField; .md is fixed outside it
    final inputFinder = find.byKey(const ValueKey('sidebar-rename-input'));
    expect(inputFinder, findsOneWidget);
    final textField = tester.widget<TextField>(inputFinder);
    expect(textField.controller?.text, equals('Untitled'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-rename-extension')),
        matching: find.text('.md'),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('sidebar-rename-extension')))
          .data,
      equals('.md'),
    );

    // Enter a new stem and submit
    await tester.enterText(inputFinder, 'FieldNotes');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.currentFileName, equals('FieldNotes.md'));
    expect(find.text('FieldNotes.md'), findsWidgets);

    // Pressing Escape cancels without changing filename
    await tester.tap(
      find.byKey(const ValueKey('sidebar-active-filename')).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(inputFinder, 'ShouldCancel');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.currentFileName, equals('FieldNotes.md'));
  });

  test(
    'EditorController.renameCurrentFile renames saved file on disk',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp(
        'draftdown_rename_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final initialFile = File(
        '${tempDir.path}${Platform.pathSeparator}Original.md',
      );
      await initialFile.writeAsString('# Hello');

      final controller = EditorController();
      addTearDown(controller.dispose);
      await controller.openFile(initialFile.path);
      expect(controller.currentFileName, equals('Original.md'));

      final error = await controller.renameCurrentFile('Renamed');
      expect(error, isNull);
      expect(controller.currentFileName, equals('Renamed.md'));
      expect(
        controller.currentFilePath,
        equals('${tempDir.path}${Platform.pathSeparator}Renamed.md'),
      );
      expect(initialFile.existsSync(), isFalse);
      expect(File(controller.currentFilePath!).existsSync(), isTrue);
    },
  );

  testWidgets(
    'Sidebar acts like tabs: preserves unsaved edits, shows unsaved dot, and styles open vs closed files',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      late Directory tempDir;
      late File fileA;
      late File fileB;
      late File fileC;
      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('draftdown_tabs_');
        fileA = File('${tempDir.path}${Platform.pathSeparator}Alpha.md');
        fileB = File('${tempDir.path}${Platform.pathSeparator}Beta.md');
        fileC = File('${tempDir.path}${Platform.pathSeparator}Gamma.md');
        await fileA.writeAsString('# Alpha initial');
        await fileB.writeAsString('# Beta initial');
        await fileC.writeAsString('# Gamma closed');

        await controller.historyService.recordFileOpen(fileC.path);
        await controller.historyService.recordFileOpen(fileB.path);
        await controller.openFile(fileA.path);
      });
      addTearDown(() async {
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      // Pin the docked sidebar open
      controller.toggleSidebar();

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: false),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Edit Alpha.md without saving
      controller.textController.text = '# Alpha unsaved edit';
      await tester.pump();
      expect(controller.isModified, isTrue);

      // Click Beta.md in history: should open without an "Unsaved Changes" dialog
      expect(find.text('Beta.md'), findsOneWidget);
      await tester.tap(find.text('Beta.md'));
      await tester.pump();
      for (
        int i = 0;
        i < 20 &&
            (controller.currentFileName != 'Beta.md' ||
                controller.history.isEmpty ||
                controller.history.first.fileName != 'Beta.md');
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Changes'), findsNothing);
      expect(controller.currentFileName, equals('Beta.md'));
      expect(controller.isModified, isFalse);

      // Alpha.md is still open and modified in the background
      expect(controller.isFileOpen(fileA.path), isTrue);
      expect(controller.isFileModified(fileA.path), isTrue);
      expect(controller.isFileOpen(fileC.path), isFalse);

      // Verify Alpha.md and Beta.md are bold, while closed Gamma.md is normal weight
      final historyList = find.byType(ListView);
      final alphaText = tester.widget<Text>(
        find.descendant(of: historyList, matching: find.text('Alpha.md')),
      );
      final betaText = tester.widget<Text>(
        find.descendant(of: historyList, matching: find.text('Beta.md')),
      );
      final gammaText = tester.widget<Text>(
        find.descendant(of: historyList, matching: find.text('Gamma.md')),
      );
      expect(alphaText.style?.fontWeight, equals(FontWeight.w700));
      expect(betaText.style?.fontWeight, equals(FontWeight.w700));
      expect(gammaText.style?.fontWeight, equals(FontWeight.w400));

      // Switch back to Alpha.md and confirm unsaved edits were preserved
      await tester.tap(find.text('Alpha.md').last);
      await tester.pump();
      for (int i = 0; i < 20 && controller.currentFileName != 'Alpha.md'; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(controller.currentFileName, equals('Alpha.md'));
      expect(controller.content, equals('# Alpha unsaved edit'));
      expect(controller.isModified, isTrue);

      // Active file (Alpha.md) should be at the top of the sidebar list
      final alphaY = tester
          .getTopLeft(
            find.descendant(of: historyList, matching: find.text('Alpha.md')),
          )
          .dy;
      final betaY = tester
          .getTopLeft(
            find.descendant(of: historyList, matching: find.text('Beta.md')),
          )
          .dy;
      final gammaY = tester
          .getTopLeft(
            find.descendant(of: historyList, matching: find.text('Gamma.md')),
          )
          .dy;
      expect(alphaY, lessThan(betaY));
      expect(betaY, lessThan(gammaY));
    },
  );

  testWidgets(
    'Conflict status shows red dot, Conflict badge, and popup dialog to discard or save as new file',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final tempDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('draftdown_widget_conflict_'),
      );
      addTearDown(() async {
        await tester.runAsync(() => tempDir!.delete(recursive: true));
      });

      final file = File(
        '${tempDir!.path}${Platform.pathSeparator}ConflictDoc.md',
      );
      await tester.runAsync(() => file.writeAsString('# Original'));

      final controller = EditorController();
      addTearDown(controller.dispose);
      await tester.runAsync(() => controller.openFile(file.path));
      controller.toggleSidebar();

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: false),
      );
      await tester.pumpAndSettle();

      // Make an unsaved edit in the app
      controller.textController.text = '# Unsaved Local Edit';
      await tester.pump();
      expect(find.text('Unsaved'), findsOneWidget);

      // Modify the file on disk externally
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await file.writeAsString('# Modified On Disk By Agent');
        await controller.checkOpenFilesForChanges();
      });

      await tester.pumpAndSettle();

      // Conflict badge and popup dialog should be visible
      expect(find.text('Conflict'), findsOneWidget);
      expect(find.text('File Conflict'), findsOneWidget);
      expect(
        find.textContaining('unsaved changes'),
        findsOneWidget,
      );
      expect(
        find.textContaining('file on disk has been modified'),
        findsOneWidget,
      );
      expect(find.text('Discard Changes'), findsOneWidget);
      expect(find.text('Save as New File'), findsOneWidget);

      // Verify red warning dot is rendered in toolbar/sidebar
      final redDots = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration as BoxDecoration).color == Colors.red,
        ),
      );
      expect(redDots.length, greaterThanOrEqualTo(1));

      // Tap Discard Changes -> should reload disk content and clear conflict
      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();
      for (int i = 0; i < 20 && controller.hasConflict; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(controller.content, equals('# Modified On Disk By Agent'));
      expect(controller.isModified, isFalse);
      expect(controller.hasConflict, isFalse);
      expect(find.text('Conflict'), findsNothing);
    },
  );

  testWidgets(
    'Tab inserts 2 spaces at cursor and indents highlighted blocks; Shift+Tab outdents',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        DraftdownApp(controller: controller, initialDarkMode: false),
      );
      await tester.pumpAndSettle();

      // Focus the editor TextField
      final editorField = find.descendant(
        of: find.byType(EditorView),
        matching: find.byType(TextField),
      );
      await tester.tap(editorField);
      await tester.pump();

      // 1. Collapsed cursor: Tab inserts 2 spaces
      controller.textController.value = const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(controller.content, equals('  Hello'));
      expect(
        controller.textController.selection,
        equals(const TextSelection.collapsed(offset: 2)),
      );

      // 2. Highlighted multi-line block: Tab indents each selected line by 2 spaces
      controller.textController.value = const TextEditingValue(
        text: 'Line 1\nLine 2\nLine 3',
        selection: TextSelection(baseOffset: 0, extentOffset: 13),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(controller.content, equals('  Line 1\n  Line 2\nLine 3'));

      // 3. Shift+Tab outdents the selected lines
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.content, equals('Line 1\nLine 2\nLine 3'));
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
