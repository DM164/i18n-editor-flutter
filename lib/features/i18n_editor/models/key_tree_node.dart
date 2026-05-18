class KeyTreeNode {
  KeyTreeNode({required this.segment, required this.fullPath});

  final String segment;
  final String fullPath;
  final Map<String, KeyTreeNode> children = <String, KeyTreeNode>{};
  bool isLeaf = false;
}
