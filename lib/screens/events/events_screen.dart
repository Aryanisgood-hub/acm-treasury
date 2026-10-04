import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../providers/bill_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/event_card.dart';
import '../../widgets/loading_widget.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(eventSummariesProvider);
    Future<void> newEvent() => showDialog<void>(
        context: context, builder: (_) => const _NewEventDialog());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
              tooltip: 'New event',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: newEvent),
        ],
      ),
      body: summaries.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () {
            ref.invalidate(eventsProvider);
            ref.invalidate(billsProvider);
          },
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.event_outlined,
              message: 'No events yet. Create one to start recording bills.',
              actionLabel: 'Create event',
              onAction: newEvent,
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => EventCard(
                  summary: list[i],
                  onTap: () => context.push('/event/${list[i].event.id}'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewEventDialog extends ConsumerStatefulWidget {
  const _NewEventDialog();

  @override
  ConsumerState<_NewEventDialog> createState() => _NewEventDialogState();
}

class _NewEventDialogState extends ConsumerState<_NewEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(eventRepositoryProvider)
          .createEvent(name: _name.text, description: _desc.text);
      if (mounted) Navigator.pop(context);
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
    return AlertDialog(
      title: const Text('New event'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Event name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter an event name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create')),
      ],
    );
  }
}
