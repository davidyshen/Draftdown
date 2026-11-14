import 'package:flutter_test/flutter_test.dart';
import 'package:draftdown/services/system_font_service.dart';

void main() {
  group('SystemFontService', () {
    tearDown(() {
      SystemFontService.instance.clearCache();
    });

    test('parseLineSeparatedFamilies trims and ignores blank lines', () {
      const raw = '  Consolas  \r\n\r\nArial\n  Segoe UI \n';
      expect(
        SystemFontService.parseLineSeparatedFamilies(raw),
        equals(['Consolas', 'Arial', 'Segoe UI']),
      );
    });

    test('parseFcListFamilies splits comma-separated aliases', () {
      const raw = 'DejaVu Sans,DejaVu Sans Condensed\nUbuntu Mono\n';
      expect(
        SystemFontService.parseFcListFamilies(raw),
        equals(['DejaVu Sans', 'DejaVu Sans Condensed', 'Ubuntu Mono']),
      );
    });

    test('setMockFonts caches and getInstalledFonts returns cached fonts', () async {
      const mockFonts = InstalledFonts(
        allFonts: ['Arial', 'Consolas', 'Georgia'],
        monospaceFonts: ['Consolas'],
      );
      SystemFontService.instance.setMockFonts(mockFonts);

      expect(SystemFontService.instance.cachedFonts, equals(mockFonts));
      final loaded = await SystemFontService.instance.getInstalledFonts();
      expect(loaded.allFonts, equals(['Arial', 'Consolas', 'Georgia']));
      expect(loaded.monospaceFonts, equals(['Consolas']));

      SystemFontService.instance.clearCache();
      expect(SystemFontService.instance.cachedFonts, isNull);
    });
  });
}
