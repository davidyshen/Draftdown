import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draftdown/controllers/markdown_syntax_controller.dart';

void main() {
  const baseStyle = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 13.5,
    color: Color(0xFF0F172A),
  );

  final darkTheme = MarkdownSyntaxTheme.dark();
  final lightTheme = MarkdownSyntaxTheme.light();

  group('MarkdownSyntaxHighlighter - Headers', () {
    test('identifies H1 to H6 headers and markers', () {
      const text =
          '# Heading 1\n## Heading 2\n### Heading 3\n#### Heading 4\n##### Heading 5\n###### Heading 6';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final markerSpans = spans
          .where((s) => s.type == MarkdownTokenType.headerMarker)
          .toList();
      expect(markerSpans.length, equals(6));

      expect(spans.any((s) => s.type == MarkdownTokenType.header1), isTrue);
      expect(spans.any((s) => s.type == MarkdownTokenType.header2), isTrue);
      expect(spans.any((s) => s.type == MarkdownTokenType.header3), isTrue);
      expect(spans.any((s) => s.type == MarkdownTokenType.header4), isTrue);
      expect(spans.any((s) => s.type == MarkdownTokenType.header5), isTrue);
      expect(spans.any((s) => s.type == MarkdownTokenType.header6), isTrue);
    });

    test('preserves bold font weight on header text', () {
      const text = '# Prominent Title';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final titleSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.header1,
      );
      expect(titleSpan.style.fontWeight, equals(FontWeight.bold));
      expect(titleSpan.style.color, equals(darkTheme.header1Color));
    });
  });

  group('MarkdownSyntaxHighlighter - Text Formatting', () {
    test('parses bold text with asterisks and underscores', () {
      const text = 'Here is **bold text** and __also bold__';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final boldSpans = spans
          .where((s) => s.type == MarkdownTokenType.bold)
          .toList();
      expect(boldSpans.length, equals(2));
      expect(boldSpans[0].style.fontWeight, equals(FontWeight.bold));
      expect(
        text.substring(boldSpans[0].start, boldSpans[0].end),
        equals('bold text'),
      );
      expect(
        text.substring(boldSpans[1].start, boldSpans[1].end),
        equals('also bold'),
      );
    });

    test('parses italic text with asterisks and underscores', () {
      const text = 'Here is *italic text* and _more italic_';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final italicSpans = spans
          .where((s) => s.type == MarkdownTokenType.italic)
          .toList();
      expect(italicSpans.length, equals(2));
      expect(italicSpans[0].style.fontStyle, equals(FontStyle.italic));
      expect(
        text.substring(italicSpans[0].start, italicSpans[0].end),
        equals('italic text'),
      );
      expect(
        text.substring(italicSpans[1].start, italicSpans[1].end),
        equals('more italic'),
      );
    });

    test('parses combined bold and italic formatting', () {
      const text = 'Text with ***bold italic*** emphasis';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final biSpans = spans
          .where((s) => s.type == MarkdownTokenType.boldItalic)
          .toList();
      expect(biSpans.length, equals(1));
      expect(biSpans[0].style.fontWeight, equals(FontWeight.bold));
      expect(biSpans[0].style.fontStyle, equals(FontStyle.italic));
      expect(
        text.substring(biSpans[0].start, biSpans[0].end),
        equals('bold italic'),
      );
    });

    test('parses strikethrough text', () {
      const text = 'This is ~~deprecated~~ syntax';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final strikeSpans = spans
          .where((s) => s.type == MarkdownTokenType.strikethrough)
          .toList();
      expect(strikeSpans.length, equals(1));
      expect(
        strikeSpans[0].style.decoration,
        equals(TextDecoration.lineThrough),
      );
      expect(
        text.substring(strikeSpans[0].start, strikeSpans[0].end),
        equals('deprecated'),
      );
    });
  });

  group('MarkdownSyntaxHighlighter - Links and Images', () {
    test('parses standard markdown link with anchor and url', () {
      const text = 'Visit [Flutter](https://flutter.dev) for documentation.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: lightTheme,
        baseStyle: baseStyle,
      );

      final linkTextSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.linkText,
      );
      expect(
        text.substring(linkTextSpan.start, linkTextSpan.end),
        equals('Flutter'),
      );
      expect(linkTextSpan.style.decoration, equals(TextDecoration.underline));

      final linkUrlSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.linkUrl,
      );
      expect(
        text.substring(linkUrlSpan.start, linkUrlSpan.end),
        equals('https://flutter.dev'),
      );
    });

    test('parses image links with image marker and url', () {
      const text = '![Figure 1](images/diagram.png "Architecture")';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      expect(spans.any((s) => s.type == MarkdownTokenType.imageMarker), isTrue);
      final altSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.linkText,
      );
      expect(text.substring(altSpan.start, altSpan.end), equals('Figure 1'));

      final urlSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.linkUrl,
      );
      expect(
        text.substring(urlSpan.start, urlSpan.end),
        equals('images/diagram.png'),
      );
    });

    test('parses autolinks', () {
      const text =
          'Contact <support@example.com> or visit <https://example.com>';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: lightTheme,
        baseStyle: baseStyle,
      );

      final autoLinks = spans
          .where((s) => s.type == MarkdownTokenType.linkText)
          .toList();
      expect(autoLinks.length, equals(2));
      expect(
        text.substring(autoLinks[0].start, autoLinks[0].end),
        equals('support@example.com'),
      );
      expect(
        text.substring(autoLinks[1].start, autoLinks[1].end),
        equals('https://example.com'),
      );
    });
  });

  group('MarkdownSyntaxHighlighter - References and Citations', () {
    test('parses Pandoc bracketed single citation', () {
      const text = 'As stated in [@turing1950], computation is fundamental.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final keySpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.citationKey,
      );
      expect(text.substring(keySpan.start, keySpan.end), equals('@turing1950'));
      expect(keySpan.style.fontWeight, equals(FontWeight.w600));

      final bracketSpans = spans
          .where((s) => s.type == MarkdownTokenType.citationBracket)
          .toList();
      expect(bracketSpans.length, equals(2)); // [ and ]
    });

    test('parses multiple citations with locators inside brackets', () {
      const text =
          'Earlier works [@shannon1948; @turing1950, p. 42] prove this.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final keySpans = spans
          .where((s) => s.type == MarkdownTokenType.citationKey)
          .toList();
      expect(keySpans.length, equals(2));
      expect(
        text.substring(keySpans[0].start, keySpans[0].end),
        equals('@shannon1948'),
      );
      expect(
        text.substring(keySpans[1].start, keySpans[1].end),
        equals('@turing1950'),
      );

      final locatorSpans = spans
          .where((s) => s.type == MarkdownTokenType.citationLocator)
          .toList();
      expect(locatorSpans.isNotEmpty, isTrue);
    });

    test('parses in-text citations with and without locators', () {
      const text =
          'According to @knuth1984, and later expanded by @vaswani2017 [p. 15].';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: lightTheme,
        baseStyle: baseStyle,
      );

      final keySpans = spans
          .where((s) => s.type == MarkdownTokenType.citationKey)
          .toList();
      expect(keySpans.length, equals(2));
      expect(
        text.substring(keySpans[0].start, keySpans[0].end),
        equals('@knuth1984'),
      );
      expect(
        text.substring(keySpans[1].start, keySpans[1].end),
        equals('@vaswani2017'),
      );

      final locatorSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.citationLocator,
      );
      expect(
        text.substring(locatorSpan.start, locatorSpan.end),
        equals('p. 15'),
      );
    });

    test('parses footnotes and footnote definitions', () {
      const text = 'Here is a note[^1].\n\n[^1]: Footnote description here.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final footKeys = spans
          .where((s) => s.type == MarkdownTokenType.footnoteKey)
          .toList();
      expect(footKeys.length, equals(2));
      expect(text.substring(footKeys[0].start, footKeys[0].end), equals('1'));
      expect(
        text.substring(footKeys[1].start, footKeys[1].end),
        equals('[^1]:'),
      );
    });
  });

  group('MarkdownSyntaxHighlighter - LaTeX Formulas', () {
    test('parses inline math with dollar signs and round brackets', () {
      const text = r'Given $E = mc^2$ and \(a^2 + b^2 = c^2\) respectively.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      final mathSpans = spans
          .where((s) => s.type == MarkdownTokenType.latexInline)
          .toList();
      expect(mathSpans.length, equals(2));
      expect(
        text.substring(mathSpans[0].start, mathSpans[0].end),
        equals('E = mc^2'),
      );
      expect(
        text.substring(mathSpans[1].start, mathSpans[1].end),
        equals('a^2 + b^2 = c^2'),
      );
      expect(mathSpans[0].style.color, equals(darkTheme.latexInlineColor));

      final delimSpans = spans
          .where((s) => s.type == MarkdownTokenType.latexDelimiter)
          .toList();
      expect(delimSpans.length, equals(4)); // $, $, \(, \)
    });

    test('parses display math block formulas', () {
      const text =
          "\$\$\n\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}\n\$\$";
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: lightTheme,
        baseStyle: baseStyle,
      );

      final displaySpans = spans
          .where((s) => s.type == MarkdownTokenType.latexDisplay)
          .toList();
      expect(displaySpans.length, equals(1));
      expect(
        displaySpans[0].style.backgroundColor,
        equals(lightTheme.latexDisplayBg),
      );
      expect(displaySpans[0].style.color, equals(lightTheme.latexDisplayColor));
    });

    test('does not misparse underscores inside math formulas as italics', () {
      const text = r'Formula $x_1 + x_2 + x_3 = 0$ is linear.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      // Should not have any italic tokens
      expect(spans.any((s) => s.type == MarkdownTokenType.italic), isFalse);
      final mathSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.latexInline,
      );
      expect(
        text.substring(mathSpan.start, mathSpan.end),
        equals(r'x_1 + x_2 + x_3 = 0'),
      );
    });
  });

  group('MarkdownSyntaxHighlighter - Code Blocks and Isolation', () {
    test('isolates code blocks from markdown formatting', () {
      const text =
          '```dart\n// This should *not* be italic or **bold**\nfinal x = 42;\n```';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      expect(spans.any((s) => s.type == MarkdownTokenType.italic), isFalse);
      expect(spans.any((s) => s.type == MarkdownTokenType.bold), isFalse);
      expect(spans.any((s) => s.type == MarkdownTokenType.codeBlock), isTrue);
    });

    test('parses inline code without formatting inside', () {
      const text = 'Call `print_line("hello *world*")` now.';
      final spans = MarkdownSyntaxHighlighter.parseSpans(
        text: text,
        theme: darkTheme,
        baseStyle: baseStyle,
      );

      expect(spans.any((s) => s.type == MarkdownTokenType.italic), isFalse);
      final codeSpan = spans.firstWhere(
        (s) => s.type == MarkdownTokenType.inlineCode,
      );
      expect(
        text.substring(codeSpan.start, codeSpan.end),
        equals('print_line("hello *world*")'),
      );
    });
  });

  group('MarkdownSyntaxEditingController - Integration', () {
    testWidgets('renders TextSpan tree with highlighted tokens', (
      tester,
    ) async {
      final controller = MarkdownSyntaxEditingController(
        text:
            r'# Header'
            '\n'
            r'Text with **bold** and $E=mc^2$ and [@turing1950].',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, equals(controller));
      expect(controller.text, contains('# Header'));

      controller.dispose();
    });

    testWidgets(
      're-uses cached tokens on theme switch for instantaneous switching',
      (tester) async {
        final controller = MarkdownSyntaxEditingController(
          text:
              r'# Title'
              '\n'
              r'Some **bold text** with `code` and $x=1$',
        );

        bool isDark = false;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                home: Scaffold(
                  body: TextField(controller: controller),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => setState(() => isDark = !isDark),
                  ),
                ),
              );
            },
          ),
        );

        final spanLight = controller.buildTextSpan(
          context: tester.element(find.byType(TextField)),
          style: const TextStyle(),
          withComposing: false,
        );

        // Toggle theme mode
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        final spanDark = controller.buildTextSpan(
          context: tester.element(find.byType(TextField)),
          style: const TextStyle(),
          withComposing: false,
        );

        // Both spans should have exact same text content
        expect(spanLight.toPlainText(), equals(spanDark.toPlainText()));
        expect(spanLight.children?.length, equals(spanDark.children?.length));

        controller.dispose();
      },
    );

    test('high throughput parsing on large markdown document', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 2000; i++) {
        buffer.writeln('## Section $i');
        buffer.writeln(
          'This is paragraph $i with **bold statement** and `inline_code()`.',
        );
        buffer.writeln('Reference to [@key$i] and formula \$x_{$i} = y^2\$.');
        buffer.writeln();
      }
      final largeText = buffer.toString();
      expect(largeText.length, greaterThan(150000));

      final stopwatch = Stopwatch()..start();
      final tokens = MarkdownSyntaxHighlighter.parseTokens(largeText);
      stopwatch.stop();

      expect(tokens.isNotEmpty, isTrue);
      // Parsing 2,000 sections (150KB+) should complete comfortably under 600ms
      expect(stopwatch.elapsedMilliseconds, lessThan(600));

      // Incremental single-line edit in the middle of the 150KB document
      final insertPos = largeText.indexOf('This is paragraph 1000');
      final editedText = largeText.replaceRange(
        insertPos,
        insertPos + 'This is paragraph 1000'.length,
        'This is **updated** paragraph 1000',
      );

      final incStopwatch = Stopwatch()..start();
      final incResult = MarkdownSyntaxHighlighter.updateTokensIncrementally(
        oldText: largeText,
        newText: editedText,
        oldTokens: tokens,
      );
      incStopwatch.stop();

      expect(incResult, isNotNull);
      expect(incStopwatch.elapsedMilliseconds, lessThan(50));

      final fullExpected = MarkdownSyntaxHighlighter.parseTokens(editedText);
      expect(incResult!.$1.length, equals(fullExpected.length));
      for (int i = 0; i < fullExpected.length; i++) {
        expect(incResult.$1[i].start, equals(fullExpected[i].start));
        expect(incResult.$1[i].end, equals(fullExpected[i].end));
        expect(incResult.$1[i].type, equals(fullExpected[i].type));
      }
    });
  });
}
