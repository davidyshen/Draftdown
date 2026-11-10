import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Settings dialog to configure typography (monospace editor font,
/// unified vs dual preview fonts), Pandoc executable paths, and Zotero integration.
class SettingsDialog extends StatefulWidget {
  final EditorController controller;

  const SettingsDialog({
    super.key,
    required this.controller,
  });

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

  // Pandoc state
  final TextEditingController _pandocPathController = TextEditingController();
  String? _pandocTestStatus;
  bool _isPandocSuccess = false;

  // Zotero & Bibliography state
  final TextEditingController _bibPathController = TextEditingController();
  String? _zoteroTestStatus;
  bool _isZoteroSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _selectedColorSchemeId = widget.controller.activeColorSchemeId;
    _selectedEditorFont = widget.controller.editorFontFamily;
    _isDualRender = widget.controller.isDualRenderFont;
    _selectedBodyFont = widget.controller.renderBodyFont;
    _selectedHeaderFont = widget.controller.renderHeaderFont;

    _bibPathController.text = widget.controller.bibliographyPath ?? '';
    _loadCustomPandocPath();
  }

  Future<void> _loadCustomPandocPath() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString('mdwriter_custom_pandoc_path') ?? '';
    _pandocPathController.text = custom;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pandocPathController.dispose();
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

  Future<void> _testPandoc() async {
    final path = _pandocPathController.text.trim();
    widget.controller.pandocService
        .setCustomPath(path.isNotEmpty ? path : null);
    await widget.controller.checkPandocAvailability();

    setState(() {
      if (widget.controller.isPandocAvailable) {
        _isPandocSuccess = true;
        _pandocTestStatus =
            'Pandoc detected: ${widget.controller.pandocVersion ?? "Available"}';
      } else {
        _isPandocSuccess = false;
        _pandocTestStatus =
            'Pandoc executable not found at specified location.';
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mdwriter_custom_pandoc_path', path);
  }

  Future<void> _resetPandocToBundled() async {
    _pandocPathController.clear();
    widget.controller.pandocService.setCustomPath(null);
    await widget.controller.checkPandocAvailability();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mdwriter_custom_pandoc_path');
    setState(() {
      _pandocTestStatus = widget.controller.isPandocAvailable
          ? 'Reverted to ${widget.controller.pandocVersion ?? "bundled Pandoc"}'
          : null;
      _isPandocSuccess = widget.controller.isPandocAvailable;
    });
  }

  Future<void> _testZotero() async {
    await widget.controller.checkZoteroConnection();
    setState(() {
      if (widget.controller.isZoteroConnected) {
        _isZoteroSuccess = true;
        _zoteroTestStatus =
            'Successfully connected to Zotero (Better BibTeX)!';
      } else {
        _isZoteroSuccess = false;
        _zoteroTestStatus =
            'Could not reach Zotero. Ensure Zotero is running with the Better BibTeX plugin enabled.';
      }
    });
  }

  Future<void> _browseBib() async {
    final path =
        await widget.controller.fileService.pickBibliographyFile();
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
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final mutedColor =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: surfaceColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
          maxHeight: 620,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.settings,
                      color: theme.colorScheme.primary, size: 22),
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
                    icon: Icon(Icons.output, size: 18),
                    text: 'Pandoc',
                  ),
                  Tab(
                    icon: Icon(Icons.book_outlined, size: 18),
                    text: 'Zotero',
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
                    _buildTypographyTab(
                        theme, isDark, borderColor, mutedColor),

                    // Tab 2: Pandoc Configuration
                    _buildPandocTab(theme, isDark, borderColor, mutedColor),

                    // Tab 3: Zotero & Bibliography
                    _buildZoteroTab(theme, isDark, borderColor, mutedColor),
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
    final previewBg =
        isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
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
                dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                value: AppTheme.availableColorSchemes
                        .any((s) => s.id == _selectedColorSchemeId)
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
                'Markdown Editor Font (Strictly Monospace)',
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
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                focusColor: Colors.transparent,
                value: AppTheme.availableMonospaceFonts.contains(_selectedEditorFont)
                    ? _selectedEditorFont
                    : AppTheme.availableMonospaceFonts.first,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                items: AppTheme.availableMonospaceFonts.map((font) {
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
              '1  # Literate Computing\n2  Literate programming as introduced by [@knuth1984literate]\n3  const double pi = 3.14159265;',
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
                label: Text('Unified (Single Font)',
                    style: TextStyle(fontSize: 11.5)),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.view_headline, size: 15),
                label: Text('Dual (Separate Header & Body)',
                    style: TextStyle(fontSize: 11.5)),
              ),
            ],
            selected: {_isDualRender},
            onSelectionChanged: (Set<bool> newSelection) {
              _onDualModeChanged(newSelection.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
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
                            fontSize: 12, fontWeight: FontWeight.w600),
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
                            fontSize: 12, fontWeight: FontWeight.w600),
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
                  'The Architecture of Literate Systems',
                  style: TextStyle(
                    fontFamily:
                        _isDualRender ? _selectedHeaderFont : _selectedBodyFont,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Computing machinery and intelligence explore the intersection between formal logic and human communication. Attention mechanisms enable scalable sequence transduction without recurrence.',
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

  Widget _buildFontDropdown({
    required String value,
    required ValueChanged<String> onChanged,
    required Color borderColor,
  }) {
    final effectiveValue =
        AppTheme.availableRenderFonts.contains(value)
            ? value
            : AppTheme.availableRenderFonts.first;

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
          items: AppTheme.availableRenderFonts.map((font) {
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

  /// Pandoc Tab: Bundled binary status & optional custom executable override
  Widget _buildPandocTab(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color mutedColor,
  ) {
    final isUsingBundled = widget.controller.isUsingBundledPandoc;
    final isAvailable = widget.controller.isPandocAvailable;
    final versionStr = widget.controller.pandocVersion ?? 'Pandoc 3.6.3 (Bundled)';
    final resolvedPath = widget.controller.resolvedPandocPath ?? 'Bundled with application';
    final cardBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Bundled Pandoc Status Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAvailable
                  ? Colors.green.withValues(alpha: 0.08)
                  : cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAvailable
                    ? Colors.green.withValues(alpha: 0.3)
                    : borderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isUsingBundled
                          ? Icons.inventory_2_outlined
                          : Icons.check_circle_outline,
                      color: isAvailable ? Colors.green : mutedColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUsingBundled
                          ? 'Bundled Pandoc Standalone Binary'
                          : 'Custom Pandoc Binary Active',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.green : null,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        versionStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isAvailable ? Colors.green : mutedColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'MDWriter bundles a complete standalone Pandoc distribution so you never need to install, configure, or manage external dependencies separately. All document export formats (PDF, Word DOCX, HTML5, EPUB, LaTeX, ODT, RTF) and academic citation processing work immediately.',
                  style: TextStyle(fontSize: 11.5, color: mutedColor, height: 1.45),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Resolved location: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor),
                    ),
                    Expanded(
                      child: Text(
                        resolvedPath,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: AppTheme.editorFontFamily,
                          color: isDark ? Colors.blue[200] : Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Custom Executable Override
          Row(
            children: [
              const Icon(Icons.tune_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Custom Binary Override (Optional)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Leave this blank to always use the bundled Pandoc binary. If you maintain a custom LaTeX installation or specialised Pandoc build, specify its path below.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pandocPathController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: Platform.isWindows
                        ? r'C:\Program Files\Pandoc\pandoc.exe'
                        : '/usr/local/bin/pandoc',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _testPandoc,
                child: const Text('Test / Save',
                    style: TextStyle(fontSize: 11.5)),
              ),
              if (_pandocPathController.text.isNotEmpty) ...[
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _resetPandocToBundled,
                  child: const Text('Reset to Bundled',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ],
          ),
          if (_pandocTestStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isPandocSuccess
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPandocSuccess
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 16,
                    color: _isPandocSuccess ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pandocTestStatus!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isPandocSuccess
                            ? Colors.green
                            : Colors.redAccent,
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
                    hintText:
                        'No bibliography chosen (using built-in sample)',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
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
                label:
                    const Text('Browse...', style: TextStyle(fontSize: 11.5)),
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
            'When Zotero is running with the Better BibTeX plugin enabled, MDWriter can connect to http://127.0.0.1:23119/better-bibtex/ for live bibliography sync.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.wifi_find, size: 16),
            label: const Text('Test Zotero Connection',
                style: TextStyle(fontSize: 11.5)),
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
}
