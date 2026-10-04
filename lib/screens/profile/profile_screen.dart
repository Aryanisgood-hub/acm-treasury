import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: member.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorView(
          message: 'Could not load your profile.',
          onRetry: () => ref.invalidate(currentMemberProvider),
        ),
        data: (m) {
          if (m == null) return const SizedBox.shrink();
          final scheme = Theme.of(context).colorScheme;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                              style: TextStyle(
                                  fontSize: 22,
                                  color: scheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(m.email),
                                const SizedBox(height: 8),
                                Chip(label: Text(m.role.label)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        _perm('Add bills', m.role.canAddBill),
                        _perm('Edit and void bills',
                            m.role.canEditBill && m.role.canVoidBill),
                        _perm('Request budget changes',
                            m.role.canRequestBudgetChange),
                        _perm('Approve budget changes', m.role.canReviewBudget),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Export & backup'),
                      subtitle: const Text(
                          'Excel backup, event and monthly reports'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/export'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    onPressed: () async {
                      final ok = await confirmDialog(context,
                          title: 'Sign out?',
                          message: 'You will need to sign in again.',
                          confirmLabel: 'Sign out');
                      if (ok) await ref.read(authServiceProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _perm(String label, bool allowed) => ListTile(
        dense: true,
        leading: Icon(
          allowed ? Icons.check_circle : Icons.cancel_outlined,
          color: allowed ? Colors.green : Colors.grey,
        ),
        title: Text(label),
      );
}
