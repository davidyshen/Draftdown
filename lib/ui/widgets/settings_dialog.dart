import 'package:flutter/material.dart';

import '../../controllers/editor_controller.dart';
import '../../services/spell_check_service.dart';
import '../../services/system_font_service.dart';
import '../theme/app_theme.dart';

/// Settings dialog to configure typography (editor font,
/// unified vs dual preview fonts), Zotero integration, and spellcheck.
class SettingsDialog extends StatefulWidget {
  final EditorController controller;

  const SettingsDialog({super.key, required this.controller});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Typography & Colour Scheme state
  late String _selectedColorSchemeId;
  late String _selectedEditorFont;
  late bool _isDualRender;
  late String _selectedBodyFont;
  late String _selectedHeaderFont;
  List<String> _monospaceFonts = const [];
  List<String> _renderFonts = const [];
  bool _isLoadingFonts = true;

  // Zotero & Bibliography state
  final TextEditingController _bibPathController = TextEditingController();
  String? _zoteroTestStatus;
  bool _isZoteroSuccess = false;

  // Spellcheck state
  late bool _spellCheckEnabled;
  late String _spellCheckLanguage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _selectedColorSchemeId = widget.controller.activeColorSchemeId;
    _selectedEditorFont = widget.controller.editorFontFamily;
    _isDualRender = widget.controller.isDualRenderFont;
    _selectedBodyFont = widget.controller.renderBodyFont;
    _selectedHeaderFont = widget.controller.renderHeaderFont;
    _spellCheckEnabled = widget.controller.isSpellCheckEnabled;
    _spellCheckLanguage = widget.controller.spellCheckLanguage;

