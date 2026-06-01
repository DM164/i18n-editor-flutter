import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_typography.dart';

class LanguageEditorsPanel extends StatelessWidget {
  const LanguageEditorsPanel({
    required this.hasLanguages,
    required this.selectedKey,
    required this.languages,
    required this.controllersByLanguage,
    required this.isLeaf,
    super.key,
  });

  final bool hasLanguages;
  final String? selectedKey;
  final List<String> languages;
  final Map<String, TextEditingController> controllersByLanguage;
  final bool isLeaf;

  @override
  Widget build(BuildContext context) {
    final String? selectedKeyValue = selectedKey;
    final AppTypography typography =
        Theme.of(context).extension<AppTypography>() ??
        const AppTypography(fontSizeMedium: 14);
    final Color outlineColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.45);

    if (selectedKeyValue == null || !hasLanguages) {
      return Card(
        margin: const EdgeInsets.fromLTRB(0, 0, 10, 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              hasLanguages
                  ? 'Select a key from the sidebar'
                  : 'No language files found in translations folder',
            ),
          ),
        ),
      );
    }

    if (!isLeaf) {
      return Card(
        margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'This key is a parent and cannot have content. Select a leaf key to edit translations.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 10, 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Copy key',
                  icon: const Icon(Icons.content_copy),
                  iconSize: 20,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: selectedKeyValue),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Key copied to clipboard')),
                    );
                  },
                ),
                Text(
                  selectedKeyValue,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final String language = languages[index];
                  final TextEditingController? controller =
                      controllersByLanguage[language];
                  if (controller == null) {
                    return const SizedBox.shrink();
                  }
                  return TextField(
                    controller: controller,
                    style: TextStyle(fontSize: typography.fontSizeMedium),
                    minLines: 2,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: language,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineColor),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
