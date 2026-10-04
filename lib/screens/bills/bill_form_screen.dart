

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/bill_model.dart';
import '../../models/event_model.dart';
import '../../models/member_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/event_provider.dart';
import '../../repositories/bill_repository.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';

/// Add (billId == null) or edit an existing bill.
class BillFormScreen extends ConsumerWidget {
  const BillFormScreen({super.key, this.billId});
  final String? billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider).value;
    if (member == null) return const Scaffold(body: LoadingWidget());

    if (billId == null) {
      if (!member.role.canAddBill) {
        return Scaffold(
            appBar: AppBar(),
            body: const ErrorView(message: 'Only treasurers can add bills.'));
      }
      return _BillForm(member: member);
    }

    return ref.watch(billsProvider).when(
          loading: () => const Scaffold(body: LoadingWidget()),
          error: (e, _) => Scaffold(
              appBar: AppBar(), body: ErrorView(message: friendlyError(e))),
          data: (list) {
            Bill? bill;
            for (final b in list) {
              if (b.id == billId) bill = b;
            }
            if (bill == null || bill.isVoided || !member.role.canEditBill) {
              return Scaffold(
                  appBar: AppBar(),
                  body: const ErrorView(
                      message: 'This bill cannot be edited.'));
            }
            return _BillForm(member: member, bill: bill);
          },
        );
  }
}

/// A receipt chosen from the camera, gallery or file picker.
class _Receipt {
  const _Receipt(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  int get size => bytes.length;
}

class _BillForm extends ConsumerStatefulWidget {
  const _BillForm({required this.member, this.bill});
  final Member member;
  final Bill? bill;

  @override
  ConsumerState<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends ConsumerState<_BillForm> {
  static const _maxBytes = 10 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reason;
  late final TextEditingController _amount;
  late final TextEditingController _dateText;
  late DateTime _billDate;
  String? _eventId;
  _Receipt? _file;
  String? _fileError;
  bool _saving = false;

  bool get _isNew => widget.bill == null;
  bool get _canUploadReceipt => widget.member.role.canAddBill;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _reason = TextEditingController(text: b?.reason ?? '');
    _amount =
        TextEditingController(text: b == null ? '' : Money.toInputString(b.amount));
    _billDate = b?.billDate ?? DateTime.now();
    _dateText = TextEditingController(text: fmtDate(_billDate));
    _eventId = b?.eventId;
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _dateText.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _billDate = picked;
        _dateText.text = fmtDate(picked);
      });
    }
  }

  void _setReceipt(String name, Uint8List bytes) {
    if (bytes.length > _maxBytes) {
      setState(() => _fileError = 'That file is larger than 10 MB.');
      return;
    }
    // Camera files can come without an extension; the type is read from it.
    final safeName = name.contains('.') ? name : '$name.jpg';
    setState(() {
      _file = _Receipt(safeName, bytes);
      _fileError = null;
    });
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Choose a file (image or PDF)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      if (source == 'file') {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          withData: true,
        );
        if (res == null || res.files.isEmpty) return;
        final f = res.files.single;
        if (f.bytes == null) {
          setState(() =>
              _fileError = 'Could not read that file. Please try again.');
          return;
        }
        _setReceipt(f.name, f.bytes!);
      } else {
        final picked = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 2400,
        );
        if (picked == null) return;
        _setReceipt(picked.name, await picked.readAsBytes());
      }
    } catch (_) {
      setState(() => _fileError =
          'Could not open the camera or files. Check the app permissions and try again.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    if (_isNew && _file == null) {
      setState(() => _fileError = 'Please attach the receipt (image or PDF).');
      return;
    }
    if (!valid) return;

    final paise = Money.parseToPaise(_amount.text)!;
    final repo = ref.read(billRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_isNew) {
        // Upload first: a bill is never saved without its receipt.
        final id = const Uuid().v4();
        final path = await repo.uploadReceipt(
            eventId: _eventId!,
            billId: id,
            fileName: _file!.name,
            bytes: _file!.bytes);
        await repo.addBill(
          id: id,
          eventId: _eventId!,
          amount: paise,
          reason: _reason.text,
          date: _billDate,
          receiptPath: path,
          receiptType: BillRepository.contentTypeFor(_file!.name),
        );
      } else {
        String? path;
        if (_file != null) {
          path = await repo.uploadReceipt(
              eventId: _eventId!,
              billId: widget.bill!.id,
              fileName: _file!.name,
              bytes: _file!.bytes);
        }
        await repo.updateBill(
          id: widget.bill!.id,
          eventId: _eventId!,
          amount: paise,
          reason: _reason.text,
          date: _billDate,
          receiptPath: path,
          receiptType:
              _file == null ? null : BillRepository.contentTypeFor(_file!.name),
        );
      }
      if (!mounted) return;
      _snack(_isNew ? 'Bill added.' : 'Bill updated.');
      context.pop();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final events = ref.watch(eventsProvider).value ?? const <EventModel>[];
    final hasReceipt = widget.bill?.receiptPath != null;

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Add bill' : 'Edit bill')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (events.isEmpty)
                  Card(
                    color: scheme.tertiaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'There are no events yet. Create an event from the '
                          'Events tab first; every bill must belong to an event.'),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _eventId,
                  decoration: const InputDecoration(labelText: 'Event'),
                  items: [
                    for (final e in events)
                      DropdownMenuItem(value: e.id, child: Text(e.name)),
                  ],
                  onChanged: (v) => setState(() => _eventId = v),
                  validator: (v) => v == null ? 'Select an event' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateText,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reason,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a reason'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: '₹ '),
                  validator: (v) => Money.parseToPaise(v ?? '') == null
                      ? 'Enter a valid amount greater than 0'
                      : null,
                ),
                const SizedBox(height: 20),
                if (_canUploadReceipt) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(_file != null || hasReceipt
                        ? 'Replace receipt'
                        : 'Add receipt (photo, image or PDF)'),
                    onPressed: _saving ? null : _pickReceipt,
                  ),
                  const SizedBox(height: 8),
                  if (_file != null)
                    Text(
                        '${_file!.name}  (${(_file!.size / 1024).toStringAsFixed(0)} KB)')
                  else if (hasReceipt)
                    const Text('A receipt is already attached.'),
                  if (_fileError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_fileError!,
                          style: TextStyle(color: scheme.error)),
                    ),
                ] else
                  Text(
                    hasReceipt
                        ? 'Receipt attached. Only treasurers can replace it.'
                        : 'No receipt attached. Only treasurers can add one.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving || events.isEmpty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(_isNew ? 'Save bill' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
