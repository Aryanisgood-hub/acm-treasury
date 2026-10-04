import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/budget_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';

class BudgetRequestsScreen extends ConsumerWidget {
  const BudgetRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(budgetRequestsProvider);
    final budget = ref.watch(totalBudgetProvider).value;
    final role = ref.watch(currentMemberProvider).value?.role;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget requests')),
      body: requests.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(budgetRequestsProvider),
        ),
        data: (list) {
          final pending = list.where((r) => r.isPending).toList();
          final history = list.where((r) => !r.isPending).toList();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('OFFICIAL BUDGET',
                              style: text.labelMedium?.copyWith(
                                  letterSpacing: 0.8,
                                  color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Text(Money.format(budget ?? 0),
                              style: text.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Changes only when the President approves a request.',
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (role != null && role.canRequestBudgetChange) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Request budget change'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const _NewRequestDialog(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    const SizedBox(
                      height: 260,
                      child: EmptyState(
                          icon: Icons.request_quote_outlined,
                          message: 'No budget requests yet.'),
                    ),
                  if (pending.isNotEmpty) ...[
                    _header(context, 'Pending (${pending.length})'),
                    for (final r in pending)
                      _RequestCard(
                          request: r, canReview: role?.canReviewBudget ?? false),
                  ],
                  if (history.isNotEmpty) ...[
                    _header(context, 'History'),
                    for (final r in history)
                      _RequestCard(request: r, canReview: false),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      );
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, required this.canReview});
  final BudgetRequest request;
  final bool canReview;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _review(bool approve) async {
    final r = widget.request;
    final ok = await confirmDialog(
      context,
      title: approve ? 'Approve budget change?' : 'Reject this request?',
      message: approve
          ? 'The official budget will change from ${Money.format(r.currentBudget)} '
              'to ${Money.format(r.requestedBudget)}.'
          : 'The official budget will stay as it is.',
      confirmLabel: approve ? 'APPROVE' : 'REJECT',
      destructive: !approve,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(budgetRepositoryProvider)
          .reviewRequest(r.id, approve: approve);
      _snack(approve ? 'Budget updated.' : 'Request rejected.');
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final up = r.change >= 0;
    final statusColor = r.status == 'approved'
        ? Colors.green
        : r.status == 'rejected'
            ? scheme.error
            : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${Money.format(r.currentBudget)}  →  '
                      '${Money.format(r.requestedBudget)}',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.status.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                          color: statusColor, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${up ? '+' : '-'}${Money.format(r.change.abs())}',
                style: text.titleSmall?.copyWith(
                    color: up ? Colors.green : scheme.error,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(r.reason),
              const SizedBox(height: 12),
              Text(
                'Requested by ${r.requestedByName} on ${fmtDateTime(r.createdAt)}',
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (r.reviewedAt != null)
                Text(
                  '${r.status == 'approved' ? 'Approved' : 'Rejected'} by '
                  '${r.reviewedByName ?? '-'} on ${fmtDateTime(r.reviewedAt!)}',
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              if (widget.canReview && r.isPending) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _review(false),
                      child: const Text('REJECT'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _review(true),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('APPROVE'),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewRequestDialog extends ConsumerStatefulWidget {
  const _NewRequestDialog();

  @override
  ConsumerState<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends ConsumerState<_NewRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(int current, int spent) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(budgetRepositoryProvider).createRequest(
            requestedBudget: Money.parseToPaise(_amount.text)!,
            reason: _reason.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request sent to the President for approval.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(totalBudgetProvider).value ?? 0;
    final spent = ref.watch(dashboardProvider).value?.spent ?? 0;
    return AlertDialog(
      title: const Text('Request budget change'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current budget: ${Money.format(current)}\n'
                    'Total spent so far: ${Money.format(spent)}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'New budget', prefixText: '₹ '),
                  validator: (v) {
                    final p = Money.parseToPaise(v ?? '');
                    if (p == null) return 'Enter a valid amount greater than 0';
                    if (p == current) return 'This is already the current budget';
                    if (p < spent) {
                      return 'Cannot be below total spent (${Money.format(spent)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Explain why the budget should change'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : () => _submit(current, spent),
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send request'),
        ),
      ],
    );
  }
}
