import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth.dart';
import 'auth_controller.dart';

Future<bool> showChangePasswordDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const ChangePasswordDialog(),
  );
  return result == true;
}

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});
  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể đổi mật khẩu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi mật khẩu'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _current,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập mật khẩu cũ'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _next,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                helperText: 'Ít nhất 8 ký tự, tối đa 72 byte UTF-8',
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty ||
                    value.length < 8 ||
                    utf8.encode(value).length > 72) {
                  return 'Mật khẩu mới phải có ít nhất 8 ký tự và tối đa 72 byte UTF-8';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
              ),
              validator: (value) =>
                  value != null && value.isNotEmpty && value != _next.text
                  ? 'Mật khẩu xác nhận không khớp'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
      ),
    ],
  );
}
