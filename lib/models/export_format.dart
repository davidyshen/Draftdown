import 'package:flutter/material.dart';

/// Supported Pandoc export formats
enum ExportFormatType {
  pdf,
  docx,
  html5,
  rtf,
  odt,
  epub,
  latex,
  plainText,
}

class ExportFormat {
  final ExportFormatType type;
  final String id;
  final String name;
  final String extension;
  final String pandocWriter;
  final String description;
  final IconData icon;

  const ExportFormat({
    required this.type,
    required this.id,
    required this.name,
    required this.extension,
    required this.pandocWriter,
    required this.description,
    required this.icon,
  });

  static const List<ExportFormat> supportedFormats = [
    ExportFormat(
      type: ExportFormatType.pdf,
      id: 'pdf',
      name: 'PDF Document',
      extension: 'pdf',
      pandocWriter: 'pdf',
      description: 'Publication-quality PDF document matching preview typography and layout',
      icon: Icons.picture_as_pdf,
    ),
    ExportFormat(
      type: ExportFormatType.docx,
      id: 'docx',
      name: 'Microsoft Word',
      extension: 'docx',
      pandocWriter: 'docx',
      description: 'Editable Word (.docx) file with native headings and references',
      icon: Icons.description,
    ),
    ExportFormat(
      type: ExportFormatType.html5,
      id: 'html5',
      name: 'HTML 5 Webpage',
      extension: 'html',
      pandocWriter: 'html5',
      description: 'Standalone HTML document matching preview typography and layout',
      icon: Icons.html,
    ),
    ExportFormat(
      type: ExportFormatType.latex,
      id: 'latex',
      name: 'LaTeX Source',
      extension: 'tex',
      pandocWriter: 'latex',
      description: 'Standard LaTeX source document for journal submission',
      icon: Icons.code,
    ),
    ExportFormat(
      type: ExportFormatType.epub,
      id: 'epub',
      name: 'EPUB eBook',
      extension: 'epub',
      pandocWriter: 'epub3',
      description: 'Reflowable electronic publication suitable for e-readers',
      icon: Icons.book,
    ),
    ExportFormat(
      type: ExportFormatType.odt,
      id: 'odt',
      name: 'OpenDocument Text',
      extension: 'odt',
      pandocWriter: 'odt',
      description: 'LibreOffice & Apache OpenOffice editable document',
      icon: Icons.article,
    ),
    ExportFormat(
      type: ExportFormatType.rtf,
      id: 'rtf',
      name: 'Rich Text Format',
      extension: 'rtf',
      pandocWriter: 'rtf',
      description: 'Universal cross-platform rich text document',
      icon: Icons.text_snippet,
    ),
    ExportFormat(
      type: ExportFormatType.plainText,
      id: 'plain',
      name: 'Plain Text',
      extension: 'txt',
      pandocWriter: 'plain',
      description: 'Stripped plain text without markdown markup',
      icon: Icons.text_fields,
    ),
  ];
}

/// Options configured when running a Pandoc export
class ExportOptions {
  final ExportFormat format;
  final String targetPath;
  final bool standalone;
  final bool tableOfContents;
  final bool useCiteproc;
  final String? bibliographyPath;
  final String? cslStylePath;
  final String customArguments;
  final String pageSize;
  final String marginSize;

  const ExportOptions({
    required this.format,
    required this.targetPath,
    this.standalone = true,
    this.tableOfContents = false,
    this.useCiteproc = true,
    this.bibliographyPath,
    this.cslStylePath,
    this.customArguments = '',
    this.pageSize = 'a4',
    this.marginSize = 'medium',
  });

  ExportOptions copyWith({
    ExportFormat? format,
    String? targetPath,
    bool? standalone,
    bool? tableOfContents,
    bool? useCiteproc,
    String? bibliographyPath,
    String? cslStylePath,
    String? customArguments,
    String? pageSize,
    String? marginSize,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      targetPath: targetPath ?? this.targetPath,
      standalone: standalone ?? this.standalone,
      tableOfContents: tableOfContents ?? this.tableOfContents,
      useCiteproc: useCiteproc ?? this.useCiteproc,
      bibliographyPath: bibliographyPath ?? this.bibliographyPath,
      cslStylePath: cslStylePath ?? this.cslStylePath,
      customArguments: customArguments ?? this.customArguments,
      pageSize: pageSize ?? this.pageSize,
      marginSize: marginSize ?? this.marginSize,
    );
  }
}
