import 'dart:io';
import 'dart:typed_data';

import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/services/clipboard_image_service.dart';
import 'package:draftdown/ui/widgets/paste_image_dialog.dart';
import 'package:draftdown/ui/widgets/toolbar.dart';
import 'package:draftdown/utils/yaml_frontmatter_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('YamlFrontmatterHelper.readMediaPathFromFrontmatter', () {
    test('returns null when frontmatter or draftdown.media is absent', () {
      expect(YamlFrontmatterHelper.readMediaPathFromFrontmatter('# Hello'), isNull);
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          '---\ntitle: Test\n---\nBody',
        ),
        isNull,
      );
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          '---\ndraftdown:\n  other: value\n---\nBody',
        ),
        isNull,
      );
    });

    test('reads unquoted, quoted, and commented draftdown.media values', () {
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          '---\ndraftdown:\n  media: assets/images\n---\nBody',
        ),
        'assets/images',
      );
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          '---\r\ndraftdown:\r\n  media: "my media"\r\n---\r\nBody',
        ),
        'my media',
      );
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          "---\ndraftdown:\n  media: 'img' # inline comment\n---\n",
        ),
        'img',
      );
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          '---\ndraftdown:\n  media: custom_media # comment\n---\n',
        ),
        'custom_media',
      );
    });

    test('ignores top-level media key outside draftdown block', () {
      expect(
        YamlFrontmatterHelper.readMediaPathFromFrontmatter(
          '---\ndraftdown:\n  theme: dark\nmedia: wrong_place\n---\nBody',
        ),
        isNull,
      );
    });
  });

  group('ClipboardImageService.detectExtension', () {
    test('detects PNG, JPEG, GIF, WebP, and BMP signatures', () {
      expect(
        ClipboardImageService.detectExtension(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        'png',
      );
      expect(
        ClipboardImageService.detectExtension(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        'jpg',
      );
      expect(
        ClipboardImageService.detectExtension(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
        ),
        'gif',
      );
      expect(
        ClipboardImageService.detectExtension(
          Uint8List.fromList([
            0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
          ]),
        ),
        'webp',
      );
      expect(
        ClipboardImageService.detectExtension(
          Uint8List.fromList([0x42, 0x4D, 0x00]),
        ),
        'bmp',
      );
      expect(
        ClipboardImageService.detectExtension(Uint8List.fromList([1, 2, 3])),
        'png',
      );
    });
  });

  group('PasteImageDialog filename helpers', () {
    test('normalises spaces to hyphens and appends default extension', () {
      expect(
        PasteImageDialog.normaliseFilename('my cool image', 'png'),
        'my-cool-image.png',
      );
      expect(
        PasteImageDialog.normaliseFilename('  diagram 1.jpg  ', 'png'),
        'diagram-1.jpg',
      );
      expect(PasteImageDialog.normaliseFilename('   ', 'png'), '');
    });

    test('validates invalid characters and empty names', () {
      expect(PasteImageDialog.validateFilename(''), isNotNull);
      expect(PasteImageDialog.validateFilename('../secret.png'), isNotNull);
      expect(PasteImageDialog.validateFilename('bad:name.png'), isNotNull);
      expect(PasteImageDialog.validateFilename('.png'), isNotNull);
      expect(PasteImageDialog.validateFilename('valid-name.png'), isNull);
    });
  });

  group('EditorController.savePastedImage', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('draftdown_paste_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves to default media folder and inserts ![](path) at cursor', () async {
      final mdPath = p.join(tempDir.path, 'notes.md');
      await File(mdPath).writeAsString('Hello world');

      final controller = EditorController();
      await controller.openFile(mdPath);
      controller.textController.selection = const TextSelection.collapsed(
        offset: 5,
      );

      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
      final insertedPath = await controller.savePastedImage(
        bytes: bytes,
        filename: 'diagram.png',
      );

      expect(insertedPath, 'media/diagram.png');
      expect(
        controller.textController.text,
        'Hello![](media/diagram.png) world',
      );
      final savedFile = File(p.join(tempDir.path, 'media', 'diagram.png'));
      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.readAsBytes(), bytes);
      controller.dispose();
    });

    test('respects custom draftdown.media frontmatter path and alt text', () async {
      final mdPath = p.join(tempDir.path, 'paper.md');
      await File(mdPath).writeAsString(
        '---\ndraftdown:\n  media: assets/figures\n---\nIntro ',
      );

      final controller = EditorController();
      await controller.openFile(mdPath);
      controller.textController.selection = TextSelection.collapsed(
        offset: controller.textController.text.length,
      );

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final insertedPath = await controller.savePastedImage(
        bytes: bytes,
        filename: 'chart.png',
        altText: 'Results chart',
      );

      expect(insertedPath, 'assets/figures/chart.png');
      expect(
        controller.textController.text,
        'Intro ![Results chart](assets/figures/chart.png)',
      );
      expect(
        await File(
          p.join(tempDir.path, 'assets', 'figures', 'chart.png'),
        ).exists(),
        isTrue,
      );
      controller.dispose();
    });
  });

  group('PasteImageDialog widget', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('draftdown_dialog_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets('returns normalised filename & alt text, and detects collisions',
        (tester) async {
      final existingFile = File(p.join(tempDir.path, 'existing.png'));
      existingFile.writeAsBytesSync([1, 2, 3]);

      PasteImageResult? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showDialog<PasteImageResult>(
                    context: context,
                    builder: (_) => PasteImageDialog(
                      imageBytes: Uint8List.fromList([1, 2, 3, 4]),
                      defaultExtension: 'png',
                      mediaDirectory: tempDir.path,
                      mediaFolderDisplay: 'media',
                      initialFilename: 'existing.png',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Collision warning & Overwrite button should be visible for existing.png
      expect(find.text('Overwrite'), findsOneWidget);
      expect(
        find.textContaining('already exists'),
        findsOneWidget,
      );

      // Change filename to include spaces -> normalises and switches back to Save & Insert
      await tester.enterText(
        find.widgetWithText(TextField, 'Filename'),
        'new shot',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Alt text (optional)'),
        'My screenshot',
      );
      await tester.pump();

      expect(find.text('Save & Insert'), findsOneWidget);
      expect(
        find.text('Spaces will be saved as: new-shot.png'),
        findsOneWidget,
      );

      await tester.tap(find.text('Save & Insert'));
      await tester.pumpAndSettle();

      expect(dialogResult, isNotNull);
      expect(dialogResult!.filename, 'new-shot.png');
      expect(dialogResult!.altText, 'My screenshot');
    });
  });

  group('AppToolbar Insert Image button', () {
    testWidgets('renders Insert Image button between Table and Cite and triggers callback',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      var insertImageTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppToolbar(
              controller: controller,
              onInsertImage: () => insertImageTapped = true,
              onOpenCitationDialog: () {},
              onOpenExportDialog: () {},
              isDarkMode: false,
            ),
          ),
        ),
      );

      final tableFinder = find.byIcon(Icons.table_chart_outlined);
      final imageFinder = find.byIcon(Icons.image_outlined);
      final citeFinder = find.text('Cite');

      expect(tableFinder, findsOneWidget);
      expect(imageFinder, findsOneWidget);
      expect(citeFinder, findsOneWidget);

      final tableX = tester.getCenter(tableFinder).dx;
      final imageX = tester.getCenter(imageFinder).dx;
      final citeX = tester.getCenter(citeFinder).dx;
      expect(imageX, greaterThan(tableX));
      expect(imageX, lessThan(citeX));

      await tester.tap(imageFinder);
      await tester.pump();
      expect(insertImageTapped, isTrue);

      controller.dispose();
    });
  });
}
