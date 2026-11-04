import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Information describing the layout position of a single logical line
class _LineInfo {
  final int lineNumber;
  final double top;
  final double height;

  const _LineInfo({
    required this.lineNumber,
    required this.top,
    required this.height,
  });
}

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
  static const double _lineBoxHeight = _fontSize * _lineHeightMultiplier; // 20.25
  static const double _contentPaddingTop = 16.0;
  static const double _contentPaddingBottom = 40.0;
  static const double _contentPaddingHorizontal = 16.0;
  static const double _gutterWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final gutterColor =
        isDark ? const Color(0xFF162032) : const Color(0xFFF1F5F9);
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

              // Calculate positions of all lines taking soft-wrapping into account
              final lines = _computeLinePositions(
                text: widget.controller.textController.text,
                editorWidth: editorWidth,
                style: editorTextStyle,
                strutStyle: editorStrutStyle,
              );

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
                        animation: widget.controller.scrollController,
                        builder: (context, _) {
                          final scrollOffset = widget
                                  .controller.scrollController.hasClients
                              ? widget.controller.scrollController.offset
                              : 0.0;

                          return ClipRect(
                            child: CustomPaint(
                              size: Size(_gutterWidth, viewportHeight),
                              painter: _LineNumberPainter(
                                lines: lines,
                                scrollOffset: scrollOffset,
                                viewportHeight: viewportHeight,
                                lineBoxHeight: _lineBoxHeight,
                                gutterTextColor: gutterTextColor,
                                fontFamily: widget.controller.editorFontFamily,
                                fontFamilyFallback:
                                    AppTheme.editorFontFamilyFallback,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Markdown Text Editing Area
                  Expanded(
                    child: TextField(
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Compute vertical start positions of every logical paragraph
  List<_LineInfo> _computeLinePositions({
    required String text,
    required double editorWidth,
    required TextStyle style,
    required StrutStyle strutStyle,
  }) {
    final paragraphs = text.split('\n');
    final List<_LineInfo> result = [];

    double currentY = _contentPaddingTop;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      int visualLines = 1;

      if (p.isNotEmpty && editorWidth > 50) {
        final painter = TextPainter(
          text: TextSpan(text: p, style: style),
          textDirection: TextDirection.ltr,
          strutStyle: strutStyle,
        )..layout(maxWidth: editorWidth);

        visualLines =
            (painter.height / _lineBoxHeight).round().clamp(1, 9999);
      }

      final double pHeight = visualLines * _lineBoxHeight;
      result.add(_LineInfo(
        lineNumber: i + 1,
        top: currentY,
        height: pHeight,
      ));

      currentY += pHeight;
    }

    return result;
  }
}

/// Custom painter rendering visible line numbers at their exact vertical positions
class _LineNumberPainter extends CustomPainter {
  final List<_LineInfo> lines;
  final double scrollOffset;
  final double viewportHeight;
  final double lineBoxHeight;
  final Color gutterTextColor;
  final String fontFamily;
  final List<String> fontFamilyFallback;

  _LineNumberPainter({
    required this.lines,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.lineBoxHeight,
    required this.gutterTextColor,
    required this.fontFamily,
    required this.fontFamilyFallback,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12.0,
      color: gutterTextColor,
      height: 1.5,
    );

    for (final line in lines) {
      // Calculate screen Y position for the first visual line of this paragraph
      final y = line.top - scrollOffset;

      // Skip lines outside visible screen bounds
      if (y + line.height < 0) continue;
      if (y > viewportHeight) break;

      final textSpan = TextSpan(
        text: '${line.lineNumber}',
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 12);

      // Vertically center with first visual line & align right with 12px margin
      final double verticalAdjustment =
          (lineBoxHeight - textPainter.height) / 2.0;
      final double x = size.width - textPainter.width - 12.0;

      textPainter.paint(canvas, Offset(x, y + verticalAdjustment));
    }
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.lines != lines ||
        oldDelegate.gutterTextColor != gutterTextColor ||
        oldDelegate.viewportHeight != viewportHeight;
  }
}
