import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_controller.dart';
import '../../services/spell_check_service.dart';
import '../theme/app_theme.dart';

/// The core Markdown text editor widget with precision-synchronised
/// monospace line-number gutter and desktop keyboard shortcuts.
class EditorView extends StatefulWidget {
  final EditorController controller;
  final VoidCallback onOpenCitation;
  final VoidCallback onOpenExport;
  final VoidCallback onOpenFile;
  final VoidCallback onNewFile;

  const EditorView({
    super.key,
    required this.controller,
    required this.onOpenCitation,
    required this.onOpenExport,
    required this.onOpenFile,
    required this.onNewFile,
  });

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> with WidgetsBindingObserver {
  static const double _fontSize = 13.5;
  static const double _lineHeightMultiplier = 1.5;
  static const double _lineBoxHeight =
      20.0; // Exact strut-rounded line height in SkParagraph
  static const double _contentPaddingTop = 16.0;
  static const double _contentPaddingBottom = 40.0;
  static const double _contentPaddingHorizontal = 16.0;
  static const double _gutterWidth = 52.0;

  GlobalKey? __textFieldKey;
  GlobalKey get _textFieldKey => __textFieldKey ??= GlobalKey();

  GlobalKey? __gutterPaintKey;
  GlobalKey get _gutterPaintKey => __gutterPaintKey ??= GlobalKey();

  String? _lastOffsetText;
  List<int>? _cachedLineStartOffsets;
  RenderEditable? _cachedRenderEditable;
  Offset? _lastSecondaryClickGlobalPos;

  // Hover spellcheck menu state
  OverlayEntry? _spellHoverOverlay;
  Timer? _spellHoverOpenTimer;
  Timer? _spellHoverCloseTimer;
  SpellErrorRange? _pendingHoverError;
  SpellErrorRange? _activeHoverError;
  bool _isPointerInsideHoverMenu = false;
  String? _lastHoverTextSnapshot;

  // Cached gutter subtree to avoid rebuilding CustomPaint on cursor-only / selection-only notifications
  Widget? _cachedGutterSubtree;
  String? _lastGutterText;
  double? _lastGutterScrollOffset;
  double? _lastGutterEditorWidth;
  double? _lastGutterViewportHeight;
  Color? _lastGutterTextColor;
  String? _lastGutterFontFamily;
  late String _lastEditorFontFamily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastEditorFontFamily = widget.controller.editorFontFamily;
    _lastHoverTextSnapshot = widget.controller.textController.text;
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.textController.addListener(_handleTextChangedForHover);
    widget.controller.scrollController.addListener(_dismissSpellHoverMenu);
  }

