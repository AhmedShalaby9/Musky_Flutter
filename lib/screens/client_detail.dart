import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';
import 'invoice_editor.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.api,
    required this.tenantId,
    required this.clientId,
    required this.clientName,
    required this.onExpired,
  });
  final MuskyApi api;
  final int tenantId;
  final int clientId;
  final String clientName;
  final VoidCallback onExpired;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _loadCancellation = ApiRequestCancellation();
  Map<String, dynamic>? _client;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  final _horizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadCancellation.cancel();
    _horizontal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.clientLedger(
        widget.tenantId,
        widget.clientId,
        cancellation: _loadCancellation,
      );
      if (!mounted) return;
      setState(() {
        _client = data['client'] as Map<String, dynamic>;
        _entries = (data['entries'] as List).cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذّر تحميل كشف الحساب. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showReceiptDialog() async {
    final balanceMinor = (_client?['balance_minor'] as num?)?.toInt() ?? 0;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ReceiptDialog(
        api: widget.api,
        tenantId: widget.tenantId,
        clientId: widget.clientId,
        balanceMinor: balanceMinor,
        onExpired: widget.onExpired,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  bool _invoiceEntry(Map<String, dynamic> entry) =>
      (entry['kind'] == 'invoice' ||
          entry['kind'] == 'void' ||
          entry['kind'] == 'purchase' ||
          entry['kind'] == 'purchase_void' ||
          entry['kind'] == 'reactivate' ||
          entry['kind'] == 'purchase_reactivate') &&
      entry['ref_id'] != null;

  Future<void> _openInvoice(int invoiceId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => InvoiceDetails(
        api: widget.api,
        tenantId: widget.tenantId,
        invoiceId: invoiceId,
        onExpired: widget.onExpired,
      ),
    );
    if (mounted) await _load();
  }

  String _kindLabel(Map<String, dynamic> entry) {
    final kind = entry['kind'] as String? ?? '';
    final type = invoiceTypeLabel(entry['document_type']);
    switch (kind) {
      case 'opening':
        return 'رصيد افتتاحي';
      case 'invoice':
      case 'purchase':
      case 'reactivate':
      case 'purchase_reactivate':
        final num = entry['invoice_number'];
        if (num != null) {
          return 'فاتورة $type INV-${num.toString().padLeft(6, '0')}';
        }
        return 'فاتورة $type';
      case 'void':
      case 'purchase_void':
        return 'إلغاء فاتورة $type';
      case 'invoice_payment':
        final num = entry['invoice_number'];
        if (num != null) {
          return '${type == 'شراء' ? 'دفعة للمورد' : 'دفعة من العميل'} INV-${num.toString().padLeft(6, '0')}';
        }
        return 'دفعة فاتورة';
      case 'receipt':
        return 'دفعة عامة';
      case 'reversal':
        return 'عكس دفعة';
      default:
        return kind;
    }
  }

  String _methodLabel(dynamic method) {
    if (method == null) return '—';
    return method == 'cash' ? 'نقدي' : 'إلكتروني';
  }

  String _formatAt(String? at) {
    if (at == null) return '—';
    try {
      final dt = DateTime.parse(at).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return at;
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceMinor = (_client?['balance_minor'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        elevation: 0,
        leading: BackButton(color: ink),
        title: Text(
          widget.clientName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الرصيد الحالي',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        egp(balanceMinor),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: balanceMinor < 0
                              ? const Color(0xFFA33624)
                              : balanceMinor == 0
                              ? muted
                              : teal,
                          letterSpacing: -.5,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: (_loading || balanceMinor <= 0)
                      ? null
                      : _showReceiptDialog,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('تسجيل دفعة'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table
          Expanded(
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
                : _entries.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد حركات بعد',
                      style: TextStyle(color: muted, fontSize: 16),
                    ),
                  )
                : Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
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
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 52,
                          columns: const [
                            DataColumn(label: Text('التاريخ')),
                            DataColumn(label: Text('النوع')),
                            DataColumn(label: Text('الوصف')),
                            DataColumn(label: Text('الطريقة')),
                            DataColumn(label: Text('المبلغ'), numeric: true),
                            DataColumn(
                              label: Text('الرصيد التراكمي'),
                              numeric: true,
                            ),
                          ],
                          rows: _entries.map((entry) {
                            final delta = (entry['delta_minor'] as num).toInt();
                            final running = (entry['running_balance'] as num)
                                .toInt();
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    _formatAt(entry['at'] as String?),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  _invoiceEntry(entry)
                                      ? TextButton(
                                          onPressed: () => _openInvoice(
                                            (entry['ref_id'] as num).toInt(),
                                          ),
                                          child: Text(_kindLabel(entry)),
                                        )
                                      : Text(_kindLabel(entry)),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 160,
                                    child: Text(
                                      '${entry['notes'] ?? ''}'.isEmpty
                                          ? '—'
                                          : '${entry['notes']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(_methodLabel(entry['method']))),
                                DataCell(
                                  Text(
                                    egp(delta.abs()),
                                    style: TextStyle(
                                      color: delta < 0
                                          ? teal
                                          : const Color(0xFFA33624),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    egp(running),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: running < 0
                                          ? const Color(0xFFA33624)
                                          : running == 0
                                          ? muted
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ReceiptDialog extends StatefulWidget {
  const ReceiptDialog({
    super.key,
    required this.api,
    required this.tenantId,
    required this.clientId,
    required this.balanceMinor,
    required this.onExpired,
  });
  final MuskyApi api;
  final int tenantId;
  final int clientId;
  final int balanceMinor;
  final VoidCallback onExpired;

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'cash';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final amountMinor = parseMoney(_amount.text);
      if (amountMinor == null || amountMinor <= 0) {
        setState(() => _error = 'أدخل مبلغاً صحيحاً.');
        return;
      }
      await widget.api.createClientReceipt(
        widget.tenantId,
        widget.clientId,
        amountMinor,
        _method,
        _notes.text.trim(),
      );
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
      if (mounted) setState(() => _error = 'تعذّر تسجيل الدفعة. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('تسجيل دفعة'),
      content: SizedBox(
        width: 420,
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
                TextFormField(
                  controller: _amount,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'المبلغ (ج.م.)',
                    hintText: '0.00',
                    helperText: 'الحد الأقصى: ${egp(widget.balanceMinor)}',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'أدخل المبلغ.';
                    final minor = parseMoney(v);
                    if (minor == null || minor <= 0)
                      return 'أدخل مبلغاً صحيحاً.';
                    if (minor > widget.balanceMinor)
                      return 'المبلغ أكبر من الرصيد.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(value: 'online', child: Text('إلكتروني')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _method = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    counterText: '',
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
          child: Text(_busy ? 'جارٍ الحفظ…' : 'تسجيل'),
        ),
      ],
    ),
  );
}
