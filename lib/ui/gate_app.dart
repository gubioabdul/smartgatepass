import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/vehicle_repository.dart';
import '../domain/vehicle_log.dart';
import '../services/gate_hardware.dart';

const ink = Color(0xFF142D39);
const teal = Color(0xFF087F78);

String friendlyError(Object error) => error is GateException
    ? error.message
    : 'Could not complete this action. Check device permissions and storage, then retry.';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class GateHome extends StatefulWidget {
  const GateHome({
    super.key,
    required this.repository,
    required this.reader,
    required this.printer,
  });
  final VehicleRepository repository;
  final PlateReader reader;
  final PassPrinter printer;
  @override
  State<GateHome> createState() => _GateHomeState();
}

class _GateHomeState extends State<GateHome> {
  List<VehicleLog> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
  }

  Future<void> _recoverPhoto() async {
    try {
      final text = await widget.reader.recoverText();
      if (mounted && text != null) await _entry(recoveredText: text);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    }
  }

  Future<void> _refresh() async {
    try {
      final records = await widget.repository.activeRecords();
      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _entry({String? recoveredText}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryPage(
          repository: widget.repository,
          reader: widget.reader,
          printer: widget.printer,
          recoveredText: recoveredText,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _search({bool exitMode = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordsPage(
          repository: widget.repository,
          printer: widget.printer,
          exitMode: exitMode,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _record(VehicleLog record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PassPage(
          record: record,
          repository: widget.repository,
          printer: widget.printer,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: teal),
          SizedBox(width: 10),
          Text(
            'SmartGatePass',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh records',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.offline_bolt_outlined,
                        color: Color(0xFF9CE5CD),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'OFFLINE GATE OPERATIONS',
                        style: TextStyle(
                          color: Color(0xFF9CE5CD),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Every entry.\nEvery exit. Recorded.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _loading || _error != null ? '—' : '${_records.length}',
                        style: const TextStyle(
                          color: Color(0xFFF4D57A),
                          fontSize: 46,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 12, bottom: 10),
                        child: Text(
                          'vehicles currently inside',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gate actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            ActionTile(
              icon: Icons.login_rounded,
              title: 'Vehicle Entry',
              subtitle: 'Read a plate and issue a gate pass',
              onTap: _entry,
              primary: true,
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.logout_rounded,
              title: 'Vehicle Exit',
              subtitle: 'Scan a pass and verify the vehicle',
              onTap: () => _search(exitMode: true),
            ),
            const SizedBox(height: 10),
            ActionTile(
              icon: Icons.manage_search_rounded,
              title: 'Search Active Record',
              subtitle: 'Find a plate or reprint a saved pass',
              onTap: _search,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Latest active passes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
                TextButton(onPressed: _search, child: const Text('View all')),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              InfoPanel(icon: Icons.error_outline, text: _error!)
            else if (_records.isEmpty)
              const InfoPanel(
                icon: Icons.directions_car_outlined,
                text: 'No vehicles inside yet. Register the first entry to create a gate pass.',
              )
            else
              ..._records
                  .take(4)
                  .map((r) => RecordTile(record: r, onTap: () => _record(r))),
            const SizedBox(height: 22),
            const Text(
              'Records stay on this phone. Use the same device for entry and exit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Material(
    color: primary ? teal : Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: primary ? Colors.white : teal, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: primary ? Colors.white : ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: primary ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: primary ? Colors.white : ink),
          ],
        ),
      ),
    ),
  );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: teal, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text, style: const TextStyle(color: ink, height: 1.5)),
        ),
      ],
    ),
  );
}

class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record, required this.onTap});
  final VehicleLog record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE4F1EC),
        foregroundColor: teal,
        child: Icon(Icons.directions_car_outlined),
      ),
      title: Text(
        record.plateNumber,
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
      subtitle: Text(
        'Entered ${formatTimestamp(record.entryTimestamp)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class EntryPage extends StatefulWidget {
  const EntryPage({
    super.key,
    required this.repository,
    required this.reader,
    required this.printer,
    this.recoveredText,
  });
  final VehicleRepository repository;
  final PlateReader reader;
  final PassPrinter printer;
  final String? recoveredText;
  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _form = GlobalKey<FormState>();
  final _plate = TextEditingController();
  bool _verified = false, _busy = false;
  String? _error, _ocrText;
  List<String> _candidates = [];

  @override
  void initState() {
    super.initState();
    if (widget.recoveredText != null) _acceptOcr(widget.recoveredText!);
  }

  void _acceptOcr(String text) {
    _ocrText = text;
    _candidates = plateCandidates(text);
    if (_candidates.length == 1) _plate.text = _candidates.single;
    _verified = false;
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await widget.reader.captureText();
      if (mounted && text != null) setState(() => _acceptOcr(text));
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_verified) {
      setState(
        () => _error = 'Verify the plate against the vehicle before saving.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final record = await widget.repository.registerEntry(_plate.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PassPage(
            record: record,
            repository: widget.repository,
            printer: widget.printer,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Vehicle Entry')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Create an entry pass',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Capture the plate, check the result, then save the vehicle entry.',
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _busy ? null : _capture,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _busy ? 'Please wait…' : 'Capture plate with camera',
                ),
              ),
              if (_ocrText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _candidates.isEmpty
                      ? 'No clear plate found. Enter it below.'
                      : 'OCR suggestions — check carefully',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 8,
                  children: _candidates
                      .map(
                        (plate) => ActionChip(
                          label: Text(plate),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _plate.text = plate;
                                  _verified = false;
                                }),
                        ),
                      )
                      .toList(),
                ),
                ExpansionTile(
                  title: const Text('View captured text'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _ocrText!.isEmpty ? 'No text detected.' : _ocrText!,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              TextFormField(
                controller: _plate,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                maxLength: 20,
                validator: validatePlate,
                onChanged: (_) => setState(() {
                  _verified = false;
                  _error = null;
                }),
                decoration: const InputDecoration(
                  labelText: 'Plate number',
                  hintText: 'e.g. ABC-123DE',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _verified,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _verified = value ?? false),
                title: const Text('I checked this plate against the vehicle.'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Save entry & create pass'),
              ),
              const SizedBox(height: 16),
              const Text(
                'The entry is saved before printing. If printing fails, find the active record and print the same pass again.',
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.repository,
    required this.printer,
    this.exitMode = false,
  });
  final VehicleRepository repository;
  final PassPrinter printer;
  final bool exitMode;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _query = TextEditingController();
  List<VehicleLog> _records = [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.repository.activeRecords(query: _query.text);
      if (mounted && request == _request) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(VehicleLog record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.exitMode
            ? ExitPage(record: record, repository: widget.repository)
            : PassPage(
                record: record,
                repository: widget.repository,
                printer: widget.printer,
              ),
      ),
    );
    await _load();
  }

  Future<void> _scan() async {
    final id = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));
    if (id == null || !mounted) return;
    try {
      final record = await widget.repository.byTicket(id);
      if (!mounted) return;
      if (record == null) {
        showMessage(
          context,
          'Ticket not found on this phone. Search by plate or verify with the entry officer.',
        );
        return;
      }
      if (!record.isActive) {
        showMessage(
          context,
          'This pass was already closed at ${formatTimestamp(record.exitTimestamp!)}.',
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ExitPage(record: record, repository: widget.repository),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.exitMode ? 'Vehicle Exit' : 'Active Records'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.exitMode) ...[
                  FilledButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan gate pass'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Or find the active vehicle manually',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _query,
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    labelText: 'Search plate or ticket ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () {
                        _query.clear();
                        _load();
                      },
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_records.isEmpty)
                          const InfoPanel(
                            icon: Icons.search_off,
                            text: 'No active records found. Check the plate or ticket ID. Closed passes are not listed here.',
                          ),
                        ..._records.map(
                          (r) => RecordTile(record: r, onTap: () => _open(r)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class PassPage extends StatefulWidget {
  const PassPage({
    super.key,
    required this.record,
    required this.repository,
    required this.printer,
  });
  final VehicleLog record;
  final VehicleRepository repository;
  final PassPrinter printer;
  @override
  State<PassPage> createState() => _PassPageState();
}

class _PassPageState extends State<PassPage> {
  bool _busy = false, _wide = false;
  String? _message;
  bool _failed = false;

  Future<void> _print() async {
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      final current = await widget.repository.byTicket(widget.record.ticketId);
      if (current == null || !current.isActive) {
        throw const GateException(
          'This pass is no longer active. Return to active records.',
        );
      }
      final devices = await widget.printer.pairedDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        throw const GateException(
          'No paired printer found. Pair an ESC/POS thermal printer in phone Bluetooth settings, then retry.',
        );
      }
      final device = await showModalBottomSheet<PrinterDevice>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Choose paired thermal printer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ...devices.map(
                (d) => ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(d.name),
                  subtitle: Text(d.address),
                  onTap: () => Navigator.pop(context, d),
                ),
              ),
            ],
          ),
        ),
      );
      if (device == null) return;
      await widget.printer.printPass(current, device, widePaper: _wide);
      if (mounted) {
        setState(
          () => _message = 'Ticket sent to printer. Check the paper and QR code before handing it to the driver.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = friendlyError(error);
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exit() async {
    final closed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ExitPage(record: widget.record, repository: widget.repository),
      ),
    );
    if (mounted && closed == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Gate Pass')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const InfoPanel(
              icon: Icons.check_circle_outline,
              text:
                  'Entry saved on this phone. This vehicle has an active pass.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Text(
                    'SMARTGATEPASS',
                    style: TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.record.plateNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entry: ${formatTimestamp(widget.record.entryTimestamp)}',
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    label: 'Gate pass QR code containing ticket ID',
                    child: QrImageView(
                      data: widget.record.ticketId,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'TICKET ID',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    widget.record.ticketId,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.record.ticketId),
                      );
                      if (context.mounted) {
                        showMessage(context, 'Ticket ID copied.');
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy ticket ID'),
                  ),
                  const Divider(),
                  const Text(
                    'Keep this pass for vehicle exit.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('80 mm paper'),
              subtitle: const Text('Off uses standard 58 mm paper'),
              value: _wide,
              onChanged: _busy ? null : (v) => setState(() => _wide = v),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _print,
              icon: const Icon(Icons.print_outlined),
              label: Text(_busy ? 'Working with printer…' : 'Print gate pass'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _failed ? Theme.of(context).colorScheme.error : teal,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _exit,
              icon: const Icon(Icons.logout),
              label: const Text('Verify vehicle exit'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ExitPage extends StatefulWidget {
  const ExitPage({super.key, required this.record, required this.repository});
  final VehicleLog record;
  final VehicleRepository repository;
  @override
  State<ExitPage> createState() => _ExitPageState();
}

class _ExitPageState extends State<ExitPage> {
  final _plate = TextEditingController();
  bool _verified = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (normalizePlate(_plate.text) != widget.record.plateNumber) {
      setState(
        () => _error =
            'Plate does not match. Check the vehicle before proceeding.',
      );
      return;
    }
    if (!_verified) {
      setState(
        () => _error = 'Confirm that you physically checked the vehicle.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record vehicle exit?'),
        content: Text(
          'Close the active pass for ${widget.record.plateNumber}? This pass cannot be used again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm exit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final closed = await widget.repository.recordExit(
        widget.record.ticketId,
        _plate.text,
      );
      if (!mounted) return;
      showMessage(
        context,
        'Exit recorded for ${closed.plateNumber} at ${formatTimestamp(closed.exitTimestamp!)}.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Verify Vehicle Exit')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const InfoPanel(
              icon: Icons.verified_user_outlined,
              text: 'A ticket identifies a record. Check the actual vehicle before authorizing exit.',
            ),
            const SizedBox(height: 24),
            Text(
              widget.record.plateNumber,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text('Entered ${formatTimestamp(widget.record.entryTimestamp)}'),
            const SizedBox(height: 8),
            SelectableText(
              'Ticket: ${widget.record.ticketId}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _plate,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {
                _verified = false;
                _error = null;
              }),
              decoration: const InputDecoration(
                labelText: 'Type the plate on the vehicle',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _verified,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _verified = v ?? false),
              title: const Text(
                'I physically checked the vehicle and its plate.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _close,
              icon: const Icon(Icons.logout),
              label: Text(_busy ? 'Saving exit…' : 'Record exit & close pass'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _returned = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Gate Pass')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Place the ticket QR code in view. You will verify the vehicle before closing the pass.',
            ),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Camera unavailable. Allow camera access in phone settings, or go back and search by plate.',
                  ),
                ),
              ),
              onDetect: (capture) {
                if (_returned) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue?.trim();
                  if (value != null && value.isNotEmpty) {
                    _returned = true;
                    Navigator.pop(context, value);
                    break;
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.search),
              label: const Text('Use manual search instead'),
            ),
          ),
        ],
      ),
    ),
  );
}
