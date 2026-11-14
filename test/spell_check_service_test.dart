import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/controllers/markdown_syntax_controller.dart';
import 'package:draftdown/services/spell_check_service.dart';
import 'package:draftdown/ui/widgets/editor_view.dart';
import 'package:draftdown/ui/widgets/settings_dialog.dart';
import 'package:draftdown/ui/widgets/sidebar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpellCheckService', () {
    test('flags misspelled words in prose while accepting valid words', () {
      final service = SpellCheckService(useNativeBackend: false);
      const text = 'This is a smaple document with a wrnog word.';
      final tokens = MarkdownSyntaxHighlighter.parseTokens(text);

      final errors = service.findSpellingErrors(text: text, tokens: tokens);
      final flagged = errors.map((e) => e.word).toList();

      expect(flagged, containsAll(['smaple', 'wrnog']));
      expect(flagged, isNot(contains('document')));
      expect(flagged, isNot(contains('word')));
    });

    test('skips code blocks, inline code, LaTeX math, URLs, and citations', () {
      final service = SpellCheckService(useNativeBackend: false);
      const text = '''
# Heading with tpyo

Normal text with `inlinetpyo` and a [valid link](https://exmaple.com/badpath).
Math: \$alpha + betaa\$ and \$\$gammapi + xzz\$\$.
Citation [@knuth1984literate] and @shannon1948mathematical and footnote [^fn1].
Acronyms like API and camelCase identifiers like myBadVarName.

```dart
final xzz = 'badcodeword';
```
''';
      final tokens = MarkdownSyntaxHighlighter.parseTokens(text);
      final errors = service.findSpellingErrors(text: text, tokens: tokens);
      final flagged = errors.map((e) => e.word).toList();

      expect(flagged, equals(['tpyo']));
    });

    test('supports custom dictionary and session ignore', () {
      final service = SpellCheckService(useNativeBackend: false);
      const text = 'Using qzxword and anotherqzx in prose.';
      final tokens = MarkdownSyntaxHighlighter.parseTokens(text);

      expect(
        service
            .findSpellingErrors(text: text, tokens: tokens)
            .map((e) => e.word),
        containsAll(['qzxword', 'anotherqzx']),
      );

      service.addCustomWord('qzxword');
      service.ignoreWord('anotherqzx');

      expect(service.findSpellingErrors(text: text, tokens: tokens), isEmpty);

      service.removeCustomWord('qzxword');
      expect(
        service
            .findSpellingErrors(text: text, tokens: tokens)
            .map((e) => e.word),
        equals(['qzxword']),
      );
    });

    test('provides spelling suggestions for misspelled words', () {
      final service = SpellCheckService(useNativeBackend: false);
      final suggestions = service.suggest('helo');
      expect(suggestions, isNotEmpty);
      expect(suggestions, contains('hello'));
    });

    test('native Windows backend initialises cleanly on Windows', () {
      final service = SpellCheckService(languageTag: 'en-GB');
      const text = 'Hello wrld, this is a test.';
      final tokens = MarkdownSyntaxHighlighter.parseTokens(text);
      final errors = service.findSpellingErrors(text: text, tokens: tokens);
      expect(errors.map((e) => e.word), contains('wrld'));
      expect(errors.map((e) => e.word), isNot(contains('Hello')));
      service.dispose();
    });
  });

  group('MarkdownSyntaxEditingController Spellcheck Integration', () {
    testWidgets(
      'applies wavy underline to misspelled words and preserves bold',
      (tester) async {
        final service = SpellCheckService(useNativeBackend: false);
        final controller = MarkdownSyntaxEditingController(
          text: 'Hello **wrold** and `badcode`',
          spellCheckService: service,
        );

        late TextSpan builtSpan;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                builtSpan = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(fontSize: 14),
                  withComposing: false,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final spans = builtSpan.children!.cast<TextSpan>();
        final wroldSpan = spans.firstWhere((s) => s.text == 'wrold');
        expect(wroldSpan.style?.decorationStyle, TextDecorationStyle.wavy);
        expect(wroldSpan.style?.fontWeight, FontWeight.bold);

        final codeSpan = spans.firstWhere((s) => s.text == 'badcode');
        expect(
          codeSpan.style?.decorationStyle,
          isNot(TextDecorationStyle.wavy),
        );

        expect(controller.spellErrorAtOffset(9)?.word, 'wrold');
        expect(controller.spellErrorAtOffset(23), isNull);

        controller.dispose();
        service.dispose();
      },
    );
  });

  group('EditorController & UI Spellcheck Integration', () {
    test('replaceSpellingError updates text and cursor offset', () {
      final service = SpellCheckService(useNativeBackend: false);
      final controller = EditorController(spellCheckService: service);
      controller.textController.text = 'Hello wrold!';
      final tokens = MarkdownSyntaxHighlighter.parseTokens(
        controller.textController.text,
      );
      final errors = service.findSpellingErrors(
        text: controller.textController.text,
        tokens: tokens,
      );
      expect(errors.length, 1);

      controller.replaceSpellingError(errors.first, 'world');
      expect(controller.textController.text, 'Hello world!');
      expect(controller.textController.selection.baseOffset, 11);

      controller.dispose();
    });

    testWidgets(
      'Toolbar toggles spellchecker and SettingsDialog shows Spellcheck tab',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = SpellCheckService(useNativeBackend: false);
        final controller = EditorController(spellCheckService: service);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  AppSidebar(
                    controller: controller,
                    onOpenFile: () {},
                    onNewFile: () {},
                    onOpenSettingsDialog: () {},
                    onToggleTheme: () {},
                  ),
                  Expanded(child: SettingsDialog(controller: controller)),
                ],
              ),
            ),
          ),
        );

        expect(controller.isSpellCheckEnabled, isTrue);
        await tester.tap(find.byKey(const ValueKey('spellcheck-toggle-btn')));
        await tester.pump();
        expect(controller.isSpellCheckEnabled, isFalse);

        await tester.tap(find.text('Spellcheck'));
        await tester.pumpAndSettle();
        expect(find.text('Enable Markdown Spellchecker'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('spellcheck-language-dropdown')),
          findsOneWidget,
        );

        controller.dispose();
      },
    );

    testWidgets(
      'right-clicking misspelled word shows suggestions even when cursor is elsewhere',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = SpellCheckService(useNativeBackend: false);
        final controller = EditorController(spellCheckService: service);
        controller.textController.text = 'This is helo world';
        // Place cursor at the start of the document, away from "helo".
        controller.textController.selection = const TextSelection.collapsed(
          offset: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EditorView(
                controller: controller,
                onOpenCitation: () {},
                onOpenExport: () {},
                onOpenFile: () {},
                onNewFile: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the screen centre of "helo" (offsets 8..12) via RenderEditable.
        final editableState = tester.state<EditableTextState>(
          find.byType(EditableText).first,
        );
        final renderEditable = editableState.renderEditable;
        final boxes = renderEditable.getBoxesForSelection(
          const TextSelection(baseOffset: 8, extentOffset: 12),
        );
        expect(boxes, isNotEmpty);
        final localCenter = boxes.first.toRect().center;
        final globalCenter = renderEditable.localToGlobal(localCenter);

        // Right-click directly on "helo" while cursor remains at offset 0.
        await tester.tapAt(globalCenter, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('hello'), findsOneWidget);
        expect(find.text('Add "helo" to dictionary'), findsOneWidget);
        expect(find.text('Ignore "helo"'), findsOneWidget);

        // Tap "hello" suggestion to replace in-place.
        await tester.tap(find.text('hello'));
        await tester.pumpAndSettle();
        expect(controller.textController.text, 'This is hello world');

        controller.dispose();
      },
    );

    testWidgets('hovering over a redlined word opens spellcheck-only menu', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = SpellCheckService(useNativeBackend: false);
      final controller = EditorController(spellCheckService: service);
      controller.textController.text = 'This is helo world';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorView(
              controller: controller,
              onOpenCitation: () {},
              onOpenExport: () {},
              onOpenFile: () {},
              onNewFile: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editableState = tester.state<EditableTextState>(
        find.byType(EditableText).first,
      );
      final renderEditable = editableState.renderEditable;
      final boxes = renderEditable.getBoxesForSelection(
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );
      final globalCenter = renderEditable.localToGlobal(
        boxes.first.toRect().center,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(globalCenter);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('spellcheck-hover-menu')),
        findsOneWidget,
      );
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('Add "helo" to dictionary'), findsOneWidget);
      expect(find.text('Ignore "helo"'), findsOneWidget);
      expect(find.text('Paste'), findsNothing);
      expect(find.text('Select all'), findsNothing);

      await tester.tap(find.text('hello'));
      await tester.pumpAndSettle();
      expect(controller.textController.text, 'This is hello world');
      expect(find.byKey(const ValueKey('spellcheck-hover-menu')), findsNothing);

      controller.dispose();
    });
  });
}
