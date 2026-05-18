import 'dart:convert';
import 'dart:io';

class TranslationFileService {
  static Future<List<String>> discoverLanguages(String folderPath) async {
    final Directory dir = Directory(folderPath);
    final List<String> languages = <String>[];

    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) {
        continue;
      }

      final String fileName = lastPathSegment(entity.path).toLowerCase();
      if (!fileName.endsWith('.json') || fileName.length <= 5) {
        continue;
      }

      languages.add(fileName.substring(0, fileName.length - 5));
    }

    languages.sort();
    return languages;
  }

  static Future<Map<String, String>> readLanguageFlat(
    String folderPath,
    String language,
  ) async {
    final String path = '$folderPath${Platform.pathSeparator}$language.json';
    final File file = File(path);
    if (!await file.exists()) {
      return <String, String>{};
    }

    final String raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, String>{};
    }

    return flattenJson(decoded);
  }

  static Map<String, String> flattenJson(
    Map<String, dynamic> input, {
    String prefix = '',
  }) {
    final Map<String, String> out = <String, String>{};

    input.forEach((String key, dynamic value) {
      final String fullKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        out.addAll(flattenJson(value, prefix: fullKey));
        return;
      }

      if (value is Map) {
        out.addAll(
          flattenJson(
            value.map((k, v) => MapEntry(k.toString(), v)),
            prefix: fullKey,
          ),
        );
        return;
      }

      out[fullKey] = value?.toString() ?? '';
    });

    return out;
  }

  static Map<String, dynamic> buildNestedForLanguage({
    required String language,
    required List<String> keys,
    required Map<String, Map<String, String>> translationsByKey,
  }) {
    final Map<String, dynamic> root = <String, dynamic>{};

    for (final String key in keys) {
      final String value = translationsByKey[key]?[language] ?? '';
      final List<String> parts = key.split('.');

      Map<String, dynamic> cursor = root;
      for (int i = 0; i < parts.length; i++) {
        final String part = parts[i];
        final bool isLeaf = i == parts.length - 1;

        if (isLeaf) {
          cursor[part] = value;
          continue;
        }

        final dynamic next = cursor[part];
        if (next is Map<String, dynamic>) {
          cursor = next;
        } else {
          final Map<String, dynamic> created = <String, dynamic>{};
          cursor[part] = created;
          cursor = created;
        }
      }
    }

    return root;
  }

  static String lastPathSegment(String path) {
    final List<String> parts =
        path.split(RegExp(r'[\\/]')).where((String p) => p.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }
}
