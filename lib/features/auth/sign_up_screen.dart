import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/app_button.dart';
import 'auth_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _birthday;
  String? _photoData;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final data = await Media.pickAsDataUri(
      source: ImageSource.gallery,
      maxWidth: 400,
      quality: 60,
    );
    if (data != null && mounted) setState(() => _photoData = data);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select your birthday',
    );
    if (picked != null && mounted) setState(() => _birthday = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().signUp(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            password: _password.text,
            birthday: _birthday,
            photoUrl: _photoData,
          );
      // RootGate redirects to Home on auth state change.
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not create your account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = Media.providerFor(_photoData);
    return AuthScaffold(
      showBack: true,
      title: 'Create account',
      subtitle: 'Join the squad and start playing',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: colors.primaryContainer,
                      backgroundImage: provider,
                      child: provider == null
                          ? Icon(Icons.add_a_photo_outlined,
                              color: colors.onPrimaryContainer, size: 28)
                          : null,
                    ),
                  ),
                  if (provider != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: const Icon(Icons.edit,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Profile photo (optional)',
                style: TextStyle(
                    color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickBirthday,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Birthday',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                child: Text(
                  _birthday == null
                      ? 'Select your birthday'
                      : DateFormat.yMMMMd().format(_birthday!),
                  style: TextStyle(
                    color: _birthday == null
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Create account',
              icon: Icons.rocket_launch_rounded,
              loading: _loading,
              gradient: true,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account?',
                    style: TextStyle(color: colors.onSurfaceVariant)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
