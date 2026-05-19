import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'dialogs/key_dialogs.dart';
import 'services/translation_file_service.dart';
import 'widgets/key_tree_sidebar.dart';
import 'widgets/language_editors_panel.dart';

class I18nEditorPage extends StatefulWidget {
  const I18nEditorPage({super.key});

  @override
  State<I18nEditorPage> createState() => _I18nEditorPageState();
}

class _I18nEditorPageState extends State<I18nEditorPage> {
  static const String _translationsFolderName = 'translations';

  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _controllersByLanguage =
      <String, TextEditingController>{};

  final Map<String, Map<String, String>> _translationsByKey = {};
  List<String> _languages = [];
  List<String> _keys = [];

  String? _selectedKey;
  String? _projectFolderPath;
  String? _translationsFolderPath;
  bool _isBusy = false;

  @override
  void dispose() {
    _searchController.dispose();
    for (final TextEditingController controller
        in _controllersByLanguage.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String _) {
    setState(() {});
  }

  List<String> get _filteredKeys {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _keys;
    }

    return _keys.where((String key) => _keyMatchesSearch(key, query)).toList();
  }

  bool _keyMatchesSearch(String key, String query) {
    if (key.toLowerCase().contains(query)) {
      return true;
    }

    final Map<String, String> values = Map<String, String>.from(
      _translationsByKey[key] ?? <String, String>{},
    );

    if (_selectedKey == key) {
      for (final String language in _languages) {
        values[language] = _controllersByLanguage[language]?.text ?? '';
      }
    }

    for (final String value in values.values) {
      if (value.toLowerCase().contains(query)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _pickAndLoadFolder() async {
    String? pickedDirectory;
    try {
      pickedDirectory = await getDirectoryPath();
    } catch (_) {
      pickedDirectory = null;
    }

    if (!mounted) {
      return;
    }

    if (pickedDirectory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No folder selected.')));
      return;
    }

    await _loadFromFolder(pickedDirectory);
  }

  Future<void> _loadFromFolder(String selectedFolderPath) async {
    setState(() {
      _isBusy = true;
    });

    try {
      final Directory selectedDir = Directory(selectedFolderPath);
      final String selectedFolderName = TranslationFileService.lastPathSegment(
        selectedFolderPath,
      );
      final String projectFolderPath =
          selectedFolderName == _translationsFolderName
              ? selectedDir.parent.path
              : selectedFolderPath;

      final String translationsFolderPath =
          '$projectFolderPath${Platform.pathSeparator}$_translationsFolderName';
      final Directory translationsDir = Directory(translationsFolderPath);
      if (!await translationsDir.exists()) {
        await translationsDir.create(recursive: true);
      }

      final List<String> nextLanguages =
          await TranslationFileService.discoverLanguages(
            translationsFolderPath,
          );

      final Map<String, Map<String, String>> languageMaps =
          <String, Map<String, String>>{};
      for (final String language in nextLanguages) {
        languageMaps[language] = await TranslationFileService.readLanguageFlat(
          translationsFolderPath,
          language,
        );
      }

      final Set<String> allKeys = <String>{};
      for (final Map<String, String> languageMap in languageMaps.values) {
        allKeys.addAll(languageMap.keys);
      }

      final Map<String, Map<String, String>> nextTranslations =
          <String, Map<String, String>>{};
      for (final String key in allKeys) {
        final Map<String, String> row = <String, String>{};
        for (final String language in nextLanguages) {
          row[language] = languageMaps[language]?[key] ?? '';
        }
        nextTranslations[key] = row;
      }

      final List<String> nextKeys = allKeys.toList()..sort();
      final String? nextSelectedKey = nextKeys.isEmpty ? null : nextKeys.first;

      setState(() {
        _projectFolderPath = projectFolderPath;
        _translationsFolderPath = translationsFolderPath;
        _searchController.clear();
        _languages = nextLanguages;
        _syncLanguageControllers();
        _translationsByKey
          ..clear()
          ..addAll(nextTranslations);
        _keys = nextKeys;
        _selectedKey = nextSelectedKey;
        _bindEditors();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load folder: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _syncLanguageControllers() {
    final Set<String> oldLanguages = _controllersByLanguage.keys.toSet();
    final Set<String> newLanguages = _languages.toSet();

    for (final String removedLanguage in oldLanguages.difference(
      newLanguages,
    )) {
      _controllersByLanguage.remove(removedLanguage)?.dispose();
    }

    for (final String language in _languages) {
      _controllersByLanguage.putIfAbsent(language, TextEditingController.new);
    }
  }

  Future<void> _saveLanguageFiles() async {
    if (_translationsFolderPath == null || _languages.isEmpty) {
      return;
    }

    _applyEditorValues();
    setState(() {
      _isBusy = true;
    });

    try {
      final JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      for (final String language in _languages) {
        final Map<String, dynamic> nested =
            TranslationFileService.buildNestedForLanguage(
              language: language,
              keys: _keys,
              translationsByKey: _translationsByKey,
            );
        final String path =
            '$_translationsFolderPath${Platform.pathSeparator}$language.json';
        await File(path).writeAsString('${encoder.convert(nested)}\n');
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${_languages.join(', ')} in $_translationsFolderPath',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save files: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _bindEditors() {
    final String? key = _selectedKey;
    if (key == null) {
      for (final TextEditingController controller
          in _controllersByLanguage.values) {
        controller.text = '';
      }
      return;
    }

    final Map<String, String> values =
        _translationsByKey[key] ?? <String, String>{};
    for (final String language in _languages) {
      _controllersByLanguage[language]?.text = values[language] ?? '';
    }
  }

  void _applyEditorValues() {
    final String? key = _selectedKey;
    if (key == null) {
      return;
    }

    final Map<String, String> values = _translationsByKey.putIfAbsent(
      key,
      () => <String, String>{},
    );
    for (final String language in _languages) {
      values[language] = _controllersByLanguage[language]?.text ?? '';
    }
  }

  void _selectKey(String key) {
    if (_selectedKey == key) {
      return;
    }

    _applyEditorValues();
    setState(() {
      _selectedKey = key;
      _bindEditors();
    });
  }

  Future<void> _addKey(String key) async {
    final String trimmedKey = key.trim();
    if (!_isValidTranslationKey(trimmedKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid key. Use letters/numbers/_/- and dots between segments.',
          ),
        ),
      );
      return;
    }

    if (_translationsByKey.containsKey(trimmedKey)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Key already exists.')));
      return;
    }

    _applyEditorValues();
    setState(() {
      final Map<String, String> row = <String, String>{};
      for (final String language in _languages) {
        row[language] = '';
      }
      _translationsByKey[trimmedKey] = row;
      _keys = _translationsByKey.keys.toList()..sort();
      _selectedKey = trimmedKey;
      _bindEditors();
    });
  }

  Future<void> _showAddKeyDialog() async {
    final String? rawKey = await KeyDialogs.showAddKeyDialog(context);

    if (!mounted || rawKey == null) {
      return;
    }

    await _addKey(rawKey);
  }

  Future<void> _showAddChildKeyDialog(String parentPath) async {
    final String? rawSegment = await KeyDialogs.showAddChildKeyDialog(
      context,
      parentPath,
    );

    if (!mounted || rawSegment == null) {
      return;
    }

    final String segment = rawSegment.trim();
    final RegExp validSegment = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!validSegment.hasMatch(segment)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid segment. Use letters/numbers/_/-.'),
        ),
      );
      return;
    }

    await _addKey('$parentPath.$segment');
  }

  Future<void> _deleteKeyPath(String fullPath) async {
    final List<String> affectedKeys =
        _keys
            .where(
              (String key) => key == fullPath || key.startsWith('$fullPath.'),
            )
            .toList()
          ..sort();

    if (affectedKeys.isEmpty) {
      return;
    }

    final bool confirmed = await KeyDialogs.showDeleteKeyConfirmation(
      context,
      fullPath: fullPath,
      affectedCount: affectedKeys.length,
    );

    if (!mounted || !confirmed) {
      return;
    }

    _applyEditorValues();
    setState(() {
      for (final String key in affectedKeys) {
        _translationsByKey.remove(key);
      }
      _keys = _translationsByKey.keys.toList()..sort();
      if (_selectedKey != null &&
          (affectedKeys.contains(_selectedKey) ||
              _selectedKey!.startsWith('$fullPath.'))) {
        _selectedKey = _keys.isEmpty ? null : _keys.first;
      }
      _bindEditors();
    });
  }

  bool _isValidTranslationKey(String key) {
    if (key.isEmpty || key.startsWith('.') || key.endsWith('.')) {
      return false;
    }

    final RegExp validPattern = RegExp(r'^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$');
    return validPattern.hasMatch(key);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLanguages = _languages.isNotEmpty;
    final List<String> filteredKeys = _filteredKeys;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple I18n Editor'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _isBusy ? null : _pickAndLoadFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open project folder'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed:
                _isBusy ||
                        _translationsFolderPath == null ||
                        _keys.isEmpty ||
                        _languages.isEmpty
                    ? null
                    : _saveLanguageFiles,
            icon: const Icon(Icons.save),
            label: const Text('Save translations'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed:
                _isBusy || _translationsFolderPath == null
                    ? null
                    : _showAddKeyDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add key'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: <Widget>[
          KeyTreeSidebar(
            keys: filteredKeys,
            selectedKey: _selectedKey,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            headerSubtitle:
                _projectFolderPath == null
                    ? 'Open a project folder to start'
                    : 'Loaded: ${TranslationFileService.lastPathSegment(_projectFolderPath!)}/$_translationsFolderName (${_languages.length} languages)',
            onSelectKey: _selectKey,
            onAddChildKey: _showAddChildKeyDialog,
            onDeleteKey: _deleteKeyPath,
          ),
          Expanded(
            child: LanguageEditorsPanel(
              hasLanguages: hasLanguages,
              selectedKey: _selectedKey,
              languages: _languages,
              controllersByLanguage: _controllersByLanguage,
            ),
          ),
        ],
      ),
    );
  }
}
