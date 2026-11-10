import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../controllers/editor_controller.dart';
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

class _EditorViewState extends State<EditorView> {
  static const double _fontSize = 13.5;
  static const double _lineHeightMultiplier = 1.5;
  static const double _lineBoxHeight = 20.0; // Exact strut-rounded line height in SkParagraph
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

  RenderEditable? _findRenderEditable() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final gutterColor =
        isDark ? AppTheme.darkGutter : AppTheme.lightGutter;
    final gutterTextColor =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final editorTextStyle = TextStyle(
      fontFamily: widget.controller.editorFontFamily,
      fontFamilyFallback: AppTheme.editorFontFamilyFallback,
      fontSize: _fontSize,
      height: _lineHeightMultiplier,
      color: isDark
          ? AppTheme.darkTextPrimary
          : AppTheme.lightTextPrimary,
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
        const SingleActivator(LogicalKeyboardKey.keyC,
            control: true, shift: true): () {
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
              final editorWidth = (constraints.maxWidth -
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
                          final targetOffset = (scrollController.offset +
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
                          final scrollOffset = widget
                                  .controller.scrollController.hasClients
                              ? widget.controller.scrollController.offset
                              : 0.0;
                          final currentText =
                              widget.controller.textController.text;
                          final lineStartOffsets =
                              _getLineStartOffsets(currentText);

                          return RepaintBoundary(
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
                                  fontFamily: widget.controller.editorFontFamily,
                                  fontFamilyFallback:
                                      AppTheme.editorFontFamilyFallback,
                                  editorStrutStyle: editorStrutStyle,
                                  findRenderEditable: _findRenderEditable,
                                  gutterPaintKey: _gutterPaintKey,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Markdown Text Editing Area
                  Expanded(
                    child: RepaintBoundary(
                      child: TextField(
                        key: _textFieldKey,
                        controller: widget.controller.textController,
                        focusNode: widget.controller.focusNode,
                        scrollController: widget.controller.scrollController,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        style: editorTextStyle,
                        strutStyle: editorStrutStyle,
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

  @override
  void paint(Canvas canvas, Size size) {
    if (lineStartOffsets.isEmpty) return;

    final textStyle = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12.0,
      color: gutterTextColor,
      height: 1.5,
    );

    final renderEditable = findRenderEditable();
    final bool hasEditable = renderEditable != null && renderEditable.hasSize;
    final double singleLineHeight =
        hasEditable ? renderEditable.preferredLineHeight : lineBoxHeight;

    double editableTopOffset = contentPaddingTop;
    if (hasEditable && renderEditable.attached) {
      final gutterBox =
          gutterPaintKey.currentContext?.findRenderObject() as RenderBox?;
      if (gutterBox != null && gutterBox.hasSize && gutterBox.attached) {
        editableTopOffset =
            renderEditable.localToGlobal(Offset.zero, ancestor: gutterBox).dy;
      }
    }

    // Returns the exact Y coordinate in gutter coordinates of the first visual line of logical line [lineIndex]
    double getLineTopY(int lineIndex) {
      if (hasEditable) {
        final charOffset = lineStartOffsets[lineIndex].clamp(0, text.length);
        final endpoints = renderEditable.getEndpointsForSelection(
          TextSelection.collapsed(offset: charOffset),
        );
        if (endpoints.isNotEmpty) {
          return editableTopOffset +
              (endpoints.first.point.dy - singleLineHeight);
        }
      }
      return contentPaddingTop + (lineIndex * singleLineHeight) - scrollOffset;
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

    for (int i = startIdx; i < lineStartOffsets.length; i++) {
      final y = getLineTopY(i);

      // Stop immediately once we pass below the visible viewport bounds
      if (y > viewportHeight) break;
      if (y + singleLineHeight < 0) continue;

      final textSpan = TextSpan(
        text: '${i + 1}',
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        strutStyle: editorStrutStyle,
      )..layout(maxWidth: size.width - 12);

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
