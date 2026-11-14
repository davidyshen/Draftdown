import 'package:flutter/material.dart';
import 'controllers/editor_controller.dart';
import 'ui/screens/main_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final editorController = EditorController();
  await editorController.initialise();

  runApp(DraftdownApp(
    controller: editorController,
    initialDarkMode: editorController.isDarkMode,
  ));
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

class _DraftdownAppState extends State<DraftdownApp> {
  Widget? _cachedMaterialApp;
  bool? _lastIsDarkMode;
  String? _lastDarkSchemeId;
  String? _lastLightSchemeId;

  @override
  void initState() {
    super.initState();
    widget.controller.syncDarkMode(widget.initialDarkMode);
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
