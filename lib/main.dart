// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

import 'controllers/editor_controller.dart';
import 'ui/screens/main_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final editorController = EditorController();
  await editorController.initialise();

  runApp(
    DraftdownApp(
      controller: editorController,
      initialDarkMode: editorController.isDarkMode,
    ),
  );
}

class DraftdownApp extends StatefulWidget {
  final EditorController controller;
  final bool initialDarkMode;

  const DraftdownApp({
    super.key,
    required this.controller,
    required this.initialDarkMode,
  });

  @override
  State<DraftdownApp> createState() => _DraftdownAppState();
}

class _DraftdownAppState extends State<DraftdownApp>
    with WidgetsBindingObserver, WindowListener {
  Widget? _cachedMaterialApp;
  bool? _lastIsDarkMode;
  String? _lastDarkSchemeId;
  String? _lastLightSchemeId;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isDesktop) {
      try {
        windowManager.addListener(this);
      } catch (_) {}
    }
    widget.controller.syncDarkMode(widget.initialDarkMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isDesktop) {
      try {
        windowManager.removeListener(this);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  void onWindowFocus() {
    WidgetsBinding.instance.scheduleFrame();
  }

  void _toggleTheme() {
    widget.controller.toggleDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isDarkMode = widget.controller.isDarkMode;
        final darkId = widget.controller.darkSchemeId;
        final lightId = widget.controller.lightSchemeId;

        if (_cachedMaterialApp != null &&
            _lastIsDarkMode == isDarkMode &&
            _lastDarkSchemeId == darkId &&
            _lastLightSchemeId == lightId) {
          return _cachedMaterialApp!;
        }

        _lastIsDarkMode = isDarkMode;
        _lastDarkSchemeId = darkId;
        _lastLightSchemeId = lightId;
        _cachedMaterialApp = MaterialApp(
          title: 'Draftdown',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainScreen(
            controller: widget.controller,
            onToggleTheme: _toggleTheme,
            isDarkMode: isDarkMode,
          ),
        );
        return _cachedMaterialApp!;
      },
    );
  }
}
