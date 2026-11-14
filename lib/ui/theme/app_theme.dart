import 'package:flutter/material.dart';

/// Represents a complete UI, preview, and syntax colour scheme for Draftdown.
class AppColorScheme {
  final String id;
  final String name;
  final String description;
  final Brightness brightness;

  // Core UI surfaces & workspace
  final Color bg;
  final Color surface;
  final Color sidebar;
  final Color gutter;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;

  // Preview workspace & paper sheet
  final Color previewCanvas;
  final Color previewPage;
  final Color previewBorder;

  // Editor syntax highlighting accents
  final Color header1Color;
  final Color header2Color;
  final Color header3Color;
  final Color header4to6Color;
  final Color inlineCodeColor;
  final Color citationColor;
  final Color mathColor;
  final Color warningOrImageColor;

  const AppColorScheme({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.sidebar,
    required this.gutter,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.previewCanvas,
    required this.previewPage,
    required this.previewBorder,
    required this.header1Color,
    required this.header2Color,
    required this.header3Color,
    required this.header4to6Color,
    required this.inlineCodeColor,
    required this.citationColor,
    required this.mathColor,
    required this.warningOrImageColor,
  });

  bool get isDark => brightness == Brightness.dark;
}

/// Clean, modern theme and colour scheme definitions for Draftdown.
class AppTheme {
  // ===========================================================================
  // Dark Mode Palettes
  // ===========================================================================

  static const AppColorScheme slateDarkScheme = AppColorScheme(
    id: 'slate_dark',
    name: 'Slate Navy (Default Dark)',
    description: 'Deep slate blue workspace with crisp sky and royal blue accents',
    brightness: Brightness.dark,
    bg: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    sidebar: Color(0xFF131D2E),
    gutter: Color(0xFF162032),
    border: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    accent: Color(0xFF3B82F6),
    previewCanvas: Color(0xFF0F172A),
    previewPage: Color(0xFF1E293B),
    previewBorder: Color(0xFF334155),
    header1Color: Color(0xFF38BDF8),
    header2Color: Color(0xFF60A5FA),
    header3Color: Color(0xFF818CF8),
    header4to6Color: Color(0xFFA5B4FC),
    inlineCodeColor: Color(0xFFF472B6),
    citationColor: Color(0xFFC084FC),
    mathColor: Color(0xFF34D399),
    warningOrImageColor: Color(0xFFF59E0B),
  );

  static const AppColorScheme tokyoNightScheme = AppColorScheme(
    id: 'tokyo_night',
    name: 'Tokyo Night (Dark)',
    description: 'Storm indigo night palette inspired by neon lights of downtown Tokyo',
    brightness: Brightness.dark,
    bg: Color(0xFF16161E),
    surface: Color(0xFF1A1B26),
    sidebar: Color(0xFF13141C),
    gutter: Color(0xFF161720),
    border: Color(0xFF292E42),
    textPrimary: Color(0xFFC0CAF5),
    textSecondary: Color(0xFFA9B1D6),
    textMuted: Color(0xFF565F89),
    accent: Color(0xFF7AA2F7),
    previewCanvas: Color(0xFF13141C),
    previewPage: Color(0xFF1A1B26),
    previewBorder: Color(0xFF292E42),
    header1Color: Color(0xFF7DCFFF),
    header2Color: Color(0xFF7AA2F7),
    header3Color: Color(0xFFBB9AF7),
    header4to6Color: Color(0xFF9AA5CE),
    inlineCodeColor: Color(0xFFFF9E64),
    citationColor: Color(0xFFBB9AF7),
    mathColor: Color(0xFF73DACA),
    warningOrImageColor: Color(0xFFE0AF68),
  );

