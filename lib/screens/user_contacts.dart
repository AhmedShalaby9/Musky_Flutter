import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

/// Lets a user manage their own printable contact lines (e.g. an Instapay
/// number) and, for a super admin, control which of any user's contacts are
/// actually printed on the invoices that user creates.
class UserContactsDialog extends StatefulWidget {
  const UserContactsDialog({
    super.key,
    required this.api,
    required this.tenantId,
    required this.userId,
    required this.userName,
    required this.canManage,
    required this.canControlVisibility,
    required this.onExpired,
  });
  final MuskyApi api;
  final int tenantId;
  final int userId;
  final String userName;
  final bool canManage;
  final bool canControlVisibility;
  final VoidCallback onExpired;

  @override
  State<UserContactsDialog> createState() => _UserContactsDialogState();
}

class _UserContactsDialogState extends State<UserContactsDialog> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _error;

  String get _base =>
      'tenants/${widget.tenantId}/users/${widget.userId}/contacts';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.request('GET', _base);
      final data = (result['data'] as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _contacts = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onExpired();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showApiError(ApiException e) {
    if (e.status == 401) {
      widget.onExpired();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }

  Future<void> _add() async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ContactEditorDialog(),
    );
    if (data == null || !mounted) return;
    try {
      await widget.api.request('POST', _base, {
        'title': data['title'],
        'value': data['value'],
      });
      await _load();
    } on ApiException catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _edit(Map<String, dynamic> contact) async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ContactEditorDialog(
        title: contact['title'] as String,
        value: contact['value'] as String,
      ),
    );
    if (data == null || !mounted) return;
    try {
      await widget.api.request('PATCH', '$_base/${contact['id']}', {
        'title': data['title'],
        'value': data['value'],
      });
      await _load();
    } on ApiException catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _delete(Map<String, dynamic> contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف جهة الاتصال'),
        content: Text('حذف "${contact['title']}: ${contact['value']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.request('DELETE', '$_base/${contact['id']}');
      await _load();
    } on ApiException catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _toggleVisible(Map<String, dynamic> contact, bool value) async {
    try {
      await widget.api.request('PATCH', '$_base/${contact['id']}', {
        'visible_on_invoice': value,
      });
      await _load();
    } on ApiException catch (e) {
      _showApiError(e);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('جهات اتصال ${widget.userName}'),
    content: SizedBox(
      width: 460,
      height: 420,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: ErrorNotice(_error!))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.canControlVisibility
                      ? 'حدد أي جهات الاتصال تظهر في الفواتير التي ينشئها هذا الحساب.'
                      : 'تظهر جهات الاتصال في الفواتير فقط بعد اعتمادها من المدير العام.',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _contacts.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد جهات اتصال بعد.',
                            style: TextStyle(color: muted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _contacts.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final contact = _contacts[i];
                            final visible =
                                contact['visible_on_invoice'] == true;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${contact['title']}: ${contact['value']}',
                              ),
                              subtitle: Text(
                                visible ? 'ظاهر في الفاتورة' : 'غير ظاهر',
                                style: TextStyle(
                                  color: visible ? teal : muted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.canControlVisibility)
                                    Switch(
                                      value: visible,
                                      onChanged: (v) =>
                                          _toggleVisible(contact, v),
                                    ),
                                  if (widget.canManage) ...[
                                    IconButton(
                                      tooltip: 'تعديل',
                                      onPressed: () => _edit(contact),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      onPressed: () => _delete(contact),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    ),
    actions: [
      if (widget.canManage)
        TextButton.icon(
          onPressed: _loading ? null : _add,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('إضافة'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );
}

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog({this.title = '', this.value = ''});
  final String title;
  final String value;

  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title);
  late final _value = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, {
        'title': _title.text.trim(),
        'value': _value.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title.isEmpty ? 'إضافة جهة اتصال' : 'تعديل جهة الاتصال'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                hintText: 'مثال: Instapay',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل عنواناً.' : null,
            ),
            TextFormField(
              controller: _value,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'القيمة',
                hintText: 'مثال: 0102223232',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل قيمة.' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _submit, child: const Text('حفظ')),
    ],
  );
}
