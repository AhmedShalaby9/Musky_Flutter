import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../core/api.dart';
import '../core/money.dart';
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
  Timer? _searchTimer;
  bool _loading = true;
  String? _error;
  int _offset = 0, _requestId = 0;
  bool get _clients => widget.section == 'العملاء';
  bool get _businesses => widget.section == 'الأعمال';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
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
      final rows = await widget.api.list(path, offset: _offset, q: _clients ? _search.text.trim() : '');
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
        setState(() => _error = 'تعذّر تحميل السجلات. حاول مجدداً.');
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

  Future<void> _addTrader() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          TraderDialog(api: widget.api, onExpired: widget.onExpired),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text('هل تريد حذف "${client['name']}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await widget.api.request(
        'DELETE',
        'tenants/${widget.tenantId}/clients/${client['id']}',
      );
      if (mounted) {
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر حذف العميل. حاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
        setState(() => _error = 'تعذّر تحديث العميل. حاول مجدداً.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
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
                        ? 'الأشخاص الذين تتعامل معهم.'
                        : _businesses
                        ? 'مساحة عمل مخصصة لكل تاجر.'
                        : 'الأشخاص الذين يصلون إلى مساحة العمل.',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            if (_clients)
              FilledButton.icon(
                onPressed: _loading ? null : () => _edit(),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('إضافة عميل'),
              ),
            if (_businesses)
              FilledButton.icon(
                onPressed: _loading ? null : _addTrader,
                icon: const Icon(Icons.add, size: 19),
                label: const Text('إضافة تاجر'),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) {
                  _searchTimer?.cancel();
                  _searchTimer = Timer(const Duration(milliseconds: 400), () {
                    _offset = 0;
                    _load();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'بحث في جميع السجلات',
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
              tooltip: 'تحديث',
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
                            child: const Text('إعادة المحاولة'),
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
                            _search.text.trim().isNotEmpty
                                ? 'لا توجد سجلات مطابقة'
                                : 'لا توجد سجلات في هذه الصفحة',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _search.text.trim().isNotEmpty
                                ? 'جرّب بحثاً آخر أو امسح حقل البحث.'
                                : _clients
                                ? 'أضف أول عميل لتنظيم جهات الاتصال.'
                                : 'حدّث الصفحة بعد إنشاء السجلات.',
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
                                const DataColumn(label: Text('الاسم')),
                                if (!_clients && !_businesses)
                                  const DataColumn(
                                    label: Text('البريد الإلكتروني'),
                                  ),
                                if (_clients)
                                  const DataColumn(label: Text('الهاتف')),
                                if (_clients)
                                  const DataColumn(
                                    label: Text('الرصيد'),
                                    numeric: true,
                                  ),
                                if (!_clients && !_businesses)
                                  const DataColumn(label: Text('الدور')),
                                const DataColumn(label: Text('الحالة')),
                                if (_clients || _businesses)
                                  const DataColumn(label: Text('الإجراءات')),
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
                                        if (!_clients && !_businesses)
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
                                        if (_clients)
                                          DataCell(
                                            _BalanceCell(
                                              minor: (row['balance_minor'] as num?)?.toInt() ?? 0,
                                            ),
                                          ),
                                        if (!_clients && !_businesses)
                                          DataCell(
                                            Text(
                                              row['role'] == 'trader'
                                                  ? 'تاجر / مالك'
                                                  : 'مسؤول',
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
                                                  ? 'نشط'
                                                  : _clients
                                                  ? 'مؤرشف'
                                                  : 'غير نشط',
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
                                                      'تعديل ${row['name']}',
                                                  onPressed: () => _edit(row),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 19,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: row['active'] == true
                                                      ? 'أرشفة ${row['name']}'
                                                      : 'استعادة ${row['name']}',
                                                  onPressed: () => _toggle(row),
                                                  icon: Icon(
                                                    row['active'] == true
                                                        ? Icons.archive_outlined
                                                        : Icons
                                                              .unarchive_outlined,
                                                    size: 19,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'حذف ${row['name']}',
                                                  onPressed: () =>
                                                      _delete(row),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 19,
                                                    color: Colors.red,
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
                                                'فتح مساحة العمل',
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
                'صفحة ${_offset ~/ 50 + 1} · ${_rows.length} سجل',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'الصفحة السابقة',
              onPressed: _loading || _offset == 0
                  ? null
                  : () {
                      _offset -= 50;
                      _load();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'الصفحة التالية',
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
    for (final key in ['name', 'phone', 'address'])
      key: TextEditingController(text: widget.client?[key] as String? ?? ''),
  };
  late final TextEditingController _balance = TextEditingController(
    text: _formatBalance(widget.client?['opening_balance_minor']),
  );
  String? _error;
  bool _busy = false;

  static String _formatBalance(dynamic minor) {
    if (minor == null) return '';
    final v = (minor as num).toInt();
    if (v == 0) return '';
    final abs = v.abs();
    final major = abs ~/ 100;
    final cents = abs % 100;
    final str = cents == 0 ? '$major' : '$major.${cents.toString().padLeft(2, '0')}';
    return v < 0 ? '-$str' : str;
  }

  static int? _parseBalance(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final neg = t.startsWith('-');
    final raw = neg ? t.substring(1) : t;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) return null;
    final parts = raw.split('.');
    var cents = int.parse(parts[0]) * 100;
    if (parts.length == 2) cents += int.parse(parts[1].padRight(2, '0'));
    return neg ? -cents : cents;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _balance.dispose();
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
        for (final entry in _fields.entries)
          entry.key: entry.value.text.trim().isEmpty && entry.key != 'name'
              ? null
              : entry.value.text.trim(),
        'opening_balance_minor': _parseBalance(_balance.text) ?? 0,
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
        setState(() => _error = 'تعذّر حفظ العميل. حاول مجدداً.');
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
      title: Text(widget.client == null ? 'إضافة عميل' : 'تعديل عميل'),
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
                  ('name', 'اسم العميل', 150),
                  ('phone', 'رقم الهاتف', 40),
                  ('address', 'العنوان', 500),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _fields[entry.$1],
                      enabled: !_busy,
                      autofocus: entry.$1 == 'name',
                      maxLength: entry.$3,
                      decoration: InputDecoration(
                        labelText: entry.$2,
                        counterText: '',
                      ),
                      validator: (v) {
                        if (entry.$1 == 'name' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'أدخل اسم العميل.';
                        }
                        return null;
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _balance,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي (ج.م.)',
                      hintText: '0.00',
                      helperText: 'موجب: العميل مدين. سالب: أنت المدين.',
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty &&
                          _parseBalance(v) == null) {
                        return 'أدخل رقماً صحيحاً (مثال: 150 أو -75.50).';
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
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ العميل'),
        ),
      ],
    ),
  );
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({required this.minor});
  final int minor;
  @override
  Widget build(BuildContext context) => Text(
    egp(minor),
    style: TextStyle(
      color: minor < 0 ? const Color(0xFFA33624) : null,
      fontWeight: FontWeight.w500,
    ),
  );
}

class TraderDialog extends StatefulWidget {
  const TraderDialog({super.key, required this.api, required this.onExpired});
  final MuskyApi api;
  final VoidCallback onExpired;
  @override
  State<TraderDialog> createState() => _TraderDialogState();
}

class _TraderDialogState extends State<TraderDialog> {
  final _form = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _traderName = TextEditingController();
  final _traderEmail = TextEditingController();
  final _traderPassword = TextEditingController();
  bool _obscure = true;
  String? _logoPath;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _businessName.dispose();
    _traderName.dispose();
    _traderEmail.dispose();
    _traderPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tenant = await widget.api.createTenant(
        _businessName.text.trim(),
        _traderName.text.trim(),
        _traderEmail.text.trim(),
        _traderPassword.text,
      );
      if (_logoPath != null) {
        await widget.api.uploadTenantLogo(tenant['id'] as int, _logoPath!);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        Navigator.pop(context);
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر إنشاء التاجر. حاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('إضافة تاجر'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorNotice(_error!),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'النشاط التجاري',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final file = await openFile(
                            acceptedTypeGroups: [
                              XTypeGroup(
                                label: 'Logo',
                                extensions: ['png', 'jpg', 'jpeg', 'webp'],
                              ),
                            ],
                          );
                          if (file != null && mounted)
                            setState(() => _logoPath = file.path);
                        },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _logoPath == null
                        ? 'Ø§Ø®ØªÙŠØ§Ø± Ø´Ø¹Ø§Ø± Ø§Ù„Ø´Ø±ÙƒØ©'
                        : _logoPath!.split(RegExp(r'[\\/]')).last,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessName,
                  enabled: !_busy,
                  autofocus: true,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'اسم النشاط التجاري',
                    counterText: '',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل اسم النشاط التجاري.'
                      : null,
                ),
                const SizedBox(height: 20),
                const Text(
                  'حساب التاجر',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _traderName,
                  enabled: !_busy,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    counterText: '',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل اسم التاجر.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _traderEmail,
                  enabled: !_busy,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'أدخل بريداً إلكترونياً.';
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(v.trim())) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _traderPassword,
                  enabled: !_busy,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل كلمة المرور.';
                    if (v.length < 12)
                      return 'يجب أن تكون كلمة المرور 12 حرفاً على الأقل.';
                    if (v.length > 72)
                      return 'يجب ألا تتجاوز كلمة المرور 72 حرفاً.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'جارٍ الإنشاء…' : 'إنشاء تاجر'),
        ),
      ],
    ),
  );
}
