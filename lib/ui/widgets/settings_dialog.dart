import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../controllers/editor_controller.dart';
import '../../models/csl_style.dart';
import '../../services/csl_style_service.dart';
import '../../services/spell_check_service.dart';
import '../../services/system_font_service.dart';
import '../theme/app_theme.dart';

/// Settings dialog to configure typography (editor font,
/// unified vs dual preview fonts), referencing / CSL styles, and spellcheck.
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

  // Referencing, CSL & Zotero state
  String? _zoteroTestStatus;
  bool _isZoteroSuccess = false;
  final TextEditingController _cslSearchController = TextEditingController();
  String _cslSearchQuery = '';
  String _cslFormatFilter = 'all';
  List<ZoteroStyleEntry>? _zoteroStylesIndex;
  bool _isLoadingZoteroIndex = false;
  String? _zoteroIndexError;
  final Set<String> _installingSlugs = {};
  String? _cslFeedbackMessage;
  bool _cslFeedbackIsError = false;

  // Spellcheck state
  late bool _spellCheckEnabled;
  late String _spellCheckLanguage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _selectedColorSchemeId = widget.controller.activeColorSchemeId;
    _selectedEditorFont = widget.controller.editorFontFamily;
    _isDualRender = widget.controller.isDualRenderFont;
    _selectedBodyFont = widget.controller.renderBodyFont;
    _selectedHeaderFont = widget.controller.renderHeaderFont;
    _spellCheckEnabled = widget.controller.isSpellCheckEnabled;
    _spellCheckLanguage = widget.controller.spellCheckLanguage;

    _initSystemFonts();
    _loadZoteroStylesIndex();
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
    _cslSearchController.dispose();
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

  Future<void> _loadZoteroStylesIndex({bool forceRefresh = false}) async {
    if (_isLoadingZoteroIndex) return;
    setState(() {
      _isLoadingZoteroIndex = true;
      _zoteroIndexError = null;
    });
    try {
      final index = await widget.controller.cslStyleService
          .fetchZoteroStylesIndex(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _zoteroStylesIndex = index;
        _isLoadingZoteroIndex = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _zoteroIndexError = e.toString();
        _isLoadingZoteroIndex = false;
      });
    }
  }

  Future<void> _installZoteroStyle(String slug, {bool activate = false}) async {
    setState(() {
      _installingSlugs.add(slug);
      _cslFeedbackMessage = null;
    });
    try {
      final style = await widget.controller.installCslStyleFromZotero(slug);
      if (activate) {
        await widget.controller.setCslStyle(style.id);
      }
      if (!mounted) return;
      setState(() {
        _installingSlugs.remove(slug);
        _cslFeedbackIsError = false;
        _cslFeedbackMessage = 'Installed "${style.title}".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installingSlugs.remove(slug);
        _cslFeedbackIsError = true;
        _cslFeedbackMessage = e.toString();
      });
    }
  }

  Future<void> _importLocalCsl() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import CSL Citation Style',
      type: FileType.custom,
      allowedExtensions: ['csl'],
    );
    final path = file?.path;
    if (path == null) return;

    setState(() => _cslFeedbackMessage = null);
    try {
      final style = await widget.controller.importLocalCslStyle(path);
      if (!mounted) return;
      setState(() {
        _cslFeedbackIsError = false;
        _cslFeedbackMessage = 'Imported "${style.title}".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cslFeedbackIsError = true;
        _cslFeedbackMessage = e.toString();
      });
    }
  }

  Future<void> _removeInstalledStyle(CslStyle style) async {
    setState(() => _cslFeedbackMessage = null);
    try {
      await widget.controller.removeCslStyle(style.id);
      if (!mounted) return;
      setState(() {
        _cslFeedbackIsError = false;
        _cslFeedbackMessage = 'Removed "${style.title}".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cslFeedbackIsError = true;
        _cslFeedbackMessage = e.toString();
      });
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
                    icon: Icon(Icons.tune_outlined, size: 18),
                    text: 'General',
                  ),
                  Tab(
                    icon: Icon(Icons.font_download_outlined, size: 18),
                    text: 'Typography',
                  ),
                  Tab(
                    icon: Icon(Icons.book_outlined, size: 18),
                    text: 'Referencing',
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
                    // Tab 1: General (Colour Scheme & About)
                    _buildGeneralTab(theme, isDark, borderColor, mutedColor),

                    // Tab 2: Typography & Fonts
                    _buildTypographyTab(theme, isDark, borderColor, mutedColor),

                    // Tab 3: Referencing & CSL Styles
                    _buildReferencingTab(
                      theme,
                      isDark,
                      borderColor,
                      mutedColor,
                    ),

                    // Tab 4: Spellcheck
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

  /// General Tab: Colour Scheme & About Draftdown
  Widget _buildGeneralTab(
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
          // Section 1: Colour Scheme Dropdown
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

          // Section 2: About Draftdown
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              const Text(
                'About Draftdown',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Draftdown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'v1.1.1',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Distraction-free academic Markdown editor with native citation support and Pandoc export.',
                  style: TextStyle(fontSize: 11.5, color: mutedColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.code, size: 14, color: mutedColor),
                    const SizedBox(width: 6),
                    SelectableText(
                      'https://github.com/davidyshen/Draftdown',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Typography Tab: Monospace Editor font & Unified vs Dual Render fonts
  Widget _buildTypographyTab(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color mutedColor,
  ) {
    final previewBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  /// Referencing, CSL Styles & Zotero Tab
  Widget _buildReferencingTab(
    ThemeData theme,
    bool isDark,
    Color borderColor,
    Color mutedColor,
  ) {
    final installed = widget.controller.availableCslStyles;
    final activeStyle = widget.controller.activeCslStyle;
    final missingId = widget.controller.missingCslStyleId;
    final installedIds = installed.map((s) => s.id).toSet();

    final query = _cslSearchQuery.trim().toLowerCase();
    final filteredOnline = (_zoteroStylesIndex ?? const <ZoteroStyleEntry>[])
        .where((entry) {
          if (_cslFormatFilter != 'all' && entry.format != _cslFormatFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          return entry.title.toLowerCase().contains(query) ||
              entry.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final displayedOnline = filteredOnline.take(50).toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Active Document Citation Style
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Document Citation Style (${widget.controller.currentFileName})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Stored in this document\'s YAML frontmatter (csl: ${widget.controller.cslStyleId}) so each manuscript keeps its own journal style.',
            style: TextStyle(fontSize: 11.5, color: mutedColor),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: installedIds.contains(activeStyle.id)
                    ? activeStyle.id
                    : CslStyleService.defaultStyleId,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                items: installed.map((style) {
                  return DropdownMenuItem<String>(
                    value: style.id,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            style.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildFormatBadge(style.citationFormat, isDark),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    widget.controller.setCslStyle(val);
                    setState(() {});
                  }
                },
              ),
            ),
          ),

          if (missingId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This document specifies "$missingId", which is not installed. Showing ${activeStyle.title} in preview.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.amber[200] : Colors.brown[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _installingSlugs.contains(missingId)
                        ? null
                        : () => _installZoteroStyle(missingId, activate: true),
                    child: _installingSlugs.contains(missingId)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Install', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          if (_cslFeedbackMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (_cslFeedbackIsError ? Colors.red : Colors.green)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    _cslFeedbackIsError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: _cslFeedbackIsError ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cslFeedbackMessage!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _cslFeedbackIsError ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _cslFeedbackMessage = null),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 28),

          // 2. Installed Styles
          Row(
            children: [
              const Icon(Icons.style_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Installed Styles',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_open_outlined, size: 14),
                label: const Text(
                  'Import .csl…',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: _importLocalCsl,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 165),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: installed.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: borderColor),
              itemBuilder: (context, index) {
                final style = installed[index];
                final isActive =
                    style.id == activeStyle.id && missingId == null;
                return InkWell(
                  onTap: () {
                    widget.controller.setCslStyle(style.id);
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 15,
                          color: isActive
                              ? theme.colorScheme.primary
                              : mutedColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                style.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (style.isDependent)
                                Text(
                                  'Parent: ${style.independentParentId}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: mutedColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildFormatBadge(style.citationFormat, isDark),
                        const SizedBox(width: 6),
                        if (style.isBuiltIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mutedColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Built-in',
                              style: TextStyle(fontSize: 10, color: mutedColor),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: 'Remove style',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red[400],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeInstalledStyle(style),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 28),

          // 3. Zotero Styles Library (Online)
          Row(
            children: [
              const Icon(Icons.public, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Zotero Styles Library',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh online styles list',
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _isLoadingZoteroIndex
                    ? null
                    : () => _loadZoteroStylesIndex(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cslSearchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search 10,000+ journal styles (e.g. Ecology, PLOS, Nature)…',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  onChanged: (val) => setState(() => _cslSearchQuery = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in const [
                ('all', 'All'),
                ('author-date', 'Author-Date'),
                ('numeric', 'Numeric'),
                ('note', 'Note'),
              ])
                ChoiceChip(
                  label: Text(entry.$2, style: const TextStyle(fontSize: 11)),
                  selected: _cslFormatFilter == entry.$1,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) =>
                      setState(() => _cslFormatFilter = entry.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 175,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _isLoadingZoteroIndex
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Loading Zotero Styles Library…',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  )
                : _zoteroIndexError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load online styles. Check your internet connection.',
                            style: TextStyle(fontSize: 11.5, color: mutedColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton(
                            onPressed: () =>
                                _loadZoteroStylesIndex(forceRefresh: true),
                            child: const Text(
                              'Retry',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : displayedOnline.isEmpty
                ? Center(
                    child: Text(
                      'No matching styles found.',
                      style: TextStyle(fontSize: 11.5, color: mutedColor),
                    ),
                  )
                : ListView.separated(
                    itemCount:
                        displayedOnline.length +
                        (filteredOnline.length > 50 ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      if (index >= displayedOnline.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Showing first 50 of ${filteredOnline.length} matches — refine your search to narrow results.',
                            style: TextStyle(fontSize: 11, color: mutedColor),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final entry = displayedOnline[index];
                      final isInstalled = installedIds.contains(
                        entry.name.toLowerCase(),
                      );
                      final isInstalling = _installingSlugs.contains(
                        entry.name,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.title,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    entry.name,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: mutedColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildFormatBadge(entry.format, isDark),
                            const SizedBox(width: 8),
                            if (isInstalled)
                              const Text(
                                'Installed ✓',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: isInstalling
                                    ? null
                                    : () => _installZoteroStyle(entry.name),
                                child: isInstalling
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Install',
                                        style: TextStyle(fontSize: 11),
                                      ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 28),

          // 4. Zotero (Better BibTeX) guide + compact Test Connection
          Row(
            children: [
              const Icon(Icons.sync, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Zotero Integration',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'To use Zotero with Draftdown, install the Better BibTeX plugin in Zotero and keep Zotero open while writing.',
                  style: TextStyle(fontSize: 11.5, color: mutedColor),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_find, size: 15),
                label: const Text(
                  'Test Zotero Connection',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: _testZotero,
              ),
            ],
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

  Widget _buildFormatBadge(String format, bool isDark) {
    final isNumeric = format == 'numeric';
    final bgColor = isNumeric
        ? Colors.blue.withValues(alpha: isDark ? 0.22 : 0.12)
        : Colors.teal.withValues(alpha: isDark ? 0.22 : 0.12);
    final fgColor = isNumeric
        ? (isDark ? Colors.blue[200] : Colors.blue[800])
        : (isDark ? Colors.teal[200] : Colors.teal[800]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        format,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
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
