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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadCancellation.cancel();
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
        direction: balanceMinor < 0 ? 'out' : 'in',
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _editReceipt(Map<String, dynamic> entry) async {
    final direction = entry['kind'] == 'client_payment' ? 'out' : 'in';
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ReceiptDialog(
        api: widget.api,
        tenantId: widget.tenantId,
        clientId: widget.clientId,
        balanceMinor: (_client?['balance_minor'] as num?)?.toInt() ?? 0,
        onExpired: widget.onExpired,
        direction: direction,
        receipt: entry,
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
      case 'client_payment':
        return 'سداد للعميل';
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

  Widget _detailSummary(String label, String value, Color color) => Container(
    width: 210,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _ledgerCards() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
    itemCount: _entries.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final entry = _entries[index];
      final delta = (entry['delta_minor'] as num).toInt();
      final running = (entry['running_balance'] as num).toInt();
      final invoice = _invoiceEntry(entry);
      final positive = delta >= 0;
      final color = positive ? const Color(0xFFA33624) : teal;
      final icon =
          entry['kind'] == 'receipt' || entry['kind'] == 'invoice_payment'
          ? Icons.payments_outlined
          : entry['document_type'] == 'purchase'
          ? Icons.shopping_cart_outlined
          : Icons.receipt_long_outlined;
      final editableReceipt =
          (entry['kind'] == 'receipt' || entry['kind'] == 'client_payment') &&
          entry['ref_id'] != null;
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
            onTap: invoice
                ? () => _openInvoice((entry['ref_id'] as num).toInt())
                : editableReceipt
                    ? () => _editReceipt(entry)
                    : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: LayoutBuilder(
              builder: (context, size) {
                final fields = [
                  _ledgerField('التاريخ', _formatAt(entry['at'] as String?)),
                  _ledgerField('الطريقة', _methodLabel(entry['method'])),
                  _ledgerField(
                    'الرصيد بعد الحركة',
                    egp(running),
                    emphasize: true,
                  ),
                ];
                final identity = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: .10),
                      foregroundColor: color,
                      child: Icon(icon, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _kindLabel(entry),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if ('${entry['notes'] ?? ''}'.isNotEmpty)
                          SizedBox(
                            width: 180,
                            child: Text(
                              '${entry['notes']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
                final amount = Text(
                  '${positive ? '+' : '−'} ${egp(delta.abs())}',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                );
                if (size.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: fields
                            .map((field) => SizedBox(width: 155, child: field))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      amount,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: identity),
                    for (final field in fields) Expanded(child: field),
                    amount,
                    if (invoice)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: muted,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _ledgerField(String label, String value, {bool emphasize = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? teal : ink,
            ),
          ),
        ],
      );

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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _detailSummary(
                  'الرصيد الحالي',
                  egp(balanceMinor),
                  balanceMinor < 0
                      ? const Color(0xFFA33624)
                      : balanceMinor == 0
                      ? muted
                      : teal,
                ),
                _detailSummary(
                  'حالة الحساب',
                  balanceMinor > 0
                      ? 'مستحق من العميل'
                      : balanceMinor < 0
                      ? 'مستحق للعميل'
                      : 'متوازن',
                  ink,
                ),
                _detailSummary(
                  'عدد الحركات',
                  '${_entries.length}',
                  const Color(0xFF536D8A),
                ),
                FilledButton.icon(
                  onPressed: (_loading || balanceMinor == 0)
                      ? null
                      : _showReceiptDialog,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(balanceMinor < 0 ? 'سداد للعميل' : 'تسجيل دفعة'),
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
                : _ledgerCards(),
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
    this.direction = 'in',
    this.receipt,
  });
  final MuskyApi api;
  final int tenantId;
  final int clientId;
  final int balanceMinor;
  final VoidCallback onExpired;
  final String direction;
  final Map<String, dynamic>? receipt;

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
  void initState() {
    super.initState();
    final receipt = widget.receipt;
    if (receipt != null) {
      final amount = ((receipt['amount_minor'] as num?) ?? (receipt['delta_minor'] as num?)?.abs() ?? 0).toInt();
      _amount.text = (amount / 100).toStringAsFixed(2);
      _notes.text = '${receipt['notes'] ?? ''}';
      _method = receipt['method'] as String? ?? 'cash';
    }
  }

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
      if (widget.receipt == null) {
        await widget.api.createClientReceipt(widget.tenantId, widget.clientId, amountMinor, _method, _notes.text.trim(), direction: widget.direction);
      } else {
        await widget.api.updateClientReceipt(widget.tenantId, widget.clientId, (widget.receipt!['ref_id'] as num).toInt(), amountMinor, _method, _notes.text.trim(), direction: widget.direction);
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
      if (mounted) setState(() => _error = 'تعذّر تسجيل الدفعة. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        widget.receipt == null
            ? (widget.direction == 'out' ? 'سداد للعميل' : 'تسجيل دفعة من العميل')
            : 'تعديل الدفعة',
      ),
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
                    if (widget.receipt == null && minor > widget.balanceMinor)
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
          child: Text(_busy ? 'جارٍ الحفظ…' : widget.receipt == null ? 'تسجيل' : 'حفظ التعديل'),
        ),
      ],
    ),
  );
}
