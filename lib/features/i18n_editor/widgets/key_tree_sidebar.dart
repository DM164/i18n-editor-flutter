import 'package:flutter/material.dart';

import '../models/key_tree_node.dart';

enum KeyContextAction { addChild, rename, delete }

class KeyTreeSidebar extends StatefulWidget {
  const KeyTreeSidebar({
    required this.keys,
    required this.selectedKey,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelectKey,
    required this.onAddChildKey,
    required this.onRenameKey,
    required this.onDeleteKey,
    required this.translationsByKey,
    required this.languages,
    this.searchQuery = '',
    this.translationMatches = const <String>{},
    super.key,
  });

  final List<String> keys;
  final String? selectedKey;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectKey;
  final ValueChanged<String> onAddChildKey;
  final ValueChanged<String> onRenameKey;
  final ValueChanged<String> onDeleteKey;
  final Map<String, Map<String, String>> translationsByKey;
  final List<String> languages;
  final String searchQuery;
  final Set<String> translationMatches;

  @override
  State<KeyTreeSidebar> createState() => _KeyTreeSidebarState();
}

class _KeyTreeSidebarState extends State<KeyTreeSidebar> {
  late Set<String> _expandedNodes;
  static const double _treeIndentStep = 6;
  static const double _treeGuideLeftOffset = 16;
  static const double _treeGuideGutterWidth = 4;

  @override
  void initState() {
    super.initState();
    _expandedNodes = _calculateInitialExpansion();
  }

