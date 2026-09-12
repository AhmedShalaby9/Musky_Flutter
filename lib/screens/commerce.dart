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
            : 'The operation could not be completed. Please retry.',
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
                  widget.products ? 'Products' : 'Invoices',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.products
                      ? 'Stock in packs. Prices in EGP per pack.'
                      : 'Draft, review and post your sales invoices.',
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
            label: Text(widget.products ? 'Add product' : 'New invoice'),
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
                      hintText: 'Search products by title or code',
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
                      labelText: 'Invoice status',
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
                          child: Text(status.isEmpty ? 'All invoices' : status),
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
            tooltip: 'Refresh',
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
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _rows.isEmpty
              ? Center(
                  child: Text(
                    widget.products
                        ? 'No products found. Add a product to get started.'
                        : 'No invoices found. Create a draft to get started.',
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
                                          'Product',
                                          'Code',
                                          'Packs',
                                          'Pieces / pack',
                                          'Price / pack',
                                          'Status',
                                          'Actions',
                                        ]
                                      : [
                                          'Invoice',
                                          'Client',
                                          'Date',
                                          'Total',
                                          'Status',
                                          'Actions',
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
                                                egp(
                                                  row['unit_price_minor']
                                                      as int,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                row['active'] == true
                                                    ? 'Active'
                                                    : 'Archived',
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip:
                                                        'Edit ${row['title']}',
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
                                                        ? 'Archive ${row['title']}'
                                                        : 'Restore ${row['title']}',
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
                                                  'Open invoice',
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
              'Page ${_offset ~/ 50 + 1} · ${_rows.length} records',
              style: const TextStyle(color: muted),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: _busy || _offset == 0
                ? null
                : () {
                    _offset -= 50;
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
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
  late final _price = TextEditingController(
    text: moneyInput(widget.product?['unit_price_minor'] as int? ?? 0),
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _code, _quantity, _pieces, _price]) {
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
          'unit_price_minor': parseMoney(_price.text)!,
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
        setState(() => _error = 'Unable to save the product. Try again.');
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
      title: Text(widget.product == null ? 'Add product' : 'Edit product'),
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
                    labelText: 'Product title',
                    counterText: '',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a title.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Product code',
                    counterText: '',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a code.' : null,
                ),
                const SizedBox(height: 16),
                for (final entry in [
                  (_quantity, 'Stock quantity (packs)', 0, 1000000000),
                  (_pieces, 'Pieces per pack', 1, 1000000),
                ]) ...[
                  TextFormField(
                    controller: entry.$1,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < entry.$3 || n > entry.$4
                          ? 'Enter a whole number from ${entry.$3} to ${entry.$4}.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _price,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price per pack (EGP)',
                  ),
                  validator: (v) => parseMoney(v ?? '') == null
                      ? 'Enter a valid price with up to 2 decimal places.'
                      : null,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Changing stock quantity records a stock adjustment.',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save product'),
        ),
      ],
    ),
  );
}
