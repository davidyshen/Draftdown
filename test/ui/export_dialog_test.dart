import 'package:draftdown/controllers/editor_controller.dart';
import 'package:draftdown/models/export_format.dart';
import 'package:draftdown/ui/widgets/export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'ExportDialog shows PDF-only line numbers, page numbers, and line spacing controls',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportDialog(controller: controller, onOpenSettings: () {}),
          ),
        ),
      );

      // Standalone Document and Table of Contents are removed across all formats
      expect(find.text('Standalone Document'), findsNothing);
      expect(find.text('Table of Contents'), findsNothing);

      // PDF is selected by default
      expect(
        find.byKey(const ValueKey('line-spacing-dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('line-numbers-checkbox')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('page-numbers-checkbox')),
        findsOneWidget,
      );

      // Default line spacing is 1.0
      expect(find.text('1.0'), findsOneWidget);

      // Toggle Line Numbers & Page Numbers and check First Page Preview updates
      await tester.tap(find.byKey(const ValueKey('line-numbers-checkbox')));
      await tester.tap(find.byKey(const ValueKey('page-numbers-checkbox')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.text('Page 1 of 1'), findsOneWidget);

      // Switch to Microsoft Word (.docx) and verify PDF-only controls are hidden
      await tester.tap(find.text(ExportFormat.supportedFormats[1].name));
      await tester.pump();

      expect(find.byKey(const ValueKey('line-spacing-dropdown')), findsNothing);
      expect(find.byKey(const ValueKey('line-numbers-checkbox')), findsNothing);
      expect(find.byKey(const ValueKey('page-numbers-checkbox')), findsNothing);
    },
  );

  testWidgets('ExportDialog remembers previously used export options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final controller = EditorController();
    addTearDown(controller.dispose);

    // First opening: change options
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(controller: controller, onOpenSettings: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('line-numbers-checkbox')));
    await tester.tap(find.byKey(const ValueKey('page-numbers-checkbox')));
    await tester.tap(find.byKey(const ValueKey('line-spacing-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2.0').last);
    await tester.pumpAndSettle();

    // Re-open ExportDialog with a new widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            key: const ValueKey('reopened-export-dialog'),
            controller: controller,
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lineNumbersCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('line-numbers-checkbox')),
    );
    final pageNumbersCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('page-numbers-checkbox')),
    );
    expect(lineNumbersCheckbox.value, isTrue);
    expect(pageNumbersCheckbox.value, isTrue);
    expect(find.text('2.0'), findsOneWidget);
  });
}
