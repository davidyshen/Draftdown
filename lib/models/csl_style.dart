/// Metadata for an installed or bundled CSL (Citation Style Language) style.
class CslStyle {
  /// Slug / identifier (e.g. `apa`, `ieee`, `journal-of-applied-ecology`).
  final String id;

  /// Human-readable title from `<title>` in the `.csl` XML.
  final String title;

  /// CSL citation-format category (`author-date`, `numeric`, `note`, `author`, `label`).
  final String citationFormat;

  /// Whether this style is bundled with Draftdown (cannot be removed).
  final bool isBuiltIn;

  /// Parent style ID when this is a dependent style (`rel="independent-parent"`).
  final String? independentParentId;

  /// Absolute filesystem path to the `.csl` file on disk.
  final String? filePath;

  const CslStyle({
    required this.id,
    required this.title,
    required this.citationFormat,
    this.isBuiltIn = false,
    this.independentParentId,
    this.filePath,
  });

  /// Whether live preview / direct export should render numeric citations (`[1]`).
  bool get isNumeric => citationFormat == 'numeric';

  /// Whether this style delegates its formatting rules to an independent parent style.
  bool get isDependent =>
      independentParentId != null && independentParentId!.isNotEmpty;

  CslStyle copyWith({
    String? id,
    String? title,
    String? citationFormat,
    bool? isBuiltIn,
    String? independentParentId,
    String? filePath,
  }) {
    return CslStyle(
      id: id ?? this.id,
      title: title ?? this.title,
      citationFormat: citationFormat ?? this.citationFormat,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      independentParentId: independentParentId ?? this.independentParentId,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CslStyle &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filePath == other.filePath;

  @override
  int get hashCode => Object.hash(id, filePath);
}

/// Entry from the Zotero Style Repository index (`styles.json`).
class ZoteroStyleEntry {
  final String name;
  final String title;
  final String format;
  final List<String> fields;
  final bool isDependent;
  final String? href;
  final String? updated;

  const ZoteroStyleEntry({
    required this.name,
    required this.title,
    required this.format,
    this.fields = const [],
    this.isDependent = false,
    this.href,
    this.updated,
  });

  factory ZoteroStyleEntry.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    String format = 'author-date';
    List<String> fields = const [];
    if (rawCategories is Map) {
      final rawFormat = rawCategories['format'];
      if (rawFormat is String && rawFormat.isNotEmpty) {
        format = rawFormat;
      }
      final rawFields = rawCategories['fields'];
      if (rawFields is List) {
        fields = rawFields.map((e) => e.toString()).toList(growable: false);
      }
    }

    final rawDep = json['dependent'];
    final isDependent = rawDep == true || rawDep == 1 || rawDep == '1';

    return ZoteroStyleEntry(
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      format: format,
      fields: fields,
      isDependent: isDependent,
      href: json['href']?.toString(),
      updated: json['updated']?.toString(),
    );
  }
}
