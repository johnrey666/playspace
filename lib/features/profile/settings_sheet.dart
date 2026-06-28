import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme_controller.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/auth_service.dart';
import 'edit_profile_screen.dart';

/// Bottom sheet opened from the profile 3-dots menu. Holds account + theme
/// settings (edit profile, change password, dark mode, accent color, logout).
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change password'),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => const ChangePasswordDialog(),
                );
              },
            ),
            const Divider(height: 8),
            SwitchListTile(
              secondary: Icon(
                theme.isDark(context)
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
              ),
              title: const Text('Dark mode'),
              value: theme.isDark(context),
              onChanged: (v) => theme.toggleDark(v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Accent color',
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ThemeController.presetColors.map((c) {
                  final selected = c.toARGB32() == theme.seed.toARGB32();
                  return GestureDetector(
                    onTap: () => theme.setSeed(c),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? colors.onSurface : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.of(context).pop();
                context.read<AuthProvider>().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated.')));
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not change password.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) =>
                  v != _next.text ? 'Passwords do not match' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}
