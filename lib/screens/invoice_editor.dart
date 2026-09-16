import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';
import 'pdf_viewer.dart';

class RecordPicker extends StatefulWidget {
  const RecordPicker({
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
  State<RecordPicker> createState() => _RecordPickerState();
}

class _RecordPickerState extends State<RecordPicker> {
  final _loadCancellation = ApiRequestCancellation();
  final _search = TextEditingController();
  Timer? _timer;
  List<Map<String, dynamic>> _rows = [];
  bool _busy = true;
  String? _error;
  int _offset = 0, _ticket = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadCancellation.cancel();
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          'q': _search.text,
          'active': 'true',
          'limit': '50',
          'offset': '$_offset',
        },
      ).query;
      final data = await widget.api.requestWithCancellation(
        'GET',
        'tenants/${widget.tenantId}/${widget.products ? 'products' : 'clients'}?$query',
        cancellation: _loadCancellation,
      );
      if (mounted && ticket == _ticket) {
        setState(
          () => _rows = (data['data'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } on ApiException catch (e) {
      if (mounted && ticket == _ticket) {
        if (e.status == 401) {
          Navigator.pop(context);
          widget.onExpired();
        } else {
          setState(() => _error = e.message);
        }
      }
    } catch (_) {
      if (mounted && ticket == _ticket) {
        setState(() => _error = 'تعذّر تحميل السجلات.');
      }
    } finally {
      if (mounted && ticket == _ticket) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.products
                ? Icons.inventory_2_outlined
                : Icons.person_search_outlined,
            color: teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.products ? 'إضافة منتج للفاتورة' : 'اختيار العميل',
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 720,
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.products
                ? 'ابحث عن الصنف ثم أضفه إلى بنود الفاتورة.'
                : 'اختر العميل الذي ستُسجّل الفاتورة باسمه.',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.products
                  ? 'بحث بالاسم أو الكود'
                  : 'بحث بالاسم أو الهاتف',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) {
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 300), () {
                _offset = 0;
                _load();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorNotice(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  )
                : _rows.isEmpty
                ? const Center(child: Text('لا توجد سجلات نشطة مطابقة.'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _rows.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      final title =
                          '${row[widget.products ? 'title' : 'name']}';
                      final secondary = widget.products
                          ? 'الكود: ${row['code']} · المتاح: ${row['quantity']} حزمة'
                          : '${row['phone'] ?? 'لا يوجد هاتف'}${'${row['address'] ?? ''}'.isEmpty ? '' : ' · ${row['address']}'}';
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context, row),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: teal.withValues(alpha: .10),
                                  foregroundColor: teal,
                                  child: Icon(
                                    widget.products
                                        ? Icons.inventory_2_outlined
                                        : Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        secondary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => Navigator.pop(context, row),
                                  icon: Icon(
                                    widget.products
                                        ? Icons.add_circle_outline
                                        : Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  label: Text(
                                    widget.products ? 'إضافة' : 'اختيار',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Page ${_offset ~/ 50 + 1}'),
              IconButton(
                tooltip: 'النتائج السابقة',
                onPressed: _busy || _offset == 0
                    ? null
                    : () {
                        _offset -= 50;
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'مزيد من النتائج',
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
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );
}

class _Line {
  _Line(this.productId, this.title, int units, int cartons, int minor)
    : unitsPerPackage = TextEditingController(text: '$units'),
      packageCount = TextEditingController(text: '$cartons'),
      price = TextEditingController(text: moneyInput(minor));
  final int productId;
  final String title;
  final TextEditingController unitsPerPackage, packageCount, price;
  int get total {
    final units = int.tryParse(unitsPerPackage.text) ?? 0;
    final cartons = int.tryParse(packageCount.text) ?? 0;
    final minor = parseMoney(price.text) ?? 0;
    if (units < 0 ||
        cartons < 0 ||
        units > 1000000000 ||
        cartons > 1000000000 ||
        (minor > 0 && units * cartons > 100000000000000 ~/ minor)) {
      return 100000000000001;
    }
    return units * cartons * minor;
  }

  void dispose() {
    unitsPerPackage.dispose();
    packageCount.dispose();
    price.dispose();
  }
}

class InvoiceEditor extends StatefulWidget {
  const InvoiceEditor({
    super.key,
    required this.api,
    required this.tenantId,
    required this.onExpired,
    this.invoice,
    this.documentType = 'sale',
  });
  final MuskyApi api;
  final int tenantId;
  final VoidCallback onExpired;
  final Map<String, dynamic>? invoice;
  final String documentType;
  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  final _form = GlobalKey<FormState>();
  late final _date = TextEditingController(
    text:
        widget.invoice?['issue_date'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10),
  );
  late final _notes = TextEditingController(
    text: widget.invoice?['notes'] as String? ?? '',
  );
  final List<_Line> _lines = [];
  int? _clientId;
  String? _clientName, _error;
  bool _busy = false;
  String get _type =>
      widget.invoice?['document_type'] as String? ?? widget.documentType;
  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    if (invoice != null) {
      _clientId = invoice['client_id'] as int;
      _clientName = invoice['client_name'] as String;
      for (final item in invoice['items'] as List) {
        _lines.add(
          _Line(
            item['product_id'] as int,
            item['title'] as String,
            item['units_per_package'] as int? ?? item['pieces_per_unit'] as int,
            item['package_count'] as int? ?? item['quantity'] as int,
            item['unit_price_minor'] as int,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool product) async {
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RecordPicker(
        api: widget.api,
        tenantId: widget.tenantId,
        products: product,
        onExpired: () {
          if (mounted) {
            Navigator.pop(context);
          }
          widget.onExpired();
        },
      ),
    );
    if (row == null || !mounted) {
      return;
    }
    setState(() {
      if (!product) {
        _clientId = row['id'] as int;
        _clientName = row['name'] as String;
      } else {
        final matches = _lines.where((l) => l.productId == row['id']);
        if (matches.isNotEmpty) {
          final line = matches.first;
          line.packageCount.text =
              '${(int.tryParse(line.packageCount.text) ?? 0) + 1}';
        } else if (_lines.length < 100) {
          _lines.add(
            _Line(
              row['id'] as int,
              row['title'] as String,
              row['pieces_per_unit'] as int,
              1,
              0,
            ),
          );
        } else {
          _error = 'يمكن أن تحتوي الفاتورة على 100 منتج كحد أقصى.';
        }
      }
    });
  }

  Future<void> _pickIssueDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ الفاتورة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    if (_clientId == null || _lines.isEmpty) {
      setState(() => _error = 'اختر عميلاً وأضف منتجاً واحداً على الأقل.');
      return;
    }
    final total = _lines.fold<int>(0, (sum, line) => sum + line.total);
    if (total > 100000000000000) {
      setState(() => _error = 'إجمالي الفاتورة يتجاوز الحد المسموح به.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = widget.invoice?['id'];
      final result = await widget.api.request(
        id == null ? 'POST' : 'PUT',
        'tenants/${widget.tenantId}/invoices${id == null ? '' : '/$id'}',
        {
          'document_type': _type,
          'client_id': _clientId,
          'issue_date': _date.text,
          'notes': _notes.text.trim(),
          if (id != null) 'version': widget.invoice!['version'],
          'items': [
            for (final line in _lines)
              {
                'product_id': line.productId,
                'units_per_package': int.parse(line.unitsPerPackage.text),
                'package_count': int.parse(line.packageCount.text),
                'unit_price_minor': parseMoney(line.price.text)!,
              },
          ],
        },
      );
      if (mounted) {
        Navigator.pop(context, result);
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
        setState(() => _error = 'تعذّر حفظ المسودة. حاول مجدداً.');
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
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (_type == 'purchase' ? const Color(0xFF536D8A) : teal)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _type == 'purchase'
                  ? Icons.shopping_cart_outlined
                  : Icons.receipt_long_outlined,
              color: _type == 'purchase' ? const Color(0xFF536D8A) : teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.invoice == null
                  ? (_type == 'purchase'
                        ? 'فاتورة شراء جديدة'
                        : 'فاتورة بيع جديدة')
                  : 'تعديل مسودة ${invoiceTypeLabel(_type)}',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 920,
        height: MediaQuery.sizeOf(context).height * .65,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        (_type == 'purchase' ? const Color(0xFF536D8A) : teal)
                            .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _type == 'purchase'
                        ? 'أضف المنتجات التي تم شراؤها. عند إصدار الفاتورة ستزداد الكمية في المخزون.'
                        : 'أضف المنتجات المراد بيعها. عند إصدار الفاتورة ستُخصم الكمية من المخزون.',
                    style: const TextStyle(color: ink),
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  ErrorNotice(_error!),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pick(false),
                      icon: const Icon(Icons.person_outline),
                      label: Text(_clientName ?? 'اختر عميلاً'),
                    ),
                    SizedBox(
                      width: 210,
                      child: TextFormField(
                        controller: _date,
                        enabled: !_busy,
                        readOnly: true,
                        onTap: _busy ? null : _pickIssueDate,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الفاتورة',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (value) {
                          final date = DateTime.tryParse(value ?? '');
                          return date == null ||
                                  !RegExp(
                                    r'^\d{4}-\d{2}-\d{2}$',
                                  ).hasMatch(value!) ||
                                  date.toIso8601String().substring(0, 10) !=
                                      value ||
                                  date.year < 1000
                              ? 'أدخل تاريخاً صحيحاً.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_lines.isNotEmpty) ...[
                  Text(
                    'بنود الفاتورة (${_lines.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                ],
                for (final line in _lines)
                  Padding(
                    key: ValueKey(line),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE1E7E0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${line.title}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'الكمية والسعر',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'إزالة ${line.title}',
                                onPressed: _busy
                                    ? null
                                    : () {
                                        setState(() => _lines.remove(line));
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                              (_) => line.dispose(),
                                            );
                                      },
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 145,
                                child: TextFormField(
                                  controller: line.unitsPerPackage,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'العبوة (قطعة/كرتونة)',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final qty = int.tryParse(v ?? '');
                                    return qty == null ||
                                            qty < 1 ||
                                            qty > 1000000000
                                        ? 'أدخل قيمة من 1 إلى 1,000,000,000.'
                                        : null;
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 145,
                                child: TextFormField(
                                  controller: line.packageCount,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'العدد (كرتونة)',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final count = int.tryParse(v ?? '');
                                    return count == null ||
                                            count < 1 ||
                                            count > 1000000000
                                        ? 'أدخل عدد الكراتين.'
                                        : null;
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: TextFormField(
                                  controller: line.price,
                                  enabled: !_busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'سعر الوحدة / القطعة (ج.م)',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => parseMoney(v ?? '') == null
                                      ? 'أدخل حتى خانتين عشريتين.'
                                      : null,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFE5),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  egp(line.total),
                                  style: const TextStyle(
                                    color: teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(true),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  maxLines: 2,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'إجمالي المسودة',
                          style: TextStyle(color: Color(0xFFB6C9C1)),
                        ),
                      ),
                      Text(
                        egp(
                          _lines.fold<int>(0, (sum, line) => sum + line.total),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
          child: const Text('إغلاق'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ المسودة'),
        ),
      ],
    ),
  );
}

class InvoiceDetails extends StatefulWidget {
  const InvoiceDetails({
    super.key,
    required this.api,
    required this.tenantId,
    required this.invoiceId,
    required this.onExpired,
  });
  final MuskyApi api;
  final int tenantId, invoiceId;
  final VoidCallback onExpired;
  @override
  State<InvoiceDetails> createState() => _InvoiceDetailsState();
}

class _InvoiceDetailsState extends State<InvoiceDetails> {
  final _loadCancellation = ApiRequestCancellation();
  Map<String, dynamic>? _invoice;
  bool _busy = true;
  String? _error;
  String get _path => 'tenants/${widget.tenantId}/invoices/${widget.invoiceId}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _handle(Object error) {
    if (!mounted) {
      return;
    }
    if (error is ApiException && error.status == 401) {
      Navigator.pop(context);
      widget.onExpired();
    } else {
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Unable to complete the request. Please refresh.',
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.requestWithCancellation(
        'GET',
        _path,
        cancellation: _loadCancellation,
      );
      if (mounted) {
        setState(() => _invoice = data);
      }
    } catch (e) {
      _handle(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _loadCancellation.cancel();
    super.dispose();
  }

  Future<void> _transition(String action) async {
    String? reason;
    if (action == 'void') {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const VoidReasonDialog(),
      );
      if (reason == null || !mounted) {
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            action == 'post'
                ? (_invoice!['document_type'] == 'purchase'
                      ? 'إصدار فاتورة الشراء؟'
                      : 'إصدار فاتورة البيع؟')
                : action == 'reactivate'
                ? 'Reactivate this invoice?'
                : 'Cancel this draft?',
          ),
          content: Text(
            action == 'post'
                ? (_invoice!['document_type'] == 'purchase'
                      ? 'سيضيف هذا الحزم إلى المخزون ويسجل ${egp(_invoice!['total_minor'] as int)} مستحقة إلى ${_invoice!['client_name']}. لا يمكن تعديل الفاتورة بعد إصدارها.'
                      : 'سيخصم هذا الحزم من المخزون ويسجل ${egp(_invoice!['total_minor'] as int)} مستحقة على ${_invoice!['client_name']}. لا يمكن تعديل الفاتورة بعد إصدارها.')
                : action == 'reactivate'
                ? 'This restores the invoice to active status and applies its stock and balance calculations again.'
                : 'This keeps the draft as cancelled. Stock and balances will not change.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                action == 'post'
                    ? 'Confirm posting'
                    : action == 'reactivate'
                    ? 'Confirm reactivation'
                    : 'Confirm cancellation',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.request(
        action == 'cancel' ? 'DELETE' : 'POST',
        action == 'cancel'
            ? '$_path?version=${_invoice!['version']}'
            : '$_path/${action == 'reactivate' ? 'reactivate' : action}',
        action == 'cancel'
            ? null
            : {'version': _invoice!['version'], 'reason': ?reason},
      );
      if (mounted) {
        setState(() => _invoice = data);
      }
    } catch (e) {
      _handle(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _edit() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InvoiceEditor(
        api: widget.api,
        tenantId: widget.tenantId,
        invoice: _invoice,
        onExpired: () {
          if (mounted) {
            Navigator.pop(context);
          }
          widget.onExpired();
        },
      ),
    );
    if (data != null && mounted) {
      setState(() => _invoice = data);
    }
  }

  Future<void> _payment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PaymentDialog(
        remainingMinor:
            (_invoice!['remaining_minor'] as int?) ??
            (_invoice!['total_minor'] as int),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.recordPayment(
        widget.tenantId,
        widget.invoiceId,
        result['amount_minor'] as int,
        result['method'] as String,
        result['notes'] as String,
      );
      await _load();
    } catch (e) {
      _handle(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generatePdf() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request('POST', '$_path/pdf');
      await _load();
    } catch (e) {
      _handle(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPdf() async {
    final url = '${_invoice?['pdf_url']}';
    if (url.isEmpty) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfScreen(
          api: widget.api,
          url: url,
          title: invoiceLabel(_invoice!),
        ),
      ),
    );
  }

  Widget _detailField(String label, String value) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Row(
        children: [
          if (_invoice != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    (_invoice!['document_type'] == 'purchase'
                            ? const Color(0xFF536D8A)
                            : teal)
                        .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _invoice!['document_type'] == 'purchase'
                    ? Icons.shopping_cart_outlined
                    : Icons.receipt_long_outlined,
                color: _invoice!['document_type'] == 'purchase'
                    ? const Color(0xFF536D8A)
                    : teal,
              ),
            ),
          if (_invoice != null) const SizedBox(width: 12),
          Expanded(
            child: Text(
              _invoice == null ? 'الفاتورة' : invoiceLabel(_invoice!),
            ),
          ),
          IconButton(
            tooltip: 'تحديث الفاتورة',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 850,
        height: MediaQuery.sizeOf(context).height * .62,
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      ErrorNotice(_error!),
                      const SizedBox(height: 16),
                    ],
                    if (_invoice != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: paper,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 28,
                          runSpacing: 12,
                          children: [
                            _detailField(
                              'العميل',
                              '${_invoice!['client_name']}',
                            ),
                            _detailField(
                              'التاريخ',
                              '${_invoice!['issue_date']}',
                            ),
                            _detailField(
                              'النوع',
                              invoiceTypeLabel(_invoice!['document_type']),
                            ),
                            _detailField(
                              'الحالة',
                              invoiceStatusLabel('${_invoice!['status']}'),
                            ),
                            if ('${_invoice!['client_address']}'.isNotEmpty)
                              _detailField(
                                'العنوان',
                                '${_invoice!['client_address']}',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('بيان')),
                              DataColumn(label: Text('العدد')),
                              DataColumn(label: Text('العبوة')),
                              DataColumn(label: Text('سعر الوحدة')),
                              DataColumn(label: Text('الإجمالي')),
                            ],
                            rows: [
                              for (final item in _invoice!['items'] as List)
                                DataRow(
                                  cells: [
                                    DataCell(Text('${item['title']}')),
                                    DataCell(
                                      Text(
                                        '${item['package_count'] ?? item['quantity']}',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${item['units_per_package'] ?? item['pieces_per_unit']}',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        egp(item['unit_price_minor'] as int),
                                      ),
                                    ),
                                    DataCell(
                                      Text(egp(item['total_minor'] as int)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'إجمالي الفاتورة',
                                style: TextStyle(color: Color(0xFFB6C9C1)),
                              ),
                            ),
                            Text(
                              egp(_invoice!['total_minor'] as int),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_invoice!['status'] == 'posted') ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_invoice!['document_type'] == 'purchase' ? 'المدفوع للمورد' : 'المدفوع'}: ${egp((_invoice!['paid_minor'] as int?) ?? 0)}',
                        ),
                        Text(
                          'المتبقي: ${egp((_invoice!['remaining_minor'] as int?) ?? (_invoice!['total_minor'] as int))}',
                        ),
                      ],
                      if ('${_invoice!['notes']}'.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('ملاحظات: ${_invoice!['notes']}'),
                      ],
                      if (_invoice!['status'] == 'void') ...[
                        const SizedBox(height: 20),
                        Text('سبب الإلغاء: ${_invoice!['void_reason']}'),
                      ],
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (_invoice != null && '${_invoice!['pdf_url']}'.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _busy ? null : _openPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('عرض PDF'),
          ),
        OutlinedButton.icon(
          onPressed: _busy || _invoice == null ? null : _generatePdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _invoice != null && '${_invoice!['pdf_url']}'.isNotEmpty
                ? 'تحديث PDF'
                : 'إنشاء PDF',
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        if (_invoice?['status'] == 'draft') ...[
          TextButton(
            onPressed: _busy ? null : () => _transition('cancel'),
            child: const Text('إلغاء المسودة'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _edit,
            child: const Text('تعديل المسودة'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _transition('post'),
            child: const Text('إصدار الفاتورة'),
          ),
        ],
        if (_invoice?['status'] == 'posted' &&
            ((_invoice?['remaining_minor'] as int?) ?? 0) > 0)
          FilledButton(
            onPressed: _busy ? null : _payment,
            child: const Text('تسجيل دفعة'),
          ),
        if (_invoice?['status'] == 'void' || _invoice?['status'] == 'cancelled')
          OutlinedButton(
            onPressed: _busy ? null : () => _transition('reactivate'),
            child: const Text('إعادة تفعيل الفاتورة'),
          ),
        if (_invoice?['status'] == 'posted')
          OutlinedButton(
            onPressed: _busy ? null : () => _transition('void'),
            child: const Text('إلغاء الفاتورة'),
          ),
      ],
    ),
  );
}

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key, required this.remainingMinor});
  final int remainingMinor;
  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'cash';
  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تسجيل دفعة'),
    content: Form(
      key: _form,
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المتبقي: ${egp(widget.remainingMinor)}'),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'المبلغ بالجنيه'),
              validator: (v) {
                final n = v == null ? null : parseMoney(v);
                if (n == null || n < 1 || n > widget.remainingMinor)
                  return 'أدخل مبلغاً صحيحاً ضمن المتبقي.';
                return null;
              },
            ),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                DropdownMenuItem(value: 'online', child: Text('إلكتروني')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
            TextFormField(
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
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
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate())
            Navigator.pop(context, {
              'amount_minor': parseMoney(_amount.text)!,
              'method': _method,
              'notes': _notes.text.trim(),
            });
        },
        child: const Text('حفظ الدفعة'),
      ),
    ],
  );
}

class VoidReasonDialog extends StatefulWidget {
  const VoidReasonDialog({super.key});
  @override
  State<VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends State<VoidReasonDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إلغاء الفاتورة'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إلغاء الفاتورة يُعيد الحزم إلى المخزون ويلغي دين العميل. لا يمكن التراجع.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _reason,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'السبب'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل السبب.' : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('رجوع'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('تأكيد الإلغاء'),
      ),
    ],
  );
}
