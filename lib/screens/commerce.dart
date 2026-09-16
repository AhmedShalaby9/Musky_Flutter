import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/commerce_cubit.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';
import 'invoice_editor.dart';
import 'product_buyers.dart';

class CommerceScreen extends StatefulWidget {
  const CommerceScreen({
    super.key,
    required this.cubit,
    required this.api,
    required this.tenantId,
    required this.products,
    required this.onExpired,
  });
  final CommerceCubit cubit;
  final MuskyApi api;
  final int tenantId;
  final bool products;
  final VoidCallback onExpired;
  @override
  State<CommerceScreen> createState() => _CommerceScreenState();
}

class _CommerceScreenState extends State<CommerceScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  String get _base =>
      'tenants/${widget.tenantId}/${widget.products ? 'products' : 'invoices'}';

  @override
  void initState() {
    super.initState();
    widget.cubit.loadIfNeeded();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
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
      widget.cubit.refresh();
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
    try {
      await widget.api.request('DELETE', '$_base/${product['id']}');
      if (mounted) widget.cubit.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) widget.onExpired();
    } catch (_) {}
  }

  Future<void> _toggle(Map<String, dynamic> product) async {
    try {
      await widget.api.request('PATCH', '$_base/${product['id']}', {
        'version': product['version'],
        'active': product['active'] != true,
      });
      if (mounted) widget.cubit.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) widget.onExpired();
    } catch (_) {}
  }

  void _openProductBuyers(Map<String, dynamic> product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductBuyersScreen(
          api: widget.api,
          tenantId: widget.tenantId,
          product: product,
          onExpired: widget.onExpired,
        ),
      ),
    );
  }

  Future<void> _newInvoice() async {
    await _newTransaction('sale');
  }

  Future<void> _newTransaction(String documentType) async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InvoiceEditor(
        api: widget.api,
        tenantId: widget.tenantId,
        onExpired: widget.onExpired,
        documentType: documentType,
      ),
    );
    if (saved != null && mounted) {
      widget.cubit.refresh();
      if (mounted) await _openInvoice(saved['id'] as int);
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
    if (mounted) widget.cubit.refresh();
  }

  Widget _invoiceField(String label, String value, {bool emphasis = false}) =>
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
              color: emphasis ? teal : ink,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );

  Widget _invoiceSummary(String label, int amount, Color color) => Container(
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
          egp(amount),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );

  Widget _productSummary(String label, int value, Color color) => Container(
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
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _invoiceRows(List<Map<String, dynamic>> rows) => ListView.separated(
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final row = rows[index];
      final purchase = row['document_type'] == 'purchase';
      final type = purchase ? 'شراء' : 'بيع';
      final typeColor = purchase ? const Color(0xFF536D8A) : teal;
      final status = invoiceStatusLabel('${row['status']}');
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openInvoice(row['id'] as int),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, size) {
              final fields = [
                _invoiceField('الفاتورة', invoiceLabel(row)),
                _invoiceField('العميل', '${row['client_name']}'),
                _invoiceField('التاريخ', '${row['issue_date']}'),
                _invoiceField(
                  'الإجمالي',
                  egp(row['total_minor'] as int),
                  emphasis: true,
                ),
                _invoiceField('الحالة', status),
              ];
              final typeChip = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
              if (size.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    typeChip,
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: fields
                          .map((field) => SizedBox(width: 150, child: field))
                          .toList(),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  typeChip,
                  const SizedBox(width: 18),
                  for (final field in fields) Expanded(child: field),
                  IconButton(
                    tooltip: 'فتح الفاتورة',
                    onPressed: () => _openInvoice(row['id'] as int),
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  Widget _productRows(List<Map<String, dynamic>> rows) => ListView.separated(
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final row = rows[index];
      final active = row['active'] == true;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, size) {
            final fields = [
              _invoiceField('المنتج', '${row['title']}'),
              _invoiceField('الكود', '${row['code']}'),
              _invoiceField(
                'المخزون',
                '${row['quantity']} حزمة',
                emphasis: true,
              ),
              _invoiceField('القطع / الحزمة', '${row['pieces_per_unit']}'),
            ];
            final status = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (active ? teal : muted).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                active ? 'نشط' : 'مؤرشف',
                style: TextStyle(
                  color: active ? teal : muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
            final actions = Wrap(
              spacing: 2,
              children: [
                TextButton.icon(
                  onPressed: () => _product(row),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل'),
                ),
                TextButton.icon(
                  onPressed: () => _openProductBuyers(row),
                  icon: const Icon(Icons.history_outlined, size: 18),
                  label: const Text('حركة الصنف'),
                ),
                TextButton.icon(
                  onPressed: () => _toggle(row),
                  icon: Icon(
                    active ? Icons.archive_outlined : Icons.unarchive_outlined,
                    size: 18,
                  ),
                  label: Text(active ? 'أرشفة' : 'استعادة'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(row),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text('حذف', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
            if (size.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  status,
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: fields
                        .map((field) => SizedBox(width: 150, child: field))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                status,
                const SizedBox(width: 18),
                for (final field in fields) Expanded(child: field),
                actions,
              ],
            );
          },
        ),
      );
    },
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CommerceCubit, CommerceState>(
    bloc: widget.cubit,
    listener: (context, state) {
      if (state.expired) widget.onExpired();
    },
    builder: (context, state) {
      final rows = state.rows;
      final busy = state.loading;
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
                      widget.products ? 'المنتجات' : 'الفواتير',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.products
                          ? 'المخزون بالحزم. الأسعار تُحدَّد في كل فاتورة.'
                          : 'أنشئ فواتير البيع والشراء وسجّل حركة المخزون والحسابات.',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!widget.products)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _newTransaction('purchase'),
                  icon: const Icon(Icons.shopping_cart, size: 18),
                  label: const Text('شراء من عميل'),
                ),
              if (!widget.products) const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: busy
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
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () => widget.cubit.search(_search.text.trim()),
                          );
                        },
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: state.documentTypeFilter ?? '',
                              decoration: const InputDecoration(
                                labelText: 'نوع الفاتورة',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('بيع وشراء'),
                                ),
                                DropdownMenuItem(
                                  value: 'sale',
                                  child: Text('بيع فقط'),
                                ),
                                DropdownMenuItem(
                                  value: 'purchase',
                                  child: Text('شراء فقط'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) =>
                                        widget.cubit.filterDocumentType(value!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: state.statusFilter,
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
                                      status.isEmpty
                                          ? 'كل الحالات'
                                          : invoiceStatusLabel(status),
                                    ),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) =>
                                        widget.cubit.filterStatus(value!),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'تحديث',
                onPressed: busy ? null : widget.cubit.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!widget.products) ...[
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _invoiceSummary(
                  'مبيعات هذه الصفحة',
                  rows
                      .where((row) => row['document_type'] != 'purchase')
                      .fold<int>(
                        0,
                        (total, row) => total + (row['total_minor'] as int),
                      ),
                  teal,
                ),
                _invoiceSummary(
                  'مشتريات هذه الصفحة',
                  rows
                      .where((row) => row['document_type'] == 'purchase')
                      .fold<int>(
                        0,
                        (total, row) => total + (row['total_minor'] as int),
                      ),
                  const Color(0xFF536D8A),
                ),
                _invoiceSummary(
                  'إجمالي هذه الصفحة',
                  rows.fold<int>(
                    0,
                    (total, row) => total + (row['total_minor'] as int),
                  ),
                  ink,
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (widget.products) ...[
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _productSummary(
                  'إجمالي الحزم',
                  rows.fold<int>(
                    0,
                    (total, row) => total + (row['quantity'] as int),
                  ),
                  teal,
                ),
                _productSummary(
                  'منتجات نشطة',
                  rows.where((row) => row['active'] == true).length,
                  const Color(0xFF527A54),
                ),
                _productSummary(
                  'منتجات مؤرشفة',
                  rows.where((row) => row['active'] != true).length,
                  muted,
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ErrorNotice(state.error!),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: widget.cubit.refresh,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : rows.isEmpty
                  ? Center(
                      child: Text(
                        widget.products
                            ? 'لا توجد منتجات. أضف منتجاً للبدء.'
                            : 'لا توجد فواتير. أنشئ مسودة للبدء.',
                        style: const TextStyle(color: muted),
                      ),
                    )
                  : !widget.products
                  ? _invoiceRows(rows)
                  : LayoutBuilder(
                      builder: (context, size) {
                        if (rows.isNotEmpty) return _productRows(rows);
                        return Scrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: size.maxWidth,
                              ),
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
                                                'النوع',
                                                'العميل',
                                                'التاريخ',
                                                'الإجمالي',
                                                'الحالة',
                                                'الإجراءات',
                                              ])
                                      DataColumn(label: Text(title)),
                                  ],
                                  rows: rows
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
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text('${row['code']}'),
                                                  ),
                                                  DataCell(
                                                    Text('${row['quantity']}'),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      '${row['pieces_per_unit']}',
                                                    ),
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
                                                      mainAxisSize:
                                                          MainAxisSize.min,
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
                                                        TextButton.icon(
                                                          onPressed: () =>
                                                              _openProductBuyers(
                                                                row,
                                                              ),
                                                          icon: const Icon(
                                                            Icons
                                                                .groups_outlined,
                                                            size: 18,
                                                          ),
                                                          label: const Text(
                                                            'شوف مين اشترى الصنف ده من هنا',
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip:
                                                              row['active'] ==
                                                                  true
                                                              ? 'أرشفة ${row['title']}'
                                                              : 'استعادة ${row['title']}',
                                                          onPressed: () =>
                                                              _toggle(row),
                                                          icon: Icon(
                                                            row['active'] ==
                                                                    true
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
                                                            Icons
                                                                .delete_outline,
                                                            size: 19,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ]
                                              : [
                                                  DataCell(
                                                    Text(invoiceLabel(row)),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      invoiceTypeLabel(
                                                        row['document_type'],
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    SizedBox(
                                                      width: 180,
                                                      child: Text(
                                                        '${row['client_name']}',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      '${row['issue_date']}',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      egp(
                                                        row['total_minor']
                                                            as int,
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      invoiceStatusLabel(
                                                        '${row['status']}',
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    TextButton(
                                                      onPressed: () =>
                                                          _openInvoice(
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
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'صفحة ${state.offset ~/ 50 + 1} · ${rows.length} سجل',
                  style: const TextStyle(color: muted),
                ),
              ),
              IconButton(
                tooltip: 'الصفحة السابقة',
                onPressed: busy || state.offset == 0
                    ? null
                    : widget.cubit.prevPage,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'الصفحة التالية',
                onPressed: busy || rows.length < 50
                    ? null
                    : widget.cubit.nextPage,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
    },
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
