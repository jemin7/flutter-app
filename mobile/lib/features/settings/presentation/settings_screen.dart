import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/validators.dart';
import '../../../core/widgets.dart';
import '../../auth/data/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _fullName;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showPasswords = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: ref.read(authControllerProvider).user?['fullName'] as String? ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      final res = await ref.read(dioProvider).patch('/api/settings/profile', data: {'fullName': _fullName.text.trim()});
      // Server is source of truth: refresh the auth state from the response.
      final user = res.data['data']['user'] as Map<String, dynamic>;
      ref.read(authControllerProvider.notifier).updateCachedUser(user);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on DioException catch (e) {
      final ex = toApiException(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final currentError = Validators.password(_currentPassword.text) == null ? null : 'Enter your current password';
    final newError = Validators.password(_newPassword.text);
    if (currentError != null || newError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newError ?? currentError!)));
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await ref.read(dioProvider).post('/api/settings/change-password', data: {
        'currentPassword': _currentPassword.text,
        'newPassword': _newPassword.text,
      });
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
    } on DioException catch (e) {
      final ex = toApiException(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(ex.fieldErrors['currentPassword'] ?? ex.message)));
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  AppTextField(controller: _fullName, label: 'Full name'),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Save profile', onPressed: _saveProfile, loading: _savingProfile),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Change password', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _currentPassword,
                    label: 'Current password',
                    obscure: !_showPasswords,
                    suffix: IconButton(
                      icon: Icon(_showPasswords ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPasswords = !_showPasswords),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(controller: _newPassword, label: 'New password', obscure: !_showPasswords),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Change password', onPressed: _changePassword, loading: _savingPassword),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App version'),
              subtitle: Text(kAppVersion),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