  static const AppColorScheme draculaScheme = AppColorScheme(
    id: 'dracula',
    name: 'Dracula (Dark)',
    description: 'High-contrast gothic dark palette with vibrant purple, pink, and cyan accents',
    brightness: Brightness.dark,
    bg: Color(0xFF1E1F29),
    surface: Color(0xFF282A36),
    sidebar: Color(0xFF21222C),
    gutter: Color(0xFF242632),
    border: Color(0xFF44475A),
    textPrimary: Color(0xFFF8F8F2),
    textSecondary: Color(0xFFBFBFBF),
    textMuted: Color(0xFF6272A4),
    accent: Color(0xFFBD93F9),
    previewCanvas: Color(0xFF1E1F29),
    previewPage: Color(0xFF282A36),
    previewBorder: Color(0xFF44475A),
    header1Color: Color(0xFFFF79C6),
    header2Color: Color(0xFFBD93F9),
    header3Color: Color(0xFF8BE9FD),
    header4to6Color: Color(0xFFF1FA8C),
    inlineCodeColor: Color(0xFFFFB86C),
    citationColor: Color(0xFFBD93F9),
    mathColor: Color(0xFF50FA7B),
    warningOrImageColor: Color(0xFFF1FA8C),
  );

  static const AppColorScheme catppuccinMochaScheme = AppColorScheme(
    id: 'catppuccin_mocha',
    name: 'Catppuccin Mocha (Dark)',
    description: 'Soothing pastel mocha dark theme with warm lavender and mauve tones',
    brightness: Brightness.dark,
    bg: Color(0xFF11111B),
    surface: Color(0xFF1E1E2E),
    sidebar: Color(0xFF181825),
    gutter: Color(0xFF181825),
    border: Color(0xFF313244),
    textPrimary: Color(0xFFCDD6F4),
    textSecondary: Color(0xFFBAC2DE),
    textMuted: Color(0xFF6C7086),
    accent: Color(0xFFCBA6F7),
    previewCanvas: Color(0xFF11111B),
    previewPage: Color(0xFF1E1E2E),
    previewBorder: Color(0xFF313244),
    header1Color: Color(0xFF89DCEB),
    header2Color: Color(0xFF89B4FA),
    header3Color: Color(0xFFCBA6F7),
    header4to6Color: Color(0xFFB4BEFE),
    inlineCodeColor: Color(0xFFF38BA8),
    citationColor: Color(0xFFF5C2E7),
    mathColor: Color(0xFFA6E3A1),
    warningOrImageColor: Color(0xFFFAB387),
  );

  static const AppColorScheme nordDarkScheme = AppColorScheme(
    id: 'nord_dark',
    name: 'Nord Polar Night (Dark)',
    description: 'Arctic north-bluish dark palette with calm frost cyan and aurora accents',
    brightness: Brightness.dark,
    bg: Color(0xFF242933),
    surface: Color(0xFF2E3440),
    sidebar: Color(0xFF292E39),
    gutter: Color(0xFF2B303C),
    border: Color(0xFF434C5E),
    textPrimary: Color(0xFFECEFF4),
    textSecondary: Color(0xFFD8DEE9),
    textMuted: Color(0xFF7B88A1),
    accent: Color(0xFF88C0D0),
    previewCanvas: Color(0xFF242933),
    previewPage: Color(0xFF2E3440),
    previewBorder: Color(0xFF434C5E),
    header1Color: Color(0xFF88C0D0),
    header2Color: Color(0xFF81A1C1),
    header3Color: Color(0xFF5E81AC),
    header4to6Color: Color(0xFF8FBCBB),
    inlineCodeColor: Color(0xFFD08770),
    citationColor: Color(0xFFB48EAD),
    mathColor: Color(0xFFA3BE8C),
    warningOrImageColor: Color(0xFFEBCB8B),
  );

