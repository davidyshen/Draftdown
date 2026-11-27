import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/ui/screens/main_screen.dart';
import 'package:draftdown/utils/markdown_outline_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MarkdownOutlineHelper', () {
    test('extracts ATX headings H1-H6 and ignores headings in code blocks', () {
      const md = '''
# Title One

Some intro paragraph.

```markdown
# Not a Heading
## Also Not a Heading
```

## Section **Two** with `code`

### Sub-section [Link](https://example.com)

#### Level 4
##### Level 5
###### Level 6 ##
''';

      final outline = MarkdownOutlineHelper.parse(md);
      expect(outline.headings.length, 6);

      expect(outline.headings[0].level, 1);
      expect(outline.headings[0].title, 'Title One');
      expect(outline.headings[0].lineIndex, 0);

      expect(outline.headings[1].level, 2);
      expect(outline.headings[1].title, 'Section Two with code');

      expect(outline.headings[2].level, 3);
      expect(outline.headings[2].title, 'Sub-section Link');

      expect(outline.headings[3].level, 4);
      expect(outline.headings[4].level, 5);
      expect(outline.headings[5].level, 6);
      expect(outline.headings[5].title, 'Level 6');
    });

    test('maps editor line indices to top-level block ranges', () {
      const md = '''
# Heading

First paragraph line 1
First paragraph line 2

- Item 1
- Item 2

## Second Heading
''';

      final outline = MarkdownOutlineHelper.parse(md);
      expect(outline.blockRanges.length, 4);

      final pos0 = MarkdownOutlineHelper.blockPositionForLine(
        outline.blockRanges,
        0,
      );
      expect(pos0.blockIndex, 0);

      final posPara = MarkdownOutlineHelper.blockPositionForLine(
        outline.blockRanges,
        3,
      );
      expect(posPara.blockIndex, 1);
      expect(posPara.fraction, greaterThan(0.0));

      final posLast = MarkdownOutlineHelper.blockPositionForLine(
        outline.blockRanges,
        8,
      );
      expect(posLast.blockIndex, 3);
    });
  });

  group('Scroll preservation, sidebar navigation, and sync scroll', () {
    String buildLongDocument() {
      final buffer = StringBuffer();
      for (int i = 1; i <= 15; i++) {
        buffer.writeln('# Heading $i');
        buffer.writeln();
        for (int p = 1; p <= 4; p++) {
          buffer.writeln(
            'Paragraph $p under heading $i with enough text to wrap and create substantial vertical scroll height in both the editor and the rendered preview pane.',
          );
          buffer.writeln();
        }
        if (i.isEven) {
          buffer.writeln('## Subheading $i.1');
          buffer.writeln();
          buffer.writeln('```dart\nvoid fn$i() {}\n```');
          buffer.writeln();
        }
      }
      return buffer.toString();
    }

    testWidgets(
      'preserves editor and preview scroll positions across view mode switches',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.textController.text = buildLongDocument();
        controller.flushPendingRenderUpdate();
        controller.setViewMode(EditorViewMode.edit);

        await tester.pumpWidget(
          MaterialApp(
            home: MainScreen(
              controller: controller,
              onToggleTheme: () {},
              isDarkMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll editor down
        controller.scrollController.jumpTo(350.0);
        await tester.pump();
        expect(controller.safeScrollOffset, closeTo(350.0, 1.0));
        final savedTopLine = controller.currentTopVisibleLine;

        // Switch Edit -> Preview -> Edit: editor top line must be preserved
        controller.setViewMode(EditorViewMode.preview);
        await tester.pumpAndSettle();

        controller.setViewMode(EditorViewMode.edit);
        await tester.pumpAndSettle();
        expect(controller.currentTopVisibleLine, savedTopLine);
        expect(controller.safeScrollOffset, greaterThan(0.0));

        // Scroll preview in Preview mode (with linked scrolling off so it stays independent)
        await controller.setLinkedScrolling(false);
        controller.setViewMode(EditorViewMode.preview);
        await tester.pumpAndSettle();
        controller.previewScrollController.jumpTo(420.0);
        await tester.pump();
        expect(controller.safePreviewScrollOffset, closeTo(420.0, 1.0));

        // Switch Preview -> Split -> Preview: preview scroll position must be preserved
        controller.setViewMode(EditorViewMode.split);
        await tester.pumpAndSettle();
        expect(controller.safePreviewScrollOffset, closeTo(420.0, 1.0));
      },
    );

    testWidgets(
      'switching between edit and split keeps the same logical line at the top of the editor',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.textController.text = buildLongDocument();
        controller.flushPendingRenderUpdate();
        controller.setViewMode(EditorViewMode.edit);

        await tester.pumpWidget(
          MaterialApp(
            home: MainScreen(
              controller: controller,
              onToggleTheme: () {},
              isDarkMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down in Edit mode so a specific logical line is at the top
        controller.scrollController.jumpTo(600.0);
        await tester.pump();
        final topLineInEdit = controller.currentTopVisibleLine;
        expect(topLineInEdit, greaterThan(5));

        // Switch Edit -> Split (width halves, wrapping increases): top logical line must match
        controller.setViewMode(EditorViewMode.split);
        await tester.pumpAndSettle();
        expect(
          (controller.currentTopVisibleLine - topLineInEdit).abs(),
          lessThanOrEqualTo(1),
        );

        // Switch Split -> Edit: top logical line must still match
        controller.setViewMode(EditorViewMode.edit);
        await tester.pumpAndSettle();
        expect(
          (controller.currentTopVisibleLine - topLineInEdit).abs(),
          lessThanOrEqualTo(1),
        );
      },
    );

    testWidgets(
      'preview maxScrollExtent remains stable while scrolling (no erratic scrollbar jumps)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.textController.text = buildLongDocument();
        controller.flushPendingRenderUpdate();
        controller.setViewMode(EditorViewMode.preview);

        await tester.pumpWidget(
          MaterialApp(
            home: MainScreen(
              controller: controller,
              onToggleTheme: () {},
              isDarkMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final initialMaxExtent =
            controller.activePreviewScrollPosition!.maxScrollExtent;
        expect(initialMaxExtent, greaterThan(500.0));

        // Scroll to multiple positions and verify maxScrollExtent does not fluctuate
        for (final fraction in [0.25, 0.5, 0.75, 1.0]) {
          controller.previewScrollController.jumpTo(
            initialMaxExtent * fraction,
          );
          await tester.pump();
          expect(
            controller.activePreviewScrollPosition!.maxScrollExtent,
            closeTo(initialMaxExtent, 0.5),
          );
        }
      },
    );

    testWidgets(
      'sidebar displays Navigation card, Sync scroll checkbox, no Zotero bar, and jumps on heading tap',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.textController.text = buildLongDocument();
        controller.flushPendingRenderUpdate();
        controller.toggleSidebar();

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 1280,
              height: 800,
              child: MainScreen(
                controller: controller,
                onToggleTheme: () {},
                isDarkMode: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zotero bar should be removed
        expect(find.byIcon(Icons.refresh), findsNothing);

        // Navigation card and Sync scroll checkbox should be present
        expect(
          find.byKey(const ValueKey('sidebar-navigation-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('sidebar-sync-scroll-checkbox')),
          findsOneWidget,
        );
        expect(find.text('Sync scroll'), findsOneWidget);
        expect(controller.isLinkedScrolling, isTrue);

        // Toggle Sync scroll checkbox
        await tester.tap(
          find.byKey(const ValueKey('sidebar-sync-scroll-checkbox')),
        );
        await tester.pumpAndSettle();
        expect(controller.isLinkedScrolling, isFalse);

        // Tap Heading 10 in Navigation card (scroll into view in sidebar first if needed)
        final headingFinder = find.text('Heading 10');
        await tester.scrollUntilVisible(
          headingFinder,
          100.0,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('sidebar-navigation-card')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(headingFinder);
        await tester.pumpAndSettle();

        expect(controller.safeScrollOffset, greaterThan(0.0));
        expect(controller.safePreviewScrollOffset, greaterThan(0.0));
      },
    );

    testWidgets(
      'editor-driven sync scroll updates preview when editor scrolls, but preview scroll never moves editor',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.textController.text = buildLongDocument();
        controller.flushPendingRenderUpdate();
        controller.setViewMode(EditorViewMode.split);

        await tester.pumpWidget(
          MaterialApp(
            home: MainScreen(
              controller: controller,
              onToggleTheme: () {},
              isDarkMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.isLinkedScrolling, isTrue);
        expect(controller.safePreviewScrollOffset, 0.0);

        // Scroll editor down -> preview should follow
        controller.scrollController.jumpTo(500.0);
        await tester.pump();
        final syncedPreviewOffset = controller.safePreviewScrollOffset;
        expect(syncedPreviewOffset, greaterThan(0.0));

        // Scroll preview independently -> editor must NOT move
        final editorOffsetBefore = controller.safeScrollOffset;
        controller.previewScrollController.jumpTo(100.0);
        await tester.pump();
        expect(controller.safeScrollOffset, closeTo(editorOffsetBefore, 0.1));
      },
    );

    testWidgets(
      'frontmatter pill hides when scrolled down and sidebar navigation area is vertically resizable',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.setFrontmatter('title: Test Paper');
        controller.textController.text = buildLongDocument();
        controller.flushPendingRenderUpdate();
        controller.toggleSidebar();

        await tester.pumpWidget(
          MaterialApp(
            home: MainScreen(
              controller: controller,
              onToggleTheme: () {},
              isDarkMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Frontmatter pill visible at scroll 0
        expect(find.text('Frontmatter'), findsOneWidget);

        // Scroll down past pill offset -> Frontmatter pill hides
        controller.scrollController.jumpTo(120.0);
        await tester.pump();
        expect(find.text('Frontmatter'), findsNothing);

        // Resize navigation card vertically via drag handle
        final navCardFinder = find.byKey(
          const ValueKey('sidebar-navigation-card'),
        );
        final initialNavHeight = tester.getSize(navCardFinder).height;
        final handleFinder = find.byKey(
          const ValueKey('sidebar-nav-resize-handle'),
        );
        await tester.drag(handleFinder, const Offset(0, -80));
        await tester.pumpAndSettle();
        final resizedNavHeight = tester.getSize(navCardFinder).height;
        expect(resizedNavHeight, greaterThan(initialNavHeight + 40));
      },
    );

    testWidgets(
      'toolbar search pill expands, searches case-insensitively from visible line, wraps around, and highlights matches',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final controller = EditorController(
          renderDebounceDuration: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);

        controller.textController.text =
            'Alpha first\nBeta line\nGamma line\nalpha second\nDelta end';
        controller.flushPendingRenderUpdate();

        await tester.pumpWidget(
          MaterialApp(
            home: MainScreen(
              controller: controller,
              onToggleTheme: () {},
              isDarkMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Collapsed search pill is 32px wide circle and matches Export pill height
        final pillFinder = find.byKey(const ValueKey('toolbar-search-pill'));
        final exportFinder = find.byKey(const ValueKey('toolbar-export-btn'));
        expect(tester.getSize(pillFinder).width, 32.0);
        expect(
          tester.getSize(pillFinder).height,
          tester.getSize(exportFinder).height,
        );

        // Tap to expand
        await tester.tap(
          find.byKey(const ValueKey('toolbar-search-toggle-btn')),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(pillFinder).width, 210.0);
        expect(
          find.byKey(const ValueKey('toolbar-search-action-btn')),
          findsOneWidget,
        );

        // Simulate visible line starting at line 2 ("Gamma line"), so search
        // should find "alpha second" on line 3 first, then wrap to "Alpha first" on line 0.
        controller.updateTopVisibleEditorLine(2, syncPreview: false);

        await tester.enterText(
          find.byKey(const ValueKey('toolbar-search-input')),
          'ALPHA',
        );
        await tester.tap(
          find.byKey(const ValueKey('toolbar-search-action-btn')),
        );
        await tester.pump();

        final firstMatch = controller.textController.searchHighlightRange;
        expect(firstMatch, isNotNull);
        expect(
          controller.textController.text.substring(
            firstMatch!.start,
            firstMatch.end,
          ),
          'alpha',
        );

        // Press action button again -> wraps to "Alpha" at index 0
        await tester.tap(
          find.byKey(const ValueKey('toolbar-search-action-btn')),
        );
        await tester.pump();

        final wrappedMatch = controller.textController.searchHighlightRange;
        expect(wrappedMatch, isNotNull);
        expect(wrappedMatch!.start, 0);
        expect(
          controller.textController.text.substring(
            wrappedMatch.start,
            wrappedMatch.end,
          ),
          'Alpha',
        );

        // Close search -> clears highlight and collapses pill
        await tester.tap(
          find.byKey(const ValueKey('toolbar-search-close-btn')),
        );
        await tester.pumpAndSettle();
        expect(controller.textController.searchHighlightRange, isNull);
        expect(tester.getSize(pillFinder).width, 32.0);

        // Ctrl+F opens the search pill
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(tester.getSize(pillFinder).width, 210.0);

        // Clicking elsewhere while query is blank auto-collapses the pill
        await tester.tapAt(const Offset(300, 300));
        await tester.pumpAndSettle();
        expect(tester.getSize(pillFinder).width, 32.0);
      },
    );
  });
}
