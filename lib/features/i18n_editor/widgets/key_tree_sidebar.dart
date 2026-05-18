import 'package:flutter/material.dart';

import '../models/key_tree_node.dart';

enum KeyContextAction { addChild, delete }

class KeyTreeSidebar extends StatelessWidget {
  const KeyTreeSidebar({
    required this.keys,
    required this.selectedKey,
    required this.headerSubtitle,
    required this.onSelectKey,
    required this.onAddChildKey,
    required this.onDeleteKey,
    super.key,
  });

  final List<String> keys;
  final String? selectedKey;
  final String headerSubtitle;
  final ValueChanged<String> onSelectKey;
  final ValueChanged<String> onAddChildKey;
  final ValueChanged<String> onDeleteKey;

  static const double _subtitleFontSize = 11;
  static const EdgeInsets _tilePadding = EdgeInsets.symmetric(horizontal: 8);
  static const VisualDensity _compactDensity = VisualDensity(
    horizontal: 0,
    vertical: -4,
  );

  @override
  Widget build(BuildContext context) {
    final KeyTreeNode treeRoot = _buildKeyTree(keys);

    return SizedBox(
      width: 320,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              title: const Text('Translation Keys'),
              subtitle: Text(headerSubtitle),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  keys.isEmpty
                      ? const Center(child: Text('No keys loaded'))
                      : ListView(
                        children: _buildTreeWidgets(
                          context,
                          treeRoot,
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
    required int depth,
  }) {
    final List<KeyTreeNode> children =
        node.children.values.toList()
          ..sort((a, b) => a.segment.compareTo(b.segment));

    return children.map((child) {
      final bool hasChildren = child.children.isNotEmpty;
      final EdgeInsets rowIndent = EdgeInsets.only(left: depth * 10.0);

      if (!hasChildren) {
        return Padding(
          padding: rowIndent,
          child: _withKeyContextMenu(
            context: context,
            node: child,
            child: ListTile(
              contentPadding: _tilePadding,
              dense: true,
              visualDensity: _compactDensity,
              minVerticalPadding: 4,
              minTileHeight: 36,
              selected: child.fullPath == selectedKey,
              onTap: () => onSelectKey(child.fullPath),
              title: Text(child.segment, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                child.fullPath,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: _subtitleFontSize),
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: rowIndent,
        child: ExpansionTile(
          key: PageStorageKey<String>('key-tree-${child.fullPath}'),
          shape: const Border(top: BorderSide(color: Colors.white10)),
          collapsedShape: const Border(),
          tilePadding: _tilePadding,
          childrenPadding: EdgeInsets.zero,
          title: _withKeyContextMenu(
            context: context,
            node: child,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: _compactDensity,
              minVerticalPadding: 0,
              minTileHeight: 36,
              title: Text(
                child.segment,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                child.fullPath,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: _subtitleFontSize),
              ),
            ),
          ),
          initiallyExpanded: true,
          children: <Widget>[
            if (child.isLeaf)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _withKeyContextMenu(
                  context: context,
                  node: child,
                  child: ListTile(
                    contentPadding: _tilePadding,
                    dense: true,
                    visualDensity: _compactDensity,
                    minVerticalPadding: 4,
                    minTileHeight: 32,
                    selected: child.fullPath == selectedKey,
                    onTap: () => onSelectKey(child.fullPath),
                    title: const Text('(value)'),
                  ),
                ),
              ),
            ..._buildTreeWidgets(context, child, depth: depth + 1),
          ],
        ),
      );
    }).toList();
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
      onLongPress: () => onAddChildKey(node.fullPath),
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
        onAddChildKey(node.fullPath);
        break;
      case KeyContextAction.delete:
        onDeleteKey(node.fullPath);
        break;
    }
  }
}
