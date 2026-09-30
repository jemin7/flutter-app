import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exceptions.dart';
import '../../../core/widgets.dart';
import '../data/external_users_repository.dart';

class UserDetailsScreen extends ConsumerWidget {
  const UserDetailsScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(externalUserByIdProvider(id));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Something went wrong',
          onRetry: () => ref.invalidate(externalUserByIdProvider(id)),
        ),
        data: (u) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero header: identity at a glance.
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        u.initials,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(u.name, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    if (u.username.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('@${u.username}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (u.company.name.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Chip(
                        avatar: Icon(Icons.business, size: 16, color: scheme.primary),
                        label: Text(u.company.name),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Contact',
              icon: Icons.contact_mail_outlined,
              children: [
                _ActionRow(icon: Icons.email_outlined, label: 'Email', value: u.email),
                _ActionRow(icon: Icons.phone_outlined, label: 'Phone', value: u.phone),
                _ActionRow(icon: Icons.language, label: 'Website', value: u.website),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Address',
              icon: Icons.location_on_outlined,
              children: [
                _Row(icon: Icons.home_outlined, label: 'Street', value: '${u.address.suite}, ${u.address.street}'),
                _Row(icon: Icons.location_city_outlined, label: 'City', value: u.address.city),
                _Row(icon: Icons.tag, label: 'Zipcode', value: u.address.zipcode),
                _Row(icon: Icons.public, label: 'Coordinates', value: '${u.address.geo.lat}, ${u.address.geo.lng}'),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Company',
              icon: Icons.business_outlined,
              children: [
                _Row(icon: Icons.business, label: 'Name', value: u.company.name),
                _Row(icon: Icons.format_quote, label: 'Catch phrase', value: u.company.catchPhrase),
                _Row(icon: Icons.work_outline, label: 'Focus', value: u.company.bs),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Row that copies the value to clipboard on tap, with a copy affordance.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () async {
          // ponytail: copying is the no-dependency action; upgrade path is url_launcher for tel:/mailto:.
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.outline),
            const SizedBox(width: 12),
            SizedBox(width: 90, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(width: 4),
            Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.primary))),
            Icon(Icons.copy_all_outlined, size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