  @override
  void didUpdateWidget(KeyTreeSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.keys != oldWidget.keys) {
      _expandedNodes = _calculateInitialExpansion();
    }
  }

  Set<String> _calculateInitialExpansion() {
    if (widget.searchQuery.isEmpty) return <String>{};
    // Expand all parent paths of matching keys
    final Set<String> expanded = <String>{};
    for (final String key in widget.keys) {
      if (key.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
          widget.translationMatches.contains(key)) {
        final parts = key.split('.');
        String path = '';
        for (int i = 0; i < parts.length - 1; i++) {
          path = path.isEmpty ? parts[i] : '$path.${parts[i]}';
          expanded.add(path);
        }
      }
    }
    return expanded;
  }

  static const EdgeInsets _tilePadding = EdgeInsets.symmetric(horizontal: 14);
  static const VisualDensity _compactDensity = VisualDensity(
    horizontal: 0,
    vertical: -4,
  );

  @override
  Widget build(BuildContext context) {
    final KeyTreeNode treeRoot = _buildKeyTree(widget.keys);
    final ThemeData theme = Theme.of(context);
    final Color dividerColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.35,
    );
    final Color subtleBorderColor =
        theme.brightness == Brightness.dark
            ? Colors.white10
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.25);

    return SizedBox(
      width: 320,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: widget.searchController,
                onChanged: widget.onSearchChanged,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search keys and translations',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: subtleBorderColor,
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: subtleBorderColor,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  hintStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  widget.keys.isEmpty
                      ? const Center(child: Text('No matching keys'))
                      : ListView(
                        children: _buildTreeWidgets(
                          context,
                          treeRoot,
                          dividerColor: dividerColor,
                          depth: 0,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  KeyTreeNode _buildKeyTree(List<String> flatKeys) {
    final KeyTreeNode root = KeyTreeNode(segment: '', fullPath: '');

    for (final String key in flatKeys) {
      final List<String> parts = key.split('.');
      KeyTreeNode cursor = root;
      String path = '';

      for (int i = 0; i < parts.length; i++) {
        final String segment = parts[i];
        path = path.isEmpty ? segment : '$path.$segment';
        cursor = cursor.children.putIfAbsent(
          segment,
          () => KeyTreeNode(segment: segment, fullPath: path),
        );
      }

      cursor.isLeaf = true;
    }

    return root;
  }

  List<Widget> _buildTreeWidgets(
    BuildContext context,
    KeyTreeNode node, {
    required Color dividerColor,
    required int depth,
  }) {
    final List<KeyTreeNode> children =
        node.children.values.toList()
          ..sort((a, b) => a.segment.compareTo(b.segment));

    // Helper to check if this node or any descendant has a missing translation
    bool hasMissingRecursive(KeyTreeNode node) {
      if (node.children.isEmpty) {
        final translations = widget.translationsByKey[node.fullPath] ?? {};
        return widget.languages.any(
          (lang) => (translations[lang] ?? '').trim().isEmpty,
        );
      }
      for (final child in node.children.values) {
        if (hasMissingRecursive(child)) return true;
      }
      return false;
    }

    return children.map((child) {
      final bool hasChildren = child.children.isNotEmpty;
      final bool isTranslationMatch = widget.translationMatches.contains(
        child.fullPath,
      );
      final bool hasMissing = hasMissingRecursive(child);

      if (!hasChildren) {
        return _wrapWithTreeGuides(
          depth: depth,
          guideColor: _guideColorForDepth(context, depth),
          child: _withKeyContextMenu(
            context: context,
            node: child,
            child: ListTile(
              contentPadding: _tilePadding,
              dense: true,
              visualDensity: _compactDensity,
              minVerticalPadding: 4,
              selected: child.fullPath == widget.selectedKey,
              onTap: () => widget.onSelectKey(child.fullPath),
              title: Row(
                children: [
                  Text(child.segment, overflow: TextOverflow.ellipsis),
                  if (isTranslationMatch)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.search,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  if (hasMissing)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }

      final bool expanded = _expandedNodes.contains(child.fullPath);

      return _wrapWithTreeGuides(
        depth: depth,
        guideColor: _guideColorForDepth(context, depth),
        child: _withKeyContextMenu(
          context: context,
          node: child,
          child: ExpansionTile(
            key: PageStorageKey<String>(
              'key-tree-${child.fullPath}-${widget.searchQuery}',
            ),
            dense: true,
            visualDensity: _compactDensity,
            shape: Border(top: BorderSide(color: dividerColor)),
            collapsedShape: const Border(),
            tilePadding: _tilePadding,
            childrenPadding: EdgeInsets.zero,
            title: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: _compactDensity,
              minVerticalPadding: 0,
              minTileHeight: 20,
              title: Row(
                children: [
                  Text(
                    child.segment,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (hasMissing)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            initiallyExpanded: expanded,
            children: <Widget>[
              ..._buildTreeWidgets(
                context,
                child,
                dividerColor: dividerColor,
                depth: depth + 1,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Color _guideColorForDepth(BuildContext context, int depth) {
    if (depth <= 0) {
      return Theme.of(context).colorScheme.outlineVariant;
    }

    // Deterministic pseudo-random hue by depth to keep colors stable.
    final int seed = ((depth * 1103515245) + 12345) & 0x7fffffff;
    final double hue = (seed % 360).toDouble();
    final double saturation = 0.50 + (((seed >> 8) % 28) / 100);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double value = isDark ? 0.95 : 0.72;

    return HSVColor.fromAHSV(
      0.72,
      hue,
      saturation.clamp(0.0, 1.0),
      value,
    ).toColor();
  }

  Widget _wrapWithTreeGuides({
    required int depth,
    required Color guideColor,
    required Widget child,
  }) {
    if (depth == 0) {
      return child;
    }

    final double guideWidth = _treeGuideLeftOffset + _treeGuideGutterWidth;

    return CustomPaint(
      painter: _TreeGuidePainter(
        depth: depth,
        step: _treeIndentStep,
        leftOffset: _treeGuideLeftOffset,
        color: guideColor,
      ),
      child: Padding(padding: EdgeInsets.only(left: guideWidth), child: child),
    );
  }

  Widget _withKeyContextMenu({
    required BuildContext context,
    required Widget child,
    required KeyTreeNode node,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown:
          (TapDownDetails details) =>
              _showKeyContextMenu(context, details, node),
      onLongPress: () => widget.onAddChildKey(node.fullPath),
      child: child,
    );
  }

  Future<void> _showKeyContextMenu(
    BuildContext context,
    TapDownDetails details,
    KeyTreeNode node,
  ) async {
    if (node.fullPath.isEmpty) {
      return;
    }

    final KeyContextAction? action = await showMenu<KeyContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const <PopupMenuEntry<KeyContextAction>>[
        PopupMenuItem<KeyContextAction>(
          value: KeyContextAction.addChild,
          child: Text('Add child key'),
        ),
        PopupMenuItem<KeyContextAction>(
          value: KeyContextAction.rename,
          child: Text('Rename'),
        ),
        PopupMenuItem<KeyContextAction>(
          value: KeyContextAction.delete,
          child: Text('Delete'),
        ),
      ],
    );

    if (action == null) {
      return;
    }

    switch (action) {
      case KeyContextAction.addChild:
        widget.onAddChildKey(node.fullPath);
        break;
      case KeyContextAction.rename:
        widget.onRenameKey(node.fullPath);
        break;
      case KeyContextAction.delete:
        widget.onDeleteKey(node.fullPath);
        break;
    }
  }
}

class _TreeGuidePainter extends CustomPainter {
  _TreeGuidePainter({
    required this.depth,
    required this.step,
    required this.leftOffset,
    required this.color,
  });

  final int depth;
  final double step;
  final double leftOffset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1;

    if (depth <= 0) {
      return;
    }

    final double x = leftOffset + (step / 2);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _TreeGuidePainter oldDelegate) {
    return oldDelegate.depth != depth ||
        oldDelegate.step != step ||
        oldDelegate.leftOffset != leftOffset ||
        oldDelegate.color != color;
  }
}
