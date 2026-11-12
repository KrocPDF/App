import 'package:flutter/material.dart';

/// Displays a modal dialog prompting for passwords to unlock 1 or 2
/// password-protected PDF files.
///
/// When 1 file is encrypted, shows a single password field mentioning the file
/// name. When 2 files are encrypted, shows both password fields stacked
/// vertically in one dialog window, each labeled with its file name.
Future<Map<String, String>?> showPdfPasswordDialog({
  required BuildContext context,
  required List<String> encryptedFilePaths,
  Map<String, String> initialPasswords = const {},
  Map<String, String> fileErrors = const {},
}) {
  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PdfPasswordDialog(
      encryptedFilePaths: encryptedFilePaths,
      initialPasswords: initialPasswords,
      fileErrors: fileErrors,
    ),
  );
}

class _PdfPasswordDialog extends StatefulWidget {
  final List<String> encryptedFilePaths;
  final Map<String, String> initialPasswords;
  final Map<String, String> fileErrors;

  const _PdfPasswordDialog({
    required this.encryptedFilePaths,
    required this.initialPasswords,
    required this.fileErrors,
  });

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _obscured;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final path in widget.encryptedFilePaths)
        path: TextEditingController(text: widget.initialPasswords[path] ?? ''),
    };
    _obscured = {for (final path in widget.encryptedFilePaths) path: true};
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _fileNameFor(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : path;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = <String, String>{
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isMultiple = widget.encryptedFilePaths.length > 1;
    final singleFileName = widget.encryptedFilePaths.isNotEmpty
        ? _fileNameFor(widget.encryptedFilePaths.first)
        : '';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMultiple ? 'Passwords Required' : 'Password Required',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMultiple
                      ? 'Both PDFs are password-protected. Enter the password for each file:'
                      : 'Enter the password to unlock "$singleFileName":',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < widget.encryptedFilePaths.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildPasswordField(
                    path: widget.encryptedFilePaths[i],
                    index: i,
                    total: widget.encryptedFilePaths.length,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Unlock & Merge')),
      ],
    );
  }

  Widget _buildPasswordField({
    required String path,
    required int index,
    required int total,
  }) {
    final fileName = _fileNameFor(path);
    final externalError = widget.fileErrors[path];
    final isObscured = _obscured[path] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total > 1 ? 'PDF ${index + 1}: $fileName' : fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _controllers[path],
          obscureText: isObscured,
          textInputAction: index < total - 1
              ? TextInputAction.next
              : TextInputAction.done,
          onFieldSubmitted: (_) {
            if (index == total - 1) {
              _submit();
            }
          },
          decoration: InputDecoration(
            hintText: 'Password for $fileName',
            errorText: externalError,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                isObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
              onPressed: () => setState(() => _obscured[path] = !isObscured),
            ),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Enter password for $fileName';
            }
            return null;
          },
        ),
      ],
    );
  }
}
