import 'package:flutter/material.dart';

class KeyDialogs {
  static Future<String?> showAddKeyDialog(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    if (!context.mounted) {
      return null;
    }

    String draftKey = '';
    final FocusNode inputFocusNode = FocusNode();

    try {
      final String? rawKey = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (inputFocusNode.canRequestFocus) {
              inputFocusNode.requestFocus();
            }
          });

          return AlertDialog(
            title: const Text(
              'Add translation key',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            content: TextField(
              focusNode: inputFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'example: common.action.add',
                border: OutlineInputBorder(),
                hintStyle: TextStyle(fontSize: 14),
              ),
              onChanged: (String value) {
                draftKey = value;
              },
              onSubmitted: (String value) {
                Navigator.of(dialogContext).pop(value);
              },
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(draftKey),
                child: const Text('Add key'),
              ),
            ],
          );
        },
      );

      return rawKey;
    } finally {
      inputFocusNode.dispose();
    }
  }

  static Future<String?> showAddChildKeyDialog(
    BuildContext context,
    String parentPath,
  ) async {
    String draftSegment = '';

    final String? rawSegment = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Add key under $parentPath',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          content: TextField(
            autofocus: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'key',
              border: OutlineInputBorder(),
              hintStyle: TextStyle(fontSize: 14),
            ),
            onChanged: (String value) {
              draftSegment = value;
            },
            onSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftSegment),
              child: const Text('Add key'),
            ),
          ],
        );
      },
    );

    return rawSegment;
  }

  static Future<String?> showRenameKeyDialog(
    BuildContext context,
    String currentPath,
  ) async {
    String draftKey = currentPath;

    final String? rawKey = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Rename key',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          content: TextFormField(
            initialValue: currentPath,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'example: action.saving.apply',
              border: OutlineInputBorder(),
              hintStyle: TextStyle(fontSize: 14),
            ),
            onChanged: (String value) {
              draftKey = value;
            },
            onFieldSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftKey),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    return rawKey;
  }

  static Future<bool> showDeleteKeyConfirmation(
    BuildContext context, {
    required String fullPath,
    required int affectedCount,
  }) async {
    final bool isSubtreeDelete = affectedCount > 1;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isSubtreeDelete ? 'Delete subtree' : 'Delete key'),
          content: Text(
            isSubtreeDelete
                ? 'Delete $affectedCount keys under "$fullPath"?'
                : 'Delete key "$fullPath"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }
}
