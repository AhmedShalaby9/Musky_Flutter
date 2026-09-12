import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.section,
    required this.tenantId,
    required this.onExpired,
    required this.onTenant,
  });
  final MuskyApi api;
  final AppUser user;
  final String section;
  final int? tenantId;
  final VoidCallback onExpired;
  final ValueChanged<Map<String, dynamic>> onTenant;
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<Map<String, dynamic>> _rows = [];
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  bool _loading = true;
  String? _error;
  int _offset = 0, _requestId = 0;
  bool get _clients => widget.section == 'Clients';
  bool get _businesses => widget.section == 'Businesses';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = _businesses
          ? 'tenants'
          : 'tenants/${widget.tenantId}/${_clients ? 'clients' : 'users'}';
      final rows = await widget.api.list(path, offset: _offset);
      if (mounted && requestId == _requestId) {
        setState(() => _rows = rows);
      }
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      if (e.status == 401) {
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Unable to load these records. Please retry.');
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? client]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ClientDialog(
        api: widget.api,
        user: widget.user,
        tenantId: widget.tenantId!,
        client: client,
        onExpired: widget.onExpired,
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> client) async {
    setState(() => _loading = true);
    try {
      await widget.api.saveClient(widget.tenantId!, {
        'active': client['active'] != true,
      }, id: client['id'] as int);
      if (mounted) {
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.status == 401) {
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to update the client. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase().trim();
    final rows = _rows
        .where(
          (row) => [
            'name',
            'email',
            'phone',
            'id',
          ].any((key) => '${row[key] ?? ''}'.toLowerCase().contains(query)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.section,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _clients
                        ? 'The people you do business with.'
                        : _businesses
                        ? 'A dedicated workspace for each trader.'
                        : 'The people with access to this workspace.',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            if (_clients)
              FilledButton.icon(
                onPressed: _loading ? null : () => _edit(),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Add client'),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search this page',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ErrorNotice(_error!),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _clients ? Icons.people_outline : Icons.folder_open,
                            size: 46,
                            color: muted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            query.isNotEmpty
                                ? 'No matching records on this page'
                                : 'No ${widget.section.toLowerCase()} on this page',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            query.isNotEmpty
                                ? 'Try another search or clear the search field.'
                                : _clients
                                ? 'Add your first client to start organizing your contacts.'
                                : 'Refresh after records have been created.',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, size) => Scrollbar(
                      controller: _horizontal,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontal,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: size.maxWidth),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAF6),
                              ),
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: muted,
                                fontSize: 12,
                              ),
                              dataRowMinHeight: 66,
                              dataRowMaxHeight: 66,
                              columns: [
                                const DataColumn(label: Text('NAME')),
                                if (!_businesses)
                                  const DataColumn(label: Text('EMAIL')),
                                if (_clients)
                                  const DataColumn(label: Text('PHONE')),
                                if (!_clients && !_businesses)
                                  const DataColumn(label: Text('ROLE')),
                                const DataColumn(label: Text('STATUS')),
                                if (_clients || _businesses)
                                  const DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: rows
                                  .map(
                                    (row) => DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              '${row['name']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (!_businesses)
                                          DataCell(
                                            SizedBox(
                                              width: 200,
                                              child: Text(
                                                '${row['email'] ?? ''}'.isEmpty
                                                    ? '—'
                                                    : '${row['email']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        if (_clients)
                                          DataCell(
                                            Text(
                                              '${row['phone'] ?? ''}'.isEmpty
                                                  ? '—'
                                                  : '${row['phone']}',
                                            ),
                                          ),
                                        if (!_clients && !_businesses)
                                          DataCell(
                                            Text(
                                              row['role'] == 'trader'
                                                  ? 'Trader / owner'
                                                  : 'Admin',
                                            ),
                                          ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: row['active'] == true
                                                  ? const Color(0xFFEAF2E4)
                                                  : paper,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              row['active'] == true
                                                  ? 'Active'
                                                  : _clients
                                                  ? 'Archived'
                                                  : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: row['active'] == true
                                                    ? teal
                                                    : muted,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_clients)
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip:
                                                      'Edit ${row['name']}',
                                                  onPressed: () => _edit(row),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 19,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: row['active'] == true
                                                      ? 'Archive ${row['name']}'
                                                      : 'Restore ${row['name']}',
                                                  onPressed: () => _toggle(row),
                                                  icon: Icon(
                                                    row['active'] == true
                                                        ? Icons.archive_outlined
                                                        : Icons
                                                              .unarchive_outlined,
                                                    size: 19,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (_businesses)
                                          DataCell(
                                            TextButton(
                                              onPressed: row['active'] == true
                                                  ? () => widget.onTenant(row)
                                                  : null,
                                              child: const Text(
                                                'Open workspace',
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Page ${_offset ~/ 50 + 1} · ${_rows.length} records${query.isEmpty ? '' : ' · ${rows.length} matches'}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Previous page',
              onPressed: _loading || _offset == 0
                  ? null
                  : () {
                      _offset -= 50;
                      _load();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _loading || _rows.length < 50
                  ? null
                  : () {
                      _offset += 50;
                      _load();
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class ClientDialog extends StatefulWidget {
  const ClientDialog({
    super.key,
    required this.api,
    required this.user,
    required this.tenantId,
    this.client,
    required this.onExpired,
  });
  final MuskyApi api;
  final AppUser user;
  final int tenantId;
  final Map<String, dynamic>? client;
  final VoidCallback onExpired;
  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final key in ['name', 'email', 'phone', 'address', 'notes'])
      key: TextEditingController(text: widget.client?[key] as String? ?? ''),
  };
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      };
      if (widget.user.isSuperAdmin && widget.client == null) {
        // Tenant creation inserts the sole trader first, before supporting admins.
        final users = await widget.api.list('tenants/${widget.tenantId}/users');
        final owners = users.where(
          (u) => u['role'] == 'trader' && u['active'] == true,
        );
        if (owners.isEmpty) {
          throw const ApiException(
            'This workspace has no active trader owner.',
          );
        }
        data['user_id'] = owners.first['id'];
      }
      await widget.api.saveClient(
        widget.tenantId,
        data,
        id: widget.client?['id'] as int?,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.status == 401) {
        Navigator.pop(context);
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save the client. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.client == null ? 'Add client' : 'Edit client'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  ErrorNotice(_error!),
                  const SizedBox(height: 16),
                ],
                for (final entry in [
                  ('name', 'Client name', 150),
                  ('email', 'Email address', 254),
                  ('phone', 'Phone number', 40),
                  ('address', 'Address', 500),
                  ('notes', 'Notes', 2000),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _fields[entry.$1],
                      enabled: !_busy,
                      autofocus: entry.$1 == 'name',
                      maxLength: entry.$3,
                      maxLines: entry.$1 == 'notes' ? 3 : 1,
                      decoration: InputDecoration(
                        labelText: entry.$2,
                        counterText: '',
                      ),
                      validator: (v) {
                        if (entry.$1 == 'name' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Enter a client name.';
                        }
                        if (entry.$1 == 'email' &&
                            v != null &&
                            v.trim().isNotEmpty &&
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save client'),
        ),
      ],
    ),
  );
}
