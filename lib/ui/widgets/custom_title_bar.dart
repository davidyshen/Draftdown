// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/legacy.dart';

import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Custom frameless desktop title bar with hover-triggered sidebar hamburger,
/// app icon & theme-recoloured SVG wordmark, draggable caption area, and
/// custom minimise, maximise/restore, and close buttons.
class CustomTitleBar extends StatefulWidget {
  final EditorController controller;
  final ValueChanged<bool> onHamburgerHoverChanged;
  final bool isDarkMode;

  const CustomTitleBar({
    super.key,
    required this.controller,
    required this.onHamburgerHoverChanged,
    required this.isDarkMode,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  static const double _barHeight = 34.0;
  bool _isMaximized = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      try {
        windowManager.addListener(this);
        _syncMaximizedState();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      try {
        windowManager.removeListener(this);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _syncMaximizedState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted && maximized != _isMaximized) {
        setState(() => _isMaximized = maximized);
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  Future<void> _minimize() async {
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Future<void> _close() async {
    try {
      await windowManager.close();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final iconColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;

    return Container(
      height: _barHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          MouseRegion(
            onEnter: (_) => widget.onHamburgerHoverChanged(true),
            onExit: (_) => widget.onHamburgerHoverChanged(false),
            child: Tooltip(
              message: 'Toggle Sidebar (Ctrl+\\)',
              child: InkWell(
                key: const ValueKey('titlebar-hamburger-btn'),
                borderRadius: BorderRadius.circular(4),
                onTap: widget.controller.toggleSidebar,
                child: SizedBox(
                  width: 30,
                  height: 26,
                  child: Icon(Icons.menu, size: 17, color: iconColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SvgPicture.asset(
            'assets/icon.svg',
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 7),
          Semantics(
            label: 'Draftdown',
            child: SvgPicture.asset(
              'assets/wordmark.svg',
              width: 78,
              height: 15,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          Expanded(
            child: DragToMoveArea(child: const SizedBox(height: _barHeight)),
          ),
          _WindowControlButton(
            key: const ValueKey('window-minimize-btn'),
            icon: Icons.remove,
            tooltip: 'Minimise',
            iconColor: iconColor,
            isDarkMode: isDark,
            onTap: _minimize,
          ),
          _WindowControlButton(
            key: const ValueKey('window-maximize-btn'),
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _isMaximized ? 13 : 14,
            tooltip: _isMaximized ? 'Restore' : 'Maximise',
            iconColor: iconColor,
            isDarkMode: isDark,
            onTap: _toggleMaximize,
          ),
          _WindowControlButton(
            key: const ValueKey('window-close-btn'),
            icon: Icons.close,
            tooltip: 'Close',
            iconColor: iconColor,
            isDarkMode: isDark,
            isClose: true,
            onTap: _close,
          ),
        ],
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final Color iconColor;
  final bool isDarkMode;
  final bool isClose;
  final VoidCallback onTap;

  const _WindowControlButton({
    super.key,
    required this.icon,
    this.iconSize = 15,
    required this.tooltip,
    required this.iconColor,
    required this.isDarkMode,
    this.isClose = false,
    required this.onTap,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.isClose
        ? const Color(0xFFE81123)
        : (widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06));
    final effectiveIconColor = (_hovered && widget.isClose)
        ? Colors.white
        : widget.iconColor;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 44,
            height: 34,
            color: _hovered ? hoverBg : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: effectiveIconColor,
            ),
          ),
        ),
      ),
    );
  }
}
