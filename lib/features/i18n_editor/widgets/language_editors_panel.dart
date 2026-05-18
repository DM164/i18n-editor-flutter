import 'package:flutter/material.dart';

import '../../../shared/theme/app_typography.dart';

class LanguageEditorsPanel extends StatelessWidget {
  const LanguageEditorsPanel({
    required this.hasLanguages,
    required this.selectedKey,
    required this.languages,
    required this.controllersByLanguage,
    super.key,
  });

  final bool hasLanguages;
  final String? selectedKey;
  final List<String> languages;
  final Map<String, TextEditingController> controllersByLanguage;

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selectedKey != null;
    final AppTypography typography =
        Theme.of(context).extension<AppTypography>() ??
        const AppTypography(fontSizeMedium: 14);

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            hasSelection && hasLanguages
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selectedKey!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: languages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final String language = languages[index];
                          final TextEditingController controller =
                              controllersByLanguage[language]!;
                          return TextField(
                            controller: controller,
                            style: TextStyle(
                              fontSize: typography.fontSizeMedium,
                            ),
                            minLines: 2,
                            maxLines: null,
                            decoration: InputDecoration(
                              labelText: language,
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white10),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
                : Center(
                  child: Text(
                    hasLanguages
                        ? 'Select a key from the sidebar'
                        : 'No language files found in translations folder',
                  ),
                ),
      ),
    );
  }
}