  static const AppColorScheme gruvboxDarkScheme = AppColorScheme(
    id: 'gruvbox_dark',
    name: 'Gruvbox Dark',
    description: 'Retro groove warm dark palette with amber, olive, and terracotta accents',
    brightness: Brightness.dark,
    bg: Color(0xFF1D2021),
    surface: Color(0xFF282828),
    sidebar: Color(0xFF222222),
    gutter: Color(0xFF242424),
    border: Color(0xFF3C3836),
    textPrimary: Color(0xFFEBDBB2),
    textSecondary: Color(0xFFD5C4A1),
    textMuted: Color(0xFF928374),
    accent: Color(0xFFFABD2F),
    previewCanvas: Color(0xFF1D2021),
    previewPage: Color(0xFF282828),
    previewBorder: Color(0xFF3C3836),
    header1Color: Color(0xFFFE8019),
    header2Color: Color(0xFFFABD2F),
    header3Color: Color(0xFF8EC07C),
    header4to6Color: Color(0xFF83A598),
    inlineCodeColor: Color(0xFFFB4934),
    citationColor: Color(0xFFD3869B),
    mathColor: Color(0xFFB8BB26),
    warningOrImageColor: Color(0xFFFE8019),
  );

  static const AppColorScheme monokaiNightScheme = AppColorScheme(
    id: 'monokai_night',
    name: 'Monokai Charcoal (Dark)',
    description: 'Warm charcoal dark workspace with vivid magenta, cyan, and lime highlights',
    brightness: Brightness.dark,
    bg: Color(0xFF1E1F1C),
    surface: Color(0xFF272822),
    sidebar: Color(0xFF21221D),
    gutter: Color(0xFF23241E),
    border: Color(0xFF3E3D32),
    textPrimary: Color(0xFFF8F8F2),
    textSecondary: Color(0xFFCFCFC2),
    textMuted: Color(0xFF75715E),
    accent: Color(0xFF66D9EF),
    previewCanvas: Color(0xFF1E1F1C),
    previewPage: Color(0xFF272822),
    previewBorder: Color(0xFF3E3D32),
    header1Color: Color(0xFFF92672),
    header2Color: Color(0xFF66D9EF),
    header3Color: Color(0xFFAE81FF),
    header4to6Color: Color(0xFFE6DB74),
    inlineCodeColor: Color(0xFFFD971F),
    citationColor: Color(0xFFAE81FF),
    mathColor: Color(0xFFA6E22E),
    warningOrImageColor: Color(0xFFE6DB74),
  );

  static const AppColorScheme solarizedDarkScheme = AppColorScheme(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    description: 'Precision low-eye-strain deep teal dark palette by Ethan Schoonover',
    brightness: Brightness.dark,
    bg: Color(0xFF00212B),
    surface: Color(0xFF002B36),
    sidebar: Color(0xFF073642),
    gutter: Color(0xFF04303C),
    border: Color(0xFF164B58),
    textPrimary: Color(0xFFEEE8D5),
    textSecondary: Color(0xFF93A1A1),
    textMuted: Color(0xFF657B83),
    accent: Color(0xFF268BD2),
    previewCanvas: Color(0xFF00212B),
    previewPage: Color(0xFF002B36),
    previewBorder: Color(0xFF164B58),
    header1Color: Color(0xFF2AA198),
    header2Color: Color(0xFF268BD2),
    header3Color: Color(0xFF6C71C4),
    header4to6Color: Color(0xFF859900),
    inlineCodeColor: Color(0xFFD33682),
    citationColor: Color(0xFF6C71C4),
    mathColor: Color(0xFF859900),
    warningOrImageColor: Color(0xFFB58900),
  );

  static const AppColorScheme everforestDarkScheme = AppColorScheme(
    id: 'everforest_dark',
    name: 'Everforest (Dark)',
    description: 'Soft woodland green-grey dark palette designed for comfortable long writing sessions',
    brightness: Brightness.dark,
    bg: Color(0xFF1E2326),
    surface: Color(0xFF272E33),
    sidebar: Color(0xFF21272B),
    gutter: Color(0xFF232A2E),
    border: Color(0xFF374145),
    textPrimary: Color(0xFFD3C6AA),
    textSecondary: Color(0xFF9DA9A0),
    textMuted: Color(0xFF7A8478),
    accent: Color(0xFFA7C080),
    previewCanvas: Color(0xFF1E2326),
    previewPage: Color(0xFF272E33),
    previewBorder: Color(0xFF374145),
    header1Color: Color(0xFFA7C080),
    header2Color: Color(0xFF83C092),
    header3Color: Color(0xFF7FBBB3),
    header4to6Color: Color(0xFFDBBC7F),
    inlineCodeColor: Color(0xFFE67E80),
    citationColor: Color(0xFFD699B6),
    mathColor: Color(0xFF83C092),
    warningOrImageColor: Color(0xFFE69875),
  );

