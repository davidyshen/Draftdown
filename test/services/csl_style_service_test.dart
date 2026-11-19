import 'dart:io';

import 'package:draftdown/services/csl_style_service.dart';
import 'package:draftdown/utils/yaml_frontmatter_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('CslStyleService.parseCslMetadata', () {
    test('parses independent numeric style metadata', () {
      const xml = '''<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0">
  <info>
    <title>IEEE</title>
    <id>http://www.zotero.org/styles/ieee</id>
    <category citation-format="numeric"/>
  </info>
</style>''';

      final style = CslStyleService.parseCslMetadata(
        xml,
        id: 'ieee',
        isBuiltIn: true,
      );

      expect(style.id, 'ieee');
      expect(style.title, 'IEEE');
      expect(style.citationFormat, 'numeric');
      expect(style.isNumeric, isTrue);
      expect(style.isDependent, isFalse);
      expect(style.isBuiltIn, isTrue);
    });

    test('parses dependent style and extracts independent-parent slug', () {
      const xml = '''<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0" default-locale="en-US">
  <info>
    <title>Journal of Applied Ecology</title>
    <id>http://www.zotero.org/styles/journal-of-applied-ecology</id>
    <link href="http://www.zotero.org/styles/journal-of-applied-ecology" rel="self"/>
    <link href="http://www.zotero.org/styles/apa" rel="independent-parent"/>
    <category citation-format="author-date"/>
  </info>
</style>''';

      final style = CslStyleService.parseCslMetadata(
        xml,
        id: 'journal-of-applied-ecology',
      );

      expect(style.id, 'journal-of-applied-ecology');
      expect(style.title, 'Journal of Applied Ecology');
      expect(style.citationFormat, 'author-date');
      expect(style.isNumeric, isFalse);
      expect(style.isDependent, isTrue);
      expect(style.independentParentId, 'apa');
    });
  });

  group('CslStyleService storage & dependency protection', () {
    late Directory tempDir;
    late CslStyleService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('draftdown_csl_test_');
      final builtinDir = Directory(p.join(tempDir.path, '_builtin'));
      await builtinDir.create(recursive: true);

      await File(p.join(builtinDir.path, 'apa.csl')).writeAsString('''
<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0">
  <info>
    <title>American Psychological Association 7th edition</title>
    <category citation-format="author-date"/>
  </info>
</style>''');

      await File(p.join(tempDir.path, 'custom-parent.csl')).writeAsString('''
<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0">
  <info>
    <title>Custom Parent Style</title>
    <category citation-format="numeric"/>
  </info>
</style>''');

      await File(p.join(tempDir.path, 'custom-child.csl')).writeAsString('''
<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0">
  <info>
    <title>Custom Child Style</title>
    <link href="http://www.zotero.org/styles/custom-parent" rel="independent-parent"/>
    <category citation-format="numeric"/>
  </info>
</style>''');

      service = CslStyleService();
      await service.initialize(
        customStorageDir: tempDir,
        skipAssetExtraction: true,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves dependent style path to its independent parent', () {
      final resolved = service.resolveEffectiveCslPath('custom-child');
      expect(resolved, isNotNull);
      expect(p.basename(resolved!), 'custom-parent.csl');
    });

    test('prevents removing built-in styles', () async {
      await expectLater(
        service.removeStyle('apa'),
        throwsA(isA<CslStyleException>()),
      );
    });

    test('prevents removing parent while dependent style exists, then allows after', () async {
      await expectLater(
        service.removeStyle('custom-parent'),
        throwsA(isA<CslStyleException>()),
      );

      await service.removeStyle('custom-child');
      expect(service.findById('custom-child'), isNull);

      await service.removeStyle('custom-parent');
      expect(service.findById('custom-parent'), isNull);
    });
  });

  group('YamlFrontmatterHelper', () {
    test('reads csl from YAML frontmatter', () {
      const md = '''---
title: My Manuscript
csl: "journal-of-applied-ecology"
---

Hello world [@smith2020].
''';
      expect(
        YamlFrontmatterHelper.readCslFromFrontmatter(md),
        'journal-of-applied-ecology',
      );
    });

    test('upserts csl into existing frontmatter preserving other keys', () {
      const md = '''---
title: My Manuscript
author: Jane Doe
---

Body text.''';
      final updated = YamlFrontmatterHelper.upsertCslInFrontmatter(md, 'ieee');
      expect(YamlFrontmatterHelper.readCslFromFrontmatter(updated), 'ieee');
      expect(updated, contains('title: My Manuscript'));
      expect(updated, contains('author: Jane Doe'));
      expect(updated, contains('Body text.'));
    });

    test('prepends frontmatter when none exists', () {
      const md = '# Heading\n\nParagraph.';
      final updated = YamlFrontmatterHelper.upsertCslInFrontmatter(
        md,
        'nature',
      );
      expect(YamlFrontmatterHelper.readCslFromFrontmatter(updated), 'nature');
      expect(
        YamlFrontmatterHelper.stripYamlFrontmatter(updated),
        '# Heading\n\nParagraph.',
      );
    });

    test('strips leading frontmatter without touching mid-document rules', () {
      const md = '''---
csl: apa
---

# Intro

---

Section 2''';
      final stripped = YamlFrontmatterHelper.stripYamlFrontmatter(md);
      expect(stripped.trimLeft(), startsWith('# Intro'));
      expect(stripped, contains('---'));
      expect(stripped, contains('Section 2'));
    });
  });
}
