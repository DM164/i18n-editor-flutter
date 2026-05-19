import 'package:flutter/material.dart';

import 'features/i18n_editor/i18n_editor_page.dart';
import 'shared/theme/app_typography.dart';

void main() {
  runApp(const I18nEditorApp());
}

class I18nEditorApp extends StatelessWidget {
  const I18nEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'i18n Editor',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          AppTypography(fontSizeMedium: 14),
        ],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          AppTypography(fontSizeMedium: 14),
        ],
      ),
      home: const I18nEditorPage(),
    );
  }
}
