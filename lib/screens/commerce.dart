import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';
import 'invoice_editor.dart';

class CommerceScreen extends StatefulWidget {
  const CommerceScreen({
    super.key,
    required this.api,
    required this.tenantId,
    required this.products,
    required this.onExpired,
  });
  final MuskyApi api;
  final int tenantId;
  final bool products;
  final VoidCallback onExpired;
  @override
  State<CommerceScreen> createState() => _CommerceScreenState();
}

class _CommerceScreenState extends State<CommerceScreen> {
  List<Map<String, dynamic>> _rows = [];
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String? _error;
  String _status = '';
  bool _busy = true;
  int _offset = 0, _request = 0;
  String get _base =>
      'tenants/${widget.tenantId}/${widget.products ? 'products' : 'invoices'}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handle(Object error) {
    if (!mounted) {
      return;
    }
    if (error is ApiException && error.status == 401) {
      widget.onExpired();
    } else {
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'تعذّر إتمام العملية. حاول مجدداً.',
      );
    }
  }

  Future<void> _load() async {
    final ticket = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          'limit': '50',
          'offset': '$_offset',
          if (widget.products) 'q': _search.text.trim(),
          if (!widget.products && _status.isNotEmpty) 'status': _status,
        },
      ).query;
      final response = await widget.api.request('GET', '$_base?$query');
      if (mounted && ticket == _request) {
        setState(
          () => _rows = (response['data'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      if (ticket == _request) {
        _handle(e);
      }
    } finally {
      if (mounted && ticket == _request) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _product([Map<String, dynamic>? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductDialog(
        api: widget.api,
        tenantId: widget.tenantId,
        product: product,
        onExpired: widget.onExpired,
      ),
    );
    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${product['title']}" نهائياً؟'),
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
    setState(() => _busy = true);
    try {
      await widget.api.request(
        'DELETE',
        '$_base/${product['id']}',
      );
      if (mounted) {
        await _load();
      }
    } catch (e) {
      _handle(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> product) async {
    setState(() => _busy = true);
    try {
      await widget.api.request('PATCH', '$_base/${product['id']}', {
        'version': product['version'],
        'active': product['active'] != true,
      });
      if (mounted) {
        await _load();
      }
    } catch (e) {
      _handle(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _newInvoice() async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InvoiceEditor(
        api: widget.api,
        tenantId: widget.tenantId,
        onExpired: widget.onExpired,
      ),
    );
    if (saved != null && mounted) {
      await _load();
      if (mounted) {
        await _openInvoice(saved['id'] as int);
      }
    }
  }

  Future<void> _openInvoice(int id) async {
    await showDialog<void>(
      context: context,
      builder: (_) => InvoiceDetails(
        api: widget.api,
        tenantId: widget.tenantId,
        invoiceId: id,
        onExpired: widget.onExpired,
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.products ? 'المنتجات' : 'الفواتير',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.products
                      ? 'المخزون بالحزم. الأسعار تُحدَّد في كل فاتورة.'
                      : 'أنشئ وراجع وأصدر فواتير المبيعات.',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : widget.products
                ? () => _product()
                : _newInvoice,
            icon: const Icon(Icons.add, size: 18),
            label: Text(widget.products ? 'إضافة منتج' : 'فاتورة جديدة'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: widget.products
                ? TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو الكود',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        _offset = 0;
                        _load();
                      });
                    },
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'حالة الفاتورة',
                    ),
                    items: [
                      for (final status in [
                        '',
                        'draft',
                        'posted',
                        'void',
                        'cancelled',
                      ])
                        DropdownMenuItem(
                          value: status,
                          child: Text(
                            status.isEmpty ? 'جميع الفواتير' : status,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            _status = value!;
                            _offset = 0;
                            _load();
                          },
                  ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Expanded(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _busy
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
              : _rows.isEmpty
              ? Center(
                  child: Text(
                    widget.products
                        ? 'لا توجد منتجات. أضف منتجاً للبدء.'
                        : 'لا توجد فواتير. أنشئ مسودة للبدء.',
                    style: const TextStyle(color: muted),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, size) => Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: size.maxWidth),
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 24,
                            horizontalMargin: 20,
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8FAF6),
                            ),
                            dataRowMinHeight: 64,
                            dataRowMaxHeight: 64,
                            columns: [
                              for (final title
                                  in widget.products
                                      ? [
                                          'المنتج',
                                          'الكود',
                                          'الحزم',
                                          'القطع / الحزمة',
                                          'الحالة',
                                          'الإجراءات',
                                        ]
                                      : [
                                          'الفاتورة',
                                          'العميل',
                                          'التاريخ',
                                          'الإجمالي',
                                          'الحالة',
                                          'الإجراءات',
                                        ])
                                DataColumn(label: Text(title)),
                            ],
                            rows: _rows
                                .map(
                                  (row) => DataRow(
                                    cells: widget.products
                                        ? [
                                            DataCell(
                                              SizedBox(
                                                width: 150,
                                                child: Text(
                                                  '${row['title']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text('${row['code']}')),
                                            DataCell(
                                              Text('${row['quantity']}'),
                                            ),
                                            DataCell(
                                              Text('${row['pieces_per_unit']}'),
                                            ),
                                            DataCell(
                                              Text(
                                                row['active'] == true
                                                    ? 'نشط'
                                                    : 'مؤرشف',
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip:
                                                        'تعديل ${row['title']}',
                                                    onPressed: () =>
                                                        _product(row),
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 19,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip:
                                                        row['active'] == true
                                                        ? 'أرشفة ${row['title']}'
                                                        : 'استعادة ${row['title']}',
                                                    onPressed: () =>
                                                        _toggle(row),
                                                    icon: Icon(
                                                      row['active'] == true
                                                          ? Icons
                                                                .archive_outlined
                                                          : Icons
                                                                .unarchive_outlined,
                                                      size: 19,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip:
                                                        'حذف ${row['title']}',
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
                                          ]
                                        : [
                                            DataCell(Text(invoiceLabel(row))),
                                            DataCell(
                                              SizedBox(
                                                width: 180,
                                                child: Text(
                                                  '${row['client_name']}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text('${row['issue_date']}'),
                                            ),
                                            DataCell(
                                              Text(
                                                egp(row['total_minor'] as int),
                                              ),
                                            ),
                                            DataCell(Text('${row['status']}')),
                                            DataCell(
                                              TextButton(
                                                onPressed: () => _openInvoice(
                                                  row['id'] as int,
                                                ),
                                                child: const Text(
                                                  'فتح الفاتورة',
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
              style: const TextStyle(color: muted),
            ),
          ),
          IconButton(
            tooltip: 'الصفحة السابقة',
            onPressed: _busy || _offset == 0
                ? null
                : () {
                    _offset -= 50;
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'الصفحة التالية',
            onPressed: _busy || _rows.length < 50
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

class ProductDialog extends StatefulWidget {
  const ProductDialog({
    super.key,
    required this.api,
    required this.tenantId,
    required this.onExpired,
    this.product,
  });
  final MuskyApi api;
  final int tenantId;
  final VoidCallback onExpired;
  final Map<String, dynamic>? product;
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.product?['title'] as String? ?? '',
  );
  late final _code = TextEditingController(
    text: widget.product?['code'] as String? ?? '',
  );
  late final _quantity = TextEditingController(
    text: '${widget.product?['quantity'] ?? 0}',
  );
  late final _pieces = TextEditingController(
    text: '${widget.product?['pieces_per_unit'] ?? 1}',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _code, _quantity, _pieces]) {
      c.dispose();
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
      final id = widget.product?['id'];
      await widget.api.request(
        id == null ? 'POST' : 'PATCH',
        'tenants/${widget.tenantId}/products${id == null ? '' : '/$id'}',
        {
          'title': _title.text.trim(),
          'code': _code.text.trim(),
          'quantity': int.parse(_quantity.text),
          'pieces_per_unit': int.parse(_pieces.text),
          if (id != null) 'version': widget.product!['version'],
        },
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.status == 401) {
          Navigator.pop(context);
          widget.onExpired();
        } else {
          setState(() => _error = e.message);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر حفظ المنتج. حاول مجدداً.');
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
      title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل منتج'),
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
                TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  autofocus: true,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    counterText: '',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'أدخل الاسم.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'كود المنتج',
                    counterText: '',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'أدخل الكود.' : null,
                ),
                const SizedBox(height: 16),
                for (final entry in [
                  (_quantity, 'الكمية (حزم)', 0, 1000000000),
                  (_pieces, 'القطع في الحزمة', 1, 1000000),
                ]) ...[
                  TextFormField(
                    controller: entry.$1,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < entry.$3 || n > entry.$4
                          ? 'أدخل رقماً صحيحاً من ${entry.$3} إلى ${entry.$4}.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'تغيير الكمية يُسجّل حركة مخزون.',
                  style: TextStyle(color: muted, fontSize: 12),
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
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ المنتج'),
        ),
      ],
    ),
  );
}
