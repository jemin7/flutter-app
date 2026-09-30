import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/exceptions.dart';
import '../../../core/widgets.dart';
import '../../auth/data/auth_controller.dart';
import '../data/external_users_repository.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _query = '';

  Future<void> _refresh() async {
    ref.invalidate(externalUsersProvider);
    await ref.read(externalUsersProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(externalUsersProvider);
    final user = ref.watch(authControllerProvider).user ?? const {};
    final restrictedCompany = user['companyName'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, username or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          if (restrictedCompany != null && restrictedCompany.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('Company: $restrictedCompany'), avatar: const Icon(Icons.business, size: 18)),
              ),
            ),
          Expanded(
            child: usersAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is ApiException ? e.message : 'Something went wrong',
                onRetry: () => ref.invalidate(externalUsersProvider),
              ),
              data: (users) {
                final filtered = users
                    .where((u) =>
                        _query.isEmpty ||
                        u.name.toLowerCase().contains(_query) ||
                        u.username.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query))
                    .toList();
                if (filtered.isEmpty) {
                  return EmptyView(
                    message: _query.isEmpty
                        ? 'No users assigned to your company. Contact your administrator.'
                        : 'No users match "$_query"',
                    icon: Icons.people_outline,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              u.initials,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text.rich(
                            TextSpan(
                              text: u.email,
                              style: Theme.of(context).textTheme.bodySmall,
                              children: [
                                const TextSpan(text: '\n'),
                                TextSpan(
                                  text: u.company.name,
                                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/users/${u.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