  static const AppColorScheme oledMidnightScheme = AppColorScheme(
    id: 'oled_midnight',
    name: 'Midnight OLED (Pitch Black)',
    description: 'True pitch-black workspace with crisp zinc borders and electric indigo accents',
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF0A0A0D),
    sidebar: Color(0xFF050507),
    gutter: Color(0xFF07070A),
    border: Color(0xFF27272A),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    accent: Color(0xFF6366F1),
    previewCanvas: Color(0xFF000000),
    previewPage: Color(0xFF0A0A0D),
    previewBorder: Color(0xFF27272A),
    header1Color: Color(0xFF38BDF8),
    header2Color: Color(0xFF818CF8),
    header3Color: Color(0xFFA78BFA),
    header4to6Color: Color(0xFFC4B5FD),
    inlineCodeColor: Color(0xFFFB7185),
    citationColor: Color(0xFFC084FC),
    mathColor: Color(0xFF34D399),
    warningOrImageColor: Color(0xFFFBBF24),
  );

  // ===========================================================================
  // Light Mode Palettes
  // ===========================================================================

  static const AppColorScheme slateLightScheme = AppColorScheme(
    id: 'slate_light',
    name: 'Slate Paper (Default Light)',
    description: 'Clean white paper sheet over a neutral cool-slate desktop canvas',
    brightness: Brightness.light,
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    sidebar: Color(0xFFF1F5F9),
    gutter: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    accent: Color(0xFF2563EB),
    previewCanvas: Color(0xFFE2E8F0),
    previewPage: Color(0xFFFFFFFF),
    previewBorder: Color(0xFFCBD5E1),
    header1Color: Color(0xFF1D4ED8),
    header2Color: Color(0xFF2563EB),
    header3Color: Color(0xFF4338CA),
    header4to6Color: Color(0xFF475569),
    inlineCodeColor: Color(0xFFBE185D),
    citationColor: Color(0xFF7C3AED),
    mathColor: Color(0xFF047857),
    warningOrImageColor: Color(0xFFD97706),
  );

  static const AppColorScheme warmParchmentLightScheme = AppColorScheme(
    id: 'warm_parchment',
    name: 'Warm Parchment (Light)',
    description: 'Soft cream paper aesthetic inspired by Solarized Light and classic editorial print',
    brightness: Brightness.light,
    bg: Color(0xFFF4EFE0),
    surface: Color(0xFFFDF6E3),
    sidebar: Color(0xFFEEE8D5),
    gutter: Color(0xFFEEE8D5),
    border: Color(0xFFD8D0B8),
    textPrimary: Color(0xFF3B3228),
    textSecondary: Color(0xFF586E75),
    textMuted: Color(0xFF839496),
    accent: Color(0xFF268BD2),
    previewCanvas: Color(0xFFE6DFCA),
    previewPage: Color(0xFFFDF6E3),
    previewBorder: Color(0xFFD3CBB4),
    header1Color: Color(0xFF268BD2),
    header2Color: Color(0xFF2AA198),
    header3Color: Color(0xFF6C71C4),
    header4to6Color: Color(0xFF586E75),
    inlineCodeColor: Color(0xFFD33682),
    citationColor: Color(0xFF6C71C4),
    mathColor: Color(0xFF859900),
    warningOrImageColor: Color(0xFFB58900),
  );

  static const AppColorScheme catppuccinLatteScheme = AppColorScheme(
    id: 'catppuccin_latte',
    name: 'Catppuccin Latte (Light)',
    description: 'Warm daylight pastel palette with soft lavender and berry accents',
    brightness: Brightness.light,
    bg: Color(0xFFE6E9EF),
    surface: Color(0xFFEFF1F5),
    sidebar: Color(0xFFDCE0E8),
    gutter: Color(0xFFE6E9EF),
    border: Color(0xFFCCD0DA),
    textPrimary: Color(0xFF4C4F69),
    textSecondary: Color(0xFF5C5F77),
    textMuted: Color(0xFF8C8FA1),
    accent: Color(0xFF7287FD),
    previewCanvas: Color(0xFFDCE0E8),
    previewPage: Color(0xFFEFF1F5),
    previewBorder: Color(0xFFBCC0CC),
    header1Color: Color(0xFF1E66F5),
    header2Color: Color(0xFF7287FD),
    header3Color: Color(0xFF8839EF),
    header4to6Color: Color(0xFF5C5F77),
    inlineCodeColor: Color(0xFFD20F39),
    citationColor: Color(0xFF8839EF),
    mathColor: Color(0xFF40A02B),
    warningOrImageColor: Color(0xFFFE640B),
  );

  /// All available colour schemes ordered with Dark Mode palettes first, followed by Light Mode palettes.
  static const List<AppColorScheme> availableColorSchemes = [
    slateDarkScheme,
    tokyoNightScheme,
    draculaScheme,
    catppuccinMochaScheme,
    nordDarkScheme,
    gruvboxDarkScheme,
    monokaiNightScheme,
    solarizedDarkScheme,
    everforestDarkScheme,
    oledMidnightScheme,
    slateLightScheme,
    warmParchmentLightScheme,
    catppuccinLatteScheme,
  ];

  static final List<AppColorScheme> darkColorSchemes =
      availableColorSchemes.where((s) => s.isDark).toList(growable: false);

  static final List<AppColorScheme> lightColorSchemes =
      availableColorSchemes.where((s) => !s.isDark).toList(growable: false);

  static AppColorScheme _activeDarkScheme = slateDarkScheme;
  static AppColorScheme _activeLightScheme = slateLightScheme;

  static AppColorScheme get activeDarkScheme => _activeDarkScheme;
  static AppColorScheme get activeLightScheme => _activeLightScheme;

  static AppColorScheme activeSchemeForBrightness(bool isDark) =>
      isDark ? _activeDarkScheme : _activeLightScheme;

  static AppColorScheme schemeById(String? id) {
    if (id == null) return slateDarkScheme;
    for (final scheme in availableColorSchemes) {
      if (scheme.id == id) return scheme;
    }
    return slateDarkScheme;
  }

  /// Updates the active dark or light palette to [scheme].
  static void setActiveScheme(AppColorScheme scheme) {
    if (scheme.isDark) {
      _activeDarkScheme = scheme;
    } else {
      _activeLightScheme = scheme;
    }
  }

  // Dynamic Light palette getters backed by the active light scheme
  static Color get lightBg => _activeLightScheme.bg;
  static Color get lightSurface => _activeLightScheme.surface;
  static Color get lightSidebar => _activeLightScheme.sidebar;
  static Color get lightGutter => _activeLightScheme.gutter;
  static Color get lightBorder => _activeLightScheme.border;
  static Color get lightTextPrimary => _activeLightScheme.textPrimary;
  static Color get lightTextSecondary => _activeLightScheme.textSecondary;
  static Color get lightTextMuted => _activeLightScheme.textMuted;
  static Color get lightAccent => _activeLightScheme.accent;
  static Color get lightPreviewCanvas => _activeLightScheme.previewCanvas;
  static Color get lightPreviewPage => _activeLightScheme.previewPage;
  static Color get lightPreviewBorder => _activeLightScheme.previewBorder;

  // Dynamic Dark palette getters backed by the active dark scheme
  static Color get darkBg => _activeDarkScheme.bg;
  static Color get darkSurface => _activeDarkScheme.surface;
  static Color get darkSidebar => _activeDarkScheme.sidebar;
  static Color get darkGutter => _activeDarkScheme.gutter;
  static Color get darkBorder => _activeDarkScheme.border;
  static Color get darkTextPrimary => _activeDarkScheme.textPrimary;
  static Color get darkTextSecondary => _activeDarkScheme.textSecondary;
  static Color get darkTextMuted => _activeDarkScheme.textMuted;
  static Color get darkAccent => _activeDarkScheme.accent;
  static Color get darkPreviewCanvas => _activeDarkScheme.previewCanvas;
  static Color get darkPreviewPage => _activeDarkScheme.previewPage;
  static Color get darkPreviewBorder => _activeDarkScheme.previewBorder;

  // Monospace fonts for editor (strictly monospace)
  static const List<String> availableMonospaceFonts = [
    'Consolas',
    'Cascadia Code',
    'Courier New',
    'Fira Code',
    'JetBrains Mono',
    'Source Code Pro',
    'Inconsolata',
    'Roboto Mono',
    'Lucida Console',
    'Menlo',
    'Monaco',
  ];

  // Render fonts for Markdown preview (headers & body)
  static const List<String> availableRenderFonts = [
    'Segoe UI',
    'Inter',
    'Roboto',
    'Arial',
    'Helvetica',
    'Georgia',
    'Times New Roman',
    'Garamond',
    'Palatino',
    'Cambria',
    'Merriweather',
    'Open Sans',
    'Lato',
    'Consolas',
  ];

  static const String editorFontFamily = 'Consolas';
  static const List<String> editorFontFamilyFallback = [
    'Cascadia Code',
    'Courier New',
    'Fira Code',
    'Menlo',
    'Monaco',
    'monospace',
  ];

  static String? _cachedLightSchemeId;
  static String? _cachedLightTooltipDarkId;
  static ThemeData? _cachedLightTheme;

  static String? _cachedDarkSchemeId;
  static String? _cachedDarkTooltipLightId;
  static ThemeData? _cachedDarkTheme;

  static ThemeData lightTheme([AppColorScheme? scheme]) {
    final s = scheme ?? _activeLightScheme;
    if (_cachedLightTheme != null &&
        _cachedLightSchemeId == s.id &&
        _cachedLightTooltipDarkId == _activeDarkScheme.id) {
      return _cachedLightTheme!;
    }
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: s.bg,
      colorScheme: ColorScheme.light(
        primary: s.accent,
        surface: s.surface,
        onSurface: s.textPrimary,
        outline: s.border,
      ),
      fontFamily: 'Segoe UI',
      dividerColor: s.border,
      tabBarTheme: TabBarThemeData(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return s.accent.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.black.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
        splashFactory: NoSplash.splashFactory,
      ),
      cardTheme: CardThemeData(
        color: s.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: s.border),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _activeDarkScheme.bg,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
    _cachedLightSchemeId = s.id;
    _cachedLightTooltipDarkId = _activeDarkScheme.id;
    _cachedLightTheme = theme;
    return theme;
  }

  static ThemeData darkTheme([AppColorScheme? scheme]) {
    final s = scheme ?? _activeDarkScheme;
    if (_cachedDarkTheme != null &&
        _cachedDarkSchemeId == s.id &&
        _cachedDarkTooltipLightId == _activeLightScheme.id) {
      return _cachedDarkTheme!;
    }
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: s.bg,
      colorScheme: ColorScheme.dark(
        primary: s.accent,
        surface: s.surface,
        onSurface: s.textPrimary,
        outline: s.border,
      ),
      fontFamily: 'Segoe UI',
      dividerColor: s.border,
      tabBarTheme: TabBarThemeData(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return s.accent.withValues(alpha: 0.15);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.06);
          }
          return Colors.transparent;
        }),
        splashFactory: NoSplash.splashFactory,
      ),
      cardTheme: CardThemeData(
        color: s.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: s.border),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _activeLightScheme.bg,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: _activeLightScheme.textPrimary, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
    _cachedDarkSchemeId = s.id;
    _cachedDarkTooltipLightId = _activeLightScheme.id;
    _cachedDarkTheme = theme;
    return theme;
  }
}
