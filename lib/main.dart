import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/editor_controller.dart';
import 'ui/screens/main_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final editorController = EditorController();
  await editorController.initialise();

  // Load saved theme mode
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('mdwriter_dark_mode') ?? false;

  runApp(MDWriterApp(
    controller: editorController,
    initialDarkMode: isDark,
  ));
}

class MDWriterApp extends StatefulWidget {
  final EditorController controller;
  final bool initialDarkMode;

  const MDWriterApp({
    super.key,
    required this.controller,
    required this.initialDarkMode,
  });

  @override
  State<MDWriterApp> createState() => _MDWriterAppState();
}

class _MDWriterAppState extends State<MDWriterApp> {
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
        return MaterialApp(
          title: 'MDWriter',
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
      },
    );
  }
}
