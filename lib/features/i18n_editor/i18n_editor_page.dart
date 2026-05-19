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

  final Map<String, Map<String, String>> _translationsByKey =
      <String, Map<String, String>>{};
  List<String> _languages = <String>[];
  List<String> _keys = <String>[];

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
      _showToast(
        title: 'Saved ${_languages.join(', ')}',
        subtitle: _translationsFolderPath ?? '',
        icon: Icons.save_rounded,
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

  void _showToast({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return _AnimatedToast(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onDismiss: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        );
      },
    );

    overlay.insert(entry);
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
      final String? selectedKey = _selectedKey;
      if (selectedKey != null &&
          (affectedKeys.contains(selectedKey) ||
              selectedKey.startsWith('$fullPath.'))) {
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
    final String? projectFolderPath = _projectFolderPath;
    final String headerSubtitle =
        projectFolderPath == null
            ? 'Open a project folder to start'
            : 'Loaded: ${TranslationFileService.lastPathSegment(projectFolderPath)}/$_translationsFolderName';

    final String searchQuery = _searchController.text.trim().toLowerCase();
    final Set<String> translationMatches = <String>{};
    if (searchQuery.isNotEmpty) {
      for (final String key in _keys) {
        final Map<String, String> values =
            _translationsByKey[key] ?? <String, String>{};
        for (final String value in values.values) {
          if (value.toLowerCase().contains(searchQuery)) {
            translationMatches.add(key);
            break;
          }
        }
      }
    }

    // Compute which keys are leaves for editability (not a prefix of any other key)
    final Set<String> nonLeafKeys = <String>{};
    for (final String key in _keys) {
      for (int i = 1; i < key.length; i++) {
        if (key[i] == '.') {
          nonLeafKeys.add(key.substring(0, i));
        }
      }
    }
    final bool selectedKeyIsLeaf =
        _selectedKey != null && !nonLeafKeys.contains(_selectedKey!);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.translate, color: Colors.deepPurpleAccent),
                const SizedBox(width: 8),
                const Text(
                  'i18n Editor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.deepPurpleAccent,
                  ),
                ),
              ],
            ),
            Text(headerSubtitle, style: const TextStyle(fontSize: 14)),
          ],
        ),
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
            onSelectKey: _selectKey,
            onAddChildKey: _showAddChildKeyDialog,
            onDeleteKey: _deleteKeyPath,
            searchQuery: searchQuery,
            translationMatches: translationMatches,
          ),
          Expanded(
            child: LanguageEditorsPanel(
              hasLanguages: hasLanguages,
              selectedKey: _selectedKey,
              languages: _languages,
              controllersByLanguage: _controllersByLanguage,
              isLeaf: selectedKeyIsLeaf,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedToast extends StatefulWidget {
  const _AnimatedToast({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = curved;
    _scale = Tween<double>(begin: 0.96, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(curved);

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1600), () async {
      if (!mounted) {
        return;
      }
      await _controller.reverse();
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color backgroundColor = theme.colorScheme.surfaceContainerHigh;
    final Color foregroundColor = theme.colorScheme.onSurface;
    final Color iconBackgroundColor = theme.colorScheme.primaryContainer;
    final Color iconColor = theme.colorScheme.onPrimaryContainer;

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _offset,
                child: ScaleTransition(
                  scale: _scale,
                  child: Material(
                    color: Colors.transparent,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: iconBackgroundColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.icon,
                                color: iconColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.subtitle.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle,
                                    style: TextStyle(
                                      color: foregroundColor.withValues(
                                        alpha: 0.72,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