    _bibPathController.text = widget.controller.bibliographyPath ?? '';
    _initSystemFonts();
  }

  void _initSystemFonts() {
    final cached = SystemFontService.instance.cachedFonts;
    if (cached != null) {
      _monospaceFonts = cached.monospaceFonts;
      _renderFonts = cached.allFonts;
      _isLoadingFonts = false;
      return;
    }
    _loadSystemFonts();
  }

  Future<void> _loadSystemFonts() async {
    final fonts = await SystemFontService.instance.getInstalledFonts();
    if (!mounted) return;
    setState(() {
      _monospaceFonts = fonts.monospaceFonts;
      _renderFonts = fonts.allFonts;
      _isLoadingFonts = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bibPathController.dispose();
    super.dispose();
  }

  void _onColorSchemeChanged(String newSchemeId) {
    setState(() => _selectedColorSchemeId = newSchemeId);
    widget.controller.setColorScheme(newSchemeId);
  }

  void _onEditorFontChanged(String newFont) {
    setState(() => _selectedEditorFont = newFont);
    widget.controller.updateTypography(editorFontFamily: newFont);
  }

  void _onDualModeChanged(bool isDual) {
    setState(() => _isDualRender = isDual);
    widget.controller.updateTypography(isDualRenderFont: isDual);
  }

  void _onBodyFontChanged(String newFont) {
    setState(() => _selectedBodyFont = newFont);
    widget.controller.updateTypography(renderBodyFont: newFont);
  }

  void _onHeaderFontChanged(String newFont) {
    setState(() => _selectedHeaderFont = newFont);
    widget.controller.updateTypography(renderHeaderFont: newFont);
  }

  Future<void> _testZotero() async {
    await widget.controller.checkZoteroConnection();
    setState(() {
      if (widget.controller.isZoteroConnected) {
        _isZoteroSuccess = true;
        _zoteroTestStatus = 'Successfully connected to Zotero (Better BibTeX)!';
      } else {
        _isZoteroSuccess = false;
        _zoteroTestStatus = 'Could not reach Zotero. Ensure Zotero is running with the Better BibTeX plugin enabled.';
      }
    });
  }

  Future<void> _browseBib() async {
    final path = await widget.controller.fileService.pickBibliographyFile();
    if (path != null) {
      _bibPathController.text = path;
      await widget.controller.loadBibliographyFile(path);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final mutedColor = isDark
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: surfaceColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Application Settings',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tab navigation
              TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: mutedColor,
                indicatorColor: theme.colorScheme.primary,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return theme.colorScheme.primary.withValues(alpha: 0.12);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04);
                  }
                  return Colors.transparent;
                }),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.font_download_outlined, size: 18),
                    text: 'Typography',
                  ),
                  Tab(
                    icon: Icon(Icons.book_outlined, size: 18),
                    text: 'Zotero',
                  ),
                  Tab(
                    icon: Icon(Icons.spellcheck, size: 18),
                    text: 'Spellcheck',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tab contents
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Typography & Fonts
                    _buildTypographyTab(theme, isDark, borderColor, mutedColor),

                    // Tab 2: Zotero & Bibliography
                    _buildZoteroTab(theme, isDark, borderColor, mutedColor),

                    // Tab 3: Spellcheck
                    _buildSpellcheckTab(theme, isDark, borderColor, mutedColor),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Typography & Appearance Tab: Colour Scheme, Monospace Editor font & Unified vs Dual Render fonts
  Widget _buildTypographyTab(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color mutedColor,
  ) {
    final previewBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final activeScheme = AppTheme.schemeById(_selectedColorSchemeId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 0: Colour Scheme Dropdown
          Row(
            children: [
              const Icon(Icons.palette_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Colour Scheme',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select a dark mode palette or light theme for the workspace, Markdown syntax highlighting, and live preview.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('colour-scheme-dropdown'),
                focusColor: Colors.transparent,
                dropdownColor: isDark
                    ? AppTheme.darkSurface
                    : AppTheme.lightSurface,
                value:
                    AppTheme.availableColorSchemes.any(
                      (s) => s.id == _selectedColorSchemeId,
                    )
                    ? _selectedColorSchemeId
                    : AppTheme.availableColorSchemes.first.id,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                items: AppTheme.availableColorSchemes.map((scheme) {
                  return DropdownMenuItem<String>(
                    value: scheme.id,
                    child: Row(
                      children: [
                        _buildSchemeSwatchPreview(scheme),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            scheme.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.isDark
                                ? scheme.accent.withValues(alpha: 0.16)
                                : Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            scheme.isDark ? 'Dark' : 'Light',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.isDark
                                  ? scheme.accent
                                  : Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _onColorSchemeChanged(val);
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Active Palette Description & Swatch Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    activeScheme.description,
                    style: TextStyle(fontSize: 11.5, color: mutedColor),
                  ),
                ),
                const SizedBox(width: 12),
                _buildSchemeSwatchPreview(activeScheme, size: 14),
              ],
            ),
          ),

          const Divider(height: 28),

          // Section 1: Monospace Editor Font
          Row(
            children: [
              const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Markdown Editor Font',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Applied to the raw Markdown editing area, line numbers gutter, and code blocks.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),

          // Monospace Font Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _isLoadingFonts || _monospaceFonts.isEmpty
                ? _buildFontLoadingRow(mutedColor)
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      focusColor: Colors.transparent,
                      value: _monospaceFonts.contains(_selectedEditorFont)
                          ? _selectedEditorFont
                          : _monospaceFonts.first,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      items: _monospaceFonts.map((font) {
                        return DropdownMenuItem<String>(
                          value: font,
                          child: Row(
                            children: [
                              Text(
                                font,
                                style: TextStyle(
                                  fontFamily: font,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '(Monospace)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _onEditorFontChanged(val);
                      },
                    ),
                  ),
          ),

          const SizedBox(height: 8),

          // Monospace Live Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              '1  # Ecological Resilience\n2  Ecosystem complexity and recovery [@holling1973resilience]\n3  const double shannonIndex = 2.4183;',
              style: TextStyle(
                fontFamily: _selectedEditorFont,
                fontFamilyFallback: AppTheme.editorFontFamilyFallback,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),

          const Divider(height: 32),

          // Section 2: Rendered Markdown Preview Fonts (Unified vs Dual)
          Row(
            children: [
              const Icon(Icons.preview_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Rendered Preview Fonts',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Customise the typography of formatted Markdown preview. Choose a single unified font or dual fonts for distinct headers and body.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),

          // Segmented button: Unified vs Dual
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.format_shapes, size: 15),
                label: Text(
                  'Unified (Single Font)',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.view_headline, size: 15),
                label: Text(
                  'Dual (Separate Header & Body)',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
            selected: {_isDualRender},
            onSelectionChanged: (Set<bool> newSelection) {
              _onDualModeChanged(newSelection.first);
            },
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),

          const SizedBox(height: 12),

          // Font Selectors (Unified vs Dual)
          if (!_isDualRender) ...[
            // Unified Font Selector
            const Text(
              'Render Font (Headers & Body)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _buildFontDropdown(
              value: _selectedBodyFont,
              onChanged: (val) {
                _onBodyFontChanged(val);
                _onHeaderFontChanged(val);
              },
              borderColor: borderColor,
            ),
          ] else ...[
            // Dual Font Selectors
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Header Font (H1 - H6)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildFontDropdown(
                        value: _selectedHeaderFont,
                        onChanged: _onHeaderFontChanged,
                        borderColor: borderColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Body Font (Paragraphs & Tables)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildFontDropdown(
                        value: _selectedBodyFont,
                        onChanged: _onBodyFontChanged,
                        borderColor: borderColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Render Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Complexity of Restored Ecosystems',
                  style: TextStyle(
                    fontFamily: _isDualRender
                        ? _selectedHeaderFont
                        : _selectedBodyFont,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ecological resilience describes the capacity of an ecosystem to absorb disturbance whilst maintaining core trophic structure and species interactions. Long-term restoration monitors biodiversity recovery across fragmented habitats.',
                  style: TextStyle(
                    fontFamily: _selectedBodyFont,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeSwatchPreview(AppColorScheme scheme, {double size = 12}) {
    final colors = [
      scheme.bg,
      scheme.surface,
      scheme.accent,
      scheme.header1Color,
      scheme.citationColor,
      scheme.mathColor,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors.map((c) {
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.border.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontLoadingRow(Color? mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading installed local fonts...',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFontDropdown({
    required String value,
    required ValueChanged<String> onChanged,
    required Color borderColor,
  }) {
    if (_isLoadingFonts || _renderFonts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: _buildFontLoadingRow(null),
      );
    }

    final effectiveValue = _renderFonts.contains(value)
        ? value
        : _renderFonts.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusColor: Colors.transparent,
          value: effectiveValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: _renderFonts.map((font) {
            return DropdownMenuItem<String>(
              value: font,
              child: Text(
                font,
                style: TextStyle(fontFamily: font, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  /// Zotero & Bibliography Tab
  Widget _buildZoteroTab(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color mutedColor,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.library_books_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Default Bibliography Database',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select a BibTeX (.bib) or CSL JSON (.json) file exported from Zotero to enable citeproc compilation and auto-complete.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bibPathController,
                  readOnly: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'No bibliography chosen (using built-in sample)',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open, size: 14),
                label: const Text(
                  'Browse...',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: _browseBib,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.controller.bibliographyStatus,
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),

          const Divider(height: 32),

          Row(
            children: [
              const Icon(Icons.sync, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Zotero Live Integration (Better BibTeX)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'When Zotero is running with the Better BibTeX plugin enabled, Draftdown can connect to http://127.0.0.1:23119/better-bibtex/ for live bibliography sync.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.wifi_find, size: 16),
            label: const Text(
              'Test Zotero Connection',
              style: TextStyle(fontSize: 11.5),
            ),
            onPressed: _testZotero,
          ),
          if (_zoteroTestStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isZoteroSuccess
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    _isZoteroSuccess
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 16,
                    color: _isZoteroSuccess ? Colors.green : Colors.amber[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _zoteroTestStatus!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isZoteroSuccess
                            ? Colors.green
                            : Colors.amber[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Spellcheck Tab: Enable/disable, dictionary locale, and custom dictionary management.
  Widget _buildSpellcheckTab(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color mutedColor,
  ) {
    final customWords = widget.controller.customDictionaryWords.toList()
      ..sort();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Enable Markdown Spellchecker',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Highlight misspelled prose in the Markdown editor while skipping code blocks, LaTeX math, URLs, and citation keys.',
              style: TextStyle(fontSize: 11.5, color: mutedColor),
            ),
            value: _spellCheckEnabled,
            onChanged: (val) {
              setState(() => _spellCheckEnabled = val);
              widget.controller.setSpellCheckEnabled(val);
            },
          ),

          const SizedBox(height: 16),

          const Text(
            'Dictionary Language',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Select the English variant used to check spelling.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('spellcheck-language-dropdown'),
                focusColor: Colors.transparent,
                dropdownColor: isDark
                    ? AppTheme.darkSurface
                    : AppTheme.lightSurface,
                value:
                    SpellCheckLanguage.supported.any(
                      (l) => l.tag == _spellCheckLanguage,
                    )
                    ? _spellCheckLanguage
                    : SpellCheckLanguage.supported.first.tag,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                items: SpellCheckLanguage.supported.map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang.tag,
                    child: Text(
                      '${lang.label} (${lang.tag})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _spellCheckLanguage = val);
                    widget.controller.setSpellCheckLanguage(val);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Custom Dictionary',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Words you have added via the editor context menu.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),

          if (customWords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'No custom words added yet. Right-click a underlined word in the editor and choose "Add to dictionary".',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customWords.map((word) {
                return Chip(
                  label: Text(word, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {});
                    widget.controller.removeWordFromDictionary(word);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