  @override
  void didUpdateWidget(covariant EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      oldWidget.controller.textController.removeListener(
        _handleTextChangedForHover,
      );
      oldWidget.controller.scrollController.removeListener(
        _dismissSpellHoverMenu,
      );
      _lastEditorFontFamily = widget.controller.editorFontFamily;
      _lastHoverTextSnapshot = widget.controller.textController.text;
      widget.controller.addListener(_handleControllerChanged);
      widget.controller.textController.addListener(_handleTextChangedForHover);
      widget.controller.scrollController.addListener(_dismissSpellHoverMenu);
      _dismissSpellHoverMenu();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissSpellHoverMenu();
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.textController.removeListener(_handleTextChangedForHover);
    widget.controller.scrollController.removeListener(_dismissSpellHoverMenu);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _dismissSpellHoverMenu();
    }
  }

  void _handleTextChangedForHover() {
    final current = widget.controller.textController.text;
    if (current != _lastHoverTextSnapshot) {
      _lastHoverTextSnapshot = current;
      _dismissSpellHoverMenu();
    }
  }

  void _handleControllerChanged() {
    final currentFont = widget.controller.editorFontFamily;
    if (currentFont != _lastEditorFontFamily) {
      _lastEditorFontFamily = currentFont;
      _cachedGutterSubtree = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _cachedRenderEditable = null;
    _cachedGutterSubtree = null;
    _LineNumberPainter._painterCache.clear();
  }

  RenderEditable? _findRenderEditable() {
    final cached = _cachedRenderEditable;
    if (cached != null && cached.attached) {
      return cached;
    }
    final ctx = _textFieldKey.currentContext;
    if (ctx == null) return null;
    RenderEditable? result;
    void visitor(Element element) {
      if (result != null) return;
      final renderObject = element.renderObject;
      if (renderObject is RenderEditable) {
        result = renderObject;
        return;
      }
      element.visitChildren(visitor);
    }

    ctx.visitChildElements(visitor);
    _cachedRenderEditable = result;
    return result;
  }

  List<int> _getLineStartOffsets(String text) {
    if (_cachedLineStartOffsets != null && _lastOffsetText == text) {
      return _cachedLineStartOffsets!;
    }
    final offsets = <int>[0];
    int idx = text.indexOf('\n');
    while (idx != -1) {
      offsets.add(idx + 1);
      idx = text.indexOf('\n', idx + 1);
    }
    _lastOffsetText = text;
    _cachedLineStartOffsets = offsets;
    return offsets;
  }

  SpellErrorRange? _spellErrorAtGlobalPosition(
    RenderEditable renderEditable,
    Offset globalPos,
  ) {
    if (!renderEditable.hasSize || !renderEditable.attached) return null;
    final textPos = renderEditable.getPositionForPoint(globalPos);
    final candidate = widget.controller.textController.spellErrorAtOffset(
      textPos.offset,
    );
    if (candidate == null) return null;

    final localPos = renderEditable.globalToLocal(globalPos);
    final boxes = renderEditable.getBoxesForSelection(
      TextSelection(baseOffset: candidate.start, extentOffset: candidate.end),
    );
    final hit = boxes.any(
      (box) => box.toRect().inflate(4.0).contains(localPos),
    );
    return hit ? candidate : null;
  }

  SpellErrorRange? _resolveSpellErrorForContextMenu(
    EditableTextState editableTextState,
  ) {
    final clickPos = _lastSecondaryClickGlobalPos;
    if (clickPos != null) {
      final renderEditable = editableTextState.renderEditable;
      if (renderEditable.hasSize && renderEditable.attached) {
        return _spellErrorAtGlobalPosition(renderEditable, clickPos);
      }
    }

    final selection = editableTextState.textEditingValue.selection;
    if (!selection.isValid) return null;
    return widget.controller.textController.spellErrorAtOffset(
      selection.baseOffset,
    );
  }

  void _handleEditorHover(PointerHoverEvent event) {
    if (!widget.controller.isSpellCheckEnabled) {
      _dismissSpellHoverMenu();
      return;
    }

    final renderEditable = _findRenderEditable();
    if (renderEditable == null) return;

    final error = _spellErrorAtGlobalPosition(renderEditable, event.position);
    if (error == null) {
      _pendingHoverError = null;
      _spellHoverOpenTimer?.cancel();
      _spellHoverOpenTimer = null;
      if (_spellHoverOverlay != null && !_isPointerInsideHoverMenu) {
        _scheduleHoverClose();
      }
      return;
    }

    _spellHoverCloseTimer?.cancel();
    _spellHoverCloseTimer = null;

    if (error == _activeHoverError || error == _pendingHoverError) {
      return;
    }

    _pendingHoverError = error;
    _spellHoverOpenTimer?.cancel();
    _spellHoverOpenTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _pendingHoverError != error) return;
      _showSpellHoverMenu(error, renderEditable);
    });
  }

  void _handleEditorExit(PointerExitEvent event) {
    _pendingHoverError = null;
    _spellHoverOpenTimer?.cancel();
    _spellHoverOpenTimer = null;
    if (_spellHoverOverlay != null) {
      _scheduleHoverClose();
    }
  }

  void _scheduleHoverClose() {
    if (_spellHoverCloseTimer?.isActive ?? false) return;
    _spellHoverCloseTimer = Timer(const Duration(milliseconds: 180), () {
      if (!_isPointerInsideHoverMenu) {
        _dismissSpellHoverMenu();
      }
    });
  }

  void _dismissSpellHoverMenu() {
    _pendingHoverError = null;
    _activeHoverError = null;
    _isPointerInsideHoverMenu = false;
    _spellHoverOpenTimer?.cancel();
    _spellHoverOpenTimer = null;
    _spellHoverCloseTimer?.cancel();
    _spellHoverCloseTimer = null;
    _spellHoverOverlay?.remove();
    _spellHoverOverlay = null;
  }

  void _showSpellHoverMenu(
    SpellErrorRange error,
    RenderEditable renderEditable,
  ) {
    if (!mounted || !renderEditable.hasSize || !renderEditable.attached) {
      return;
    }

    final boxes = renderEditable.getBoxesForSelection(
      TextSelection(baseOffset: error.start, extentOffset: error.end),
    );
    if (boxes.isEmpty) return;

    final wordRectLocal = boxes.first.toRect();
    final topLeftGlobal = renderEditable.localToGlobal(wordRectLocal.topLeft);
    final bottomLeftGlobal = renderEditable.localToGlobal(
      wordRectLocal.bottomLeft,
    );

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _spellHoverOverlay?.remove();
    _spellHoverOverlay = null;
    _activeHoverError = error;

    final suggestions = widget.controller.getSpellingSuggestions(error.word);
    final mediaSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final mutedColor = isDark
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    const double menuWidth = 220.0;
    final int itemCount = (suggestions.isEmpty ? 1 : suggestions.length) + 2;
    final double estimatedHeight = (itemCount * 34.0) + 16.0;

    final double left = topLeftGlobal.dx.clamp(
      8.0,
      (mediaSize.width - menuWidth - 8.0).clamp(8.0, mediaSize.width),
    );
    final bool showAbove =
        bottomLeftGlobal.dy + estimatedHeight + 8.0 > mediaSize.height &&
        topLeftGlobal.dy - estimatedHeight - 6.0 >= 8.0;
    final double top = showAbove
        ? topLeftGlobal.dy - estimatedHeight - 4.0
        : bottomLeftGlobal.dy + 4.0;

    _spellHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        width: menuWidth,
        child: MouseRegion(
          onEnter: (_) {
            _isPointerInsideHoverMenu = true;
            _spellHoverCloseTimer?.cancel();
            _spellHoverCloseTimer = null;
          },
          onExit: (_) {
            _isPointerInsideHoverMenu = false;
            _scheduleHoverClose();
          },
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: surfaceColor,
            child: Container(
              key: const ValueKey('spellcheck-hover-menu'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        'No suggestions',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: mutedColor,
                        ),
                      ),
                    )
                  else
                    for (final suggestion in suggestions)
                      InkWell(
                        onTap: () {
                          _dismissSpellHoverMenu();
                          widget.controller.replaceSpellingError(
                            error,
                            suggestion,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text(
                            suggestion,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  Divider(height: 6, thickness: 1, color: borderColor),
                  InkWell(
                    onTap: () {
                      _dismissSpellHoverMenu();
                      widget.controller.addWordToDictionary(error.word);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_add_outlined,
                            size: 15,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add "${error.word}" to dictionary',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _dismissSpellHoverMenu();
                      widget.controller.ignoreSpellingWord(error.word);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 15,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ignore "${error.word}"',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_spellHoverOverlay!);
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final defaultItems = editableTextState.contextMenuButtonItems;

    if (!widget.controller.isSpellCheckEnabled) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: defaultItems,
      );
    }

    final spellError = _resolveSpellErrorForContextMenu(editableTextState);
    if (spellError == null) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: defaultItems,
      );
    }

    final suggestions = widget.controller.getSpellingSuggestions(
      spellError.word,
    );
    final items = <ContextMenuButtonItem>[
      for (final suggestion in suggestions)
        ContextMenuButtonItem(
          label: suggestion,
          onPressed: () {
            editableTextState.hideToolbar();
            widget.controller.replaceSpellingError(spellError, suggestion);
          },
        ),
      ContextMenuButtonItem(
        label: 'Add "${spellError.word}" to dictionary',
        onPressed: () {
          editableTextState.hideToolbar();
          widget.controller.addWordToDictionary(spellError.word);
        },
      ),
      ContextMenuButtonItem(
        label: 'Ignore "${spellError.word}"',
        onPressed: () {
          editableTextState.hideToolbar();
          widget.controller.ignoreSpellingWord(spellError.word);
        },
      ),
      ...defaultItems,
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final gutterColor = isDark ? AppTheme.darkGutter : AppTheme.lightGutter;
    final gutterTextColor = isDark
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    final editorTextStyle = TextStyle(
      fontFamily: widget.controller.editorFontFamily,
      fontFamilyFallback: AppTheme.editorFontFamilyFallback,
      fontSize: _fontSize,
      height: _lineHeightMultiplier,
      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
    );

    final editorStrutStyle = StrutStyle(
      fontFamily: widget.controller.editorFontFamily,
      fontFamilyFallback: AppTheme.editorFontFamilyFallback,
      fontSize: _fontSize,
      height: _lineHeightMultiplier,
      forceStrutHeight: true,
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          widget.controller.saveFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          widget.onOpenFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          widget.onNewFile();
        },
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () {
          widget.onOpenExport();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          shift: true,
        ): () {
          widget.onOpenCitation();
        },
        const SingleActivator(LogicalKeyboardKey.backslash, control: true): () {
          widget.controller.toggleSidebar();
        },
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
          widget.controller.setViewMode(EditorViewMode.edit);
        },
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
          widget.controller.setViewMode(EditorViewMode.split);
        },
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
          widget.controller.setViewMode(EditorViewMode.preview);
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: surfaceColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight;
              final editorWidth =
                  (constraints.maxWidth -
                          _gutterWidth -
                          (_contentPaddingHorizontal * 2))
                      .clamp(100.0, 99999.0);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Synchronised Line Number Gutter
                  Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final scrollController =
                            widget.controller.scrollController;
                        if (scrollController.hasClients) {
                          final targetOffset =
                              (scrollController.offset +
                                      pointerSignal.scrollDelta.dy)
                                  .clamp(
                                    0.0,
                                    scrollController.position.maxScrollExtent,
                                  );
                          scrollController.jumpTo(targetOffset);
                        }
                      }
                    },
                    child: Container(
                      width: _gutterWidth,
                      decoration: BoxDecoration(
                        color: gutterColor,
                        border: Border(right: BorderSide(color: borderColor)),
                      ),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          widget.controller.scrollController,
                          widget.controller.textController,
                        ]),
                        builder: (context, _) {
                          final scrollOffset =
                              widget.controller.scrollController.hasClients
                              ? widget.controller.scrollController.offset
                              : 0.0;
                          final currentText =
                              widget.controller.textController.text;
                          final fontFamily = widget.controller.editorFontFamily;

                          if (_cachedGutterSubtree != null &&
                              _lastGutterText == currentText &&
                              _lastGutterScrollOffset == scrollOffset &&
                              _lastGutterEditorWidth == editorWidth &&
                              _lastGutterViewportHeight == viewportHeight &&
                              _lastGutterTextColor == gutterTextColor &&
                              _lastGutterFontFamily == fontFamily) {
                            return _cachedGutterSubtree!;
                          }

                          final lineStartOffsets = _getLineStartOffsets(
                            currentText,
                          );

                          final subtree = RepaintBoundary(
                            child: ClipRect(
                              child: CustomPaint(
                                key: _gutterPaintKey,
                                size: Size(_gutterWidth, viewportHeight),
                                painter: _LineNumberPainter(
                                  lineStartOffsets: lineStartOffsets,
                                  text: currentText,
                                  editorWidth: editorWidth,
                                  scrollOffset: scrollOffset,
                                  viewportHeight: viewportHeight,
                                  lineBoxHeight: _lineBoxHeight,
                                  contentPaddingTop: _contentPaddingTop,
                                  gutterTextColor: gutterTextColor,
                                  fontFamily: fontFamily,
                                  fontFamilyFallback:
                                      AppTheme.editorFontFamilyFallback,
                                  editorStrutStyle: editorStrutStyle,
                                  findRenderEditable: _findRenderEditable,
                                  gutterPaintKey: _gutterPaintKey,
                                ),
                              ),
                            ),
                          );

                          _lastGutterText = currentText;
                          _lastGutterScrollOffset = scrollOffset;
                          _lastGutterEditorWidth = editorWidth;
                          _lastGutterViewportHeight = viewportHeight;
                          _lastGutterTextColor = gutterTextColor;
                          _lastGutterFontFamily = fontFamily;
                          _cachedGutterSubtree = subtree;
                          return subtree;
                        },
                      ),
                    ),
                  ),

                  // Markdown Text Editing Area
                  Expanded(
                    child: RepaintBoundary(
                      child: MouseRegion(
                        onHover: _handleEditorHover,
                        onExit: _handleEditorExit,
                        child: Listener(
                          onPointerDown: (event) {
                            _dismissSpellHoverMenu();
                            if ((event.buttons & kSecondaryMouseButton) != 0) {
                              _lastSecondaryClickGlobalPos = event.position;
                            } else {
                              _lastSecondaryClickGlobalPos = null;
                            }
                          },
                          child: TextField(
                            key: _textFieldKey,
                            controller: widget.controller.textController,
                            focusNode: widget.controller.focusNode,
                            scrollController:
                                widget.controller.scrollController,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            style: editorTextStyle,
                            strutStyle: editorStrutStyle,
                            contextMenuBuilder: _buildContextMenu,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.fromLTRB(
                                _contentPaddingHorizontal,
                                _contentPaddingTop,
                                _contentPaddingHorizontal,
                                _contentPaddingBottom,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering visible line numbers at the exact vertical position
/// of the first visual line of each logical line by querying TextField's [RenderEditable] directly.
/// Uses binary search in O(log N) to only process and paint lines currently visible on screen.
class _LineNumberPainter extends CustomPainter {
  final List<int> lineStartOffsets;
  final String text;
  final double editorWidth;
  final double scrollOffset;
  final double viewportHeight;
  final double lineBoxHeight;
  final double contentPaddingTop;
  final Color gutterTextColor;
  final String fontFamily;
  final List<String> fontFamilyFallback;
  final StrutStyle editorStrutStyle;
  final RenderEditable? Function() findRenderEditable;
  final GlobalKey gutterPaintKey;

  // Shared pool of pre-laid-out line number TextPainters to eliminate
  // per-frame native SkParagraph allocations and GC pressure during scrolling/typing.
  static final Map<int, TextPainter> _painterCache = <int, TextPainter>{};
  static const int _maxCachedPainters = 512;
  static String? _cachedFontFamily;
  static Color? _cachedColor;
  static double? _cachedMaxWidth;
  static TextStyle? _cachedTextStyle;

  _LineNumberPainter({
    required this.lineStartOffsets,
    required this.text,
    required this.editorWidth,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.lineBoxHeight,
    required this.contentPaddingTop,
    required this.gutterTextColor,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.editorStrutStyle,
    required this.findRenderEditable,
    required this.gutterPaintKey,
  });

  TextPainter _getOrLayoutPainter(int lineNumber, double maxWidth) {
    if (_cachedFontFamily != fontFamily ||
        _cachedColor != gutterTextColor ||
        _cachedMaxWidth != maxWidth) {
      for (final tp in _painterCache.values) {
        tp.dispose();
      }
      _painterCache.clear();
      _cachedFontFamily = fontFamily;
      _cachedColor = gutterTextColor;
      _cachedMaxWidth = maxWidth;
      _cachedTextStyle = TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: 12.0,
        color: gutterTextColor,
        height: 1.5,
      );
    }

    final existing = _painterCache[lineNumber];
    if (existing != null) {
      return existing;
    }

    if (_painterCache.length >= _maxCachedPainters) {
      final oldestKey = _painterCache.keys.first;
      _painterCache.remove(oldestKey)?.dispose();
    }

    final tp = TextPainter(
      text: TextSpan(text: '$lineNumber', style: _cachedTextStyle),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
      strutStyle: editorStrutStyle,
    )..layout(maxWidth: maxWidth);

    _painterCache[lineNumber] = tp;
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (lineStartOffsets.isEmpty) return;

    final renderEditable = findRenderEditable();
    final bool hasEditable = renderEditable != null && renderEditable.hasSize;
    final double singleLineHeight = hasEditable
        ? renderEditable.preferredLineHeight
        : lineBoxHeight;

    double editableTopOffset = contentPaddingTop;
    if (hasEditable && renderEditable.attached) {
      final gutterBox =
          gutterPaintKey.currentContext?.findRenderObject() as RenderBox?;
      if (gutterBox != null && gutterBox.hasSize && gutterBox.attached) {
        editableTopOffset = renderEditable
            .localToGlobal(Offset.zero, ancestor: gutterBox)
            .dy;
      }
    }

    final yCache = <int, double>{};

    // Returns the exact Y coordinate in gutter coordinates of the first visual line of logical line [lineIndex]
    double getLineTopY(int lineIndex) {
      final cachedY = yCache[lineIndex];
      if (cachedY != null) return cachedY;

      double y;
      if (hasEditable) {
        // Fast path: if the previous line's Y is already known and the previous line is empty (just '\n'),
        // it is guaranteed to occupy exactly 1 visual line, avoiding a native selection-endpoint query.
        if (lineIndex > 0) {
          final prevY = yCache[lineIndex - 1];
          if (prevY != null &&
              lineStartOffsets[lineIndex] - lineStartOffsets[lineIndex - 1] <=
                  1) {
            y = prevY + singleLineHeight;
            yCache[lineIndex] = y;
            return y;
          }
        }
        final charOffset = lineStartOffsets[lineIndex].clamp(0, text.length);
        final endpoints = renderEditable.getEndpointsForSelection(
          TextSelection.collapsed(offset: charOffset),
        );
        if (endpoints.isNotEmpty) {
          y = editableTopOffset + (endpoints.first.point.dy - singleLineHeight);
          yCache[lineIndex] = y;
          return y;
        }
      }
      y = contentPaddingTop + (lineIndex * singleLineHeight) - scrollOffset;
      yCache[lineIndex] = y;
      return y;
    }

    // Binary search in O(log N) to find the first logical line intersecting the viewport
    int low = 0;
    int high = lineStartOffsets.length - 1;
    int firstVisibleIndex = 0;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final y = getLineTopY(mid);
      if (y + singleLineHeight >= 0) {
        firstVisibleIndex = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    final int startIdx = firstVisibleIndex > 0 ? firstVisibleIndex - 1 : 0;
    final double maxLabelWidth = size.width - 12.0;

    for (int i = startIdx; i < lineStartOffsets.length; i++) {
      final y = getLineTopY(i);

      // Stop immediately once we pass below the visible viewport bounds
      if (y > viewportHeight) break;
      if (y + singleLineHeight < 0) continue;

      final textPainter = _getOrLayoutPainter(i + 1, maxLabelWidth);
      final double x = size.width - textPainter.width - 12.0;

      // Because textPainter uses the exact same editorStrutStyle (with forceStrutHeight: true),
      // painting at y aligns the line number's strut box and baseline with the first visual line.
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.text != text ||
        oldDelegate.editorWidth != editorWidth ||
        oldDelegate.gutterTextColor != gutterTextColor ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.viewportHeight != viewportHeight;
  }
}
