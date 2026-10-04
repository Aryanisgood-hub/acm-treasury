import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/bill_model.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';

class BillDetailsScreen extends ConsumerStatefulWidget {
  const BillDetailsScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends ConsumerState<BillDetailsScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _viewReceipt(Bill bill) async {
    setState(() => _busy = true);
    try {
      final url =
          await ref.read(billRepositoryProvider).receiptUrl(bill.receiptPath!);
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) _snack('Could not open the receipt.');
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _void(Bill bill, String eventName) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _VoidDialog(bill: bill, eventName: eventName),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(billRepositoryProvider).voidBill(bill.id, reason);
      _snack('Bill voided.');
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(billsProvider);
    final role = ref.watch(currentMemberProvider).value?.role;
    final events = ref.watch(eventsProvider).value ?? const <EventModel>[];

    return bills.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(appBar: AppBar(), body: ErrorView(message: friendlyError(e))),
      data: (list) {
        Bill? bill;
        for (final b in list) {
          if (b.id == widget.billId) bill = b;
        }
        if (bill == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const ErrorView(message: 'This bill could not be found.'));
        }
        final b = bill;
        var eventName = 'Unknown event';
        for (final e in events) {
          if (e.id == b.eventId) eventName = e.name;
        }
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Bill details')),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (b.isVoided)
                    Card(
                      color: scheme.errorContainer,
                      child: ListTile(
                        leading: Icon(Icons.block, color: scheme.error),
                        title: Text('This bill was voided',
                            style: TextStyle(color: scheme.onErrorContainer)),
                        subtitle: Text(
                            'It no longer counts toward any totals.',
                            style: TextStyle(color: scheme.onErrorContainer)),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        _row('Event', eventName),
                        _row('Date', fmtDate(b.billDate)),
                        _row('Reason', b.reason),
                        _row('Amount', Money.format(b.amount), bold: true),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        _row('Added by', '${b.addedByName}\n${b.addedByEmail}'),
                        _row('Created at', fmtDateTime(b.createdAt)),
                        if (b.lastModifiedAt != null) ...[
                          _row('Last modified by', b.lastModifiedByName ?? '-'),
                          _row('Last modified at',
                              fmtDateTime(b.lastModifiedAt!)),
                        ],
                        if (b.isVoided) ...[
                          _row('Voided by', b.voidedByName ?? '-'),
                          if (b.voidedAt != null)
                            _row('Voided at', fmtDateTime(b.voidedAt!)),
                          _row('Void reason', b.voidReason ?? '-'),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(b.receiptPath == null
                          ? 'No receipt attached'
                          : 'Receipt attached'),
                      trailing: b.receiptPath == null
                          ? null
                          : FilledButton.tonal(
                              onPressed: _busy ? null : () => _viewReceipt(b),
                              child: const Text('View'),
                            ),
                    ),
                  ),
                  if (b.isActive && role != null) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      if (role.canEditBill)
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            onPressed: _busy
                                ? null
                                : () => context.push('/bill/${b.id}/edit'),
                          ),
                        ),
                      if (role.canEditBill && role.canVoidBill)
                        const SizedBox(width: 12),
                      if (role.canVoidBill)
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                                foregroundColor: scheme.onError),
                            icon: const Icon(Icons.block),
                            label: const Text('Void'),
                            onPressed: _busy ? null : () => _void(b, eventName),
                          ),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _VoidDialog extends StatefulWidget {
  const _VoidDialog({required this.bill, required this.eventName});
  final Bill bill;
  final String eventName;

  @override
  State<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<_VoidDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    return AlertDialog(
      title: const Text('Void this bill?'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to void this bill? '
                  'It stays on record but stops counting toward totals.'),
              const SizedBox(height: 12),
              Text('Event: ${widget.eventName}'),
              Text('Reason: ${b.reason}'),
              Text('Amount: ${Money.format(b.amount)}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Why void it?'),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Enter a reason (at least 3 characters)'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _reason.text.trim());
            }
          },
          child: const Text('VOID BILL'),
        ),
      ],
    );
  }
}
