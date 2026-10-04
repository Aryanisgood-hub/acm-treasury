import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../providers/export_provider.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  static const _xlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  late final List<DateTime> _months;
  late DateTime _month;
  String? _eventId;
  String? _busy; // which action is running

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = List.generate(24, (i) => DateTime(now.year, now.month - i));
    _month = _months.first;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _stamp() => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');

  Future<void> _run(String key, Future<void> Function() job) async {
    setState(() => _busy = key);
    try {
      await job();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _share(Uint8List bytes, String fileName) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: _xlsx)],
      fileNameOverrides: [fileName],
    ));
  }

  Future<void> _backup() => _run('backup', () async {
        final bytes = await ref.read(exportServiceProvider).fullBackup();
        await _share(bytes, 'ACM-Treasury-backup-${_stamp()}.xlsx');
      });

  Future<void> _eventReport(EventModel ev) => _run('event', () async {
        final bytes =
            await ref.read(exportServiceProvider).eventReport(ev.id, ev.name);
        await _share(bytes, 'ACM-event-${_safe(ev.name)}.xlsx');
      });

  Future<void> _monthlyReport() => _run('month', () async {
        final bytes = await ref.read(exportServiceProvider).monthlyReport(_month);
        await _share(
            bytes, 'ACM-report-${DateFormat('yyyy-MM').format(_month)}.xlsx');
      });

  Widget _spinnerOr(String key, String label) => _busy == key
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5))
      : Text(label);

  Widget _card(String title, String description, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider).value ?? const <EventModel>[];
    final anyBusy = _busy != null;
    EventModel? selected;
    for (final e in events) {
      if (e.id == _eventId) selected = e;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Export & backup')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                'Full backup',
                'Everything in one Excel file: summary, all bills (including '
                    'voided), events, budget requests, change history and members. '
                    'Receipt photos stay in Supabase Storage; the file lists '
                    'each receipt\'s file name.',
                [
                  FilledButton.icon(
                    icon: const Icon(Icons.backup_outlined),
                    onPressed: anyBusy ? null : _backup,
                    label: _spinnerOr('backup', 'Create backup'),
                  ),
                  const SizedBox(height: 8),
                  Text('Tip: make a backup once a month and save it to Google Drive.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              _card(
                'Event report',
                'All bills for one event with its total.',
                [
                  DropdownButtonFormField<String>(
                    initialValue: _eventId,
                    decoration: const InputDecoration(labelText: 'Event'),
                    items: [
                      for (final e in events)
                        DropdownMenuItem(value: e.id, child: Text(e.name)),
                    ],
                    onChanged: (v) => setState(() => _eventId = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.event_note_outlined),
                    onPressed: anyBusy || selected == null
                        ? null
                        : () => _eventReport(selected!),
                    label: _spinnerOr('event', 'Create event report'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _card(
                'Monthly report',
                'Spending in one month across all events.',
                [
                  DropdownButtonFormField<DateTime>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: [
                      for (final m in _months)
                        DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat('MMMM yyyy').format(m))),
                    ],
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: anyBusy ? null : _monthlyReport,
                    label: _spinnerOr('month', 'Create monthly report'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Reports count only active bills; voided bills are listed but '
                'never added to totals. On your phone, choose Drive, Files, '
                'WhatsApp or email when the share sheet opens.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
