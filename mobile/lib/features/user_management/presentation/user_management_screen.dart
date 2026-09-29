import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/exceptions.dart';
import '../../../core/widgets.dart';

class AppUser {
  const AppUser({required this.id, required this.fullName, required this.username, required this.email, required this.role, required this.companyName});

  final String id;
  final String fullName;
  final String username;
  final String email;
  final String role;
  final String? companyName;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'USER',
        companyName: json['companyName'] as String?,
      );
}

final appUsersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/api/admin/users');
    return (res.data['data'] as List? ?? []).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  } on DioException catch (e) {
    throw toApiException(e);
  }
});

final companiesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/api/admin/companies');
    return List<String>.from(res.data['data'] as List? ?? []);
  } on DioException catch (e) {
    throw toApiException(e);
  }
});

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  Future<void> _updateUser(WidgetRef ref, BuildContext context, AppUser user, {String? role, String? companyName}) async {
    try {
      await ref.read(dioProvider).patch('/api/admin/users/${user.id}', data: {
        if (role != null) 'role': role,
        if (companyName != null) 'companyName': companyName,
      });
      ref.invalidate(appUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated')));
      }
    } on DioException catch (e) {
      final ex = toApiException(e);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    }
  }

  Future<void> _deleteUser(WidgetRef ref, BuildContext context, AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('${user.fullName} will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(dioProvider).delete('/api/admin/users/${user.id}');
      ref.invalidate(appUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
      }
    } on DioException catch (e) {
      final ex = toApiException(e);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(appUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User management')),
      body: usersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Failed to load users',
          onRetry: () => ref.invalidate(appUsersProvider),
        ),
        data: (users) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(appUsersProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(u.fullName.isEmpty ? '?' : u.fullName[0].toUpperCase())),
                  title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('@${u.username} · ${u.role}${u.companyName != null ? ' · ${u.companyName}' : ''}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _deleteUser(ref, context, u);
                      if (value == 'promote') _updateUser(ref, context, u, role: 'SUPER_ADMIN');
                      if (value == 'demote') _updateUser(ref, context, u, role: 'USER');
                    },
                    itemBuilder: (_) => [
                      if (u.role == 'USER') const PopupMenuItem(value: 'promote', child: Text('Make Super Admin')),
                      if (u.role == 'SUPER_ADMIN') const PopupMenuItem(value: 'demote', child: Text('Set as USER')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => _editCompanyDialog(ref, context, u),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _editCompanyDialog(WidgetRef ref, BuildContext context, AppUser user) async {
    final companies = await ref.read(companiesProvider.future);
    if (!context.mounted) return;
    String? selected = user.companyName;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Company for ${user.username}'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            hint: const Text('No company'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— No company —')),
              ...companies.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => setState(() => selected = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true && context.mounted) {
      await _updateUser(ref, context, user, companyName: (selected == null || selected!.isEmpty) ? null : selected);
    }
  }
}
