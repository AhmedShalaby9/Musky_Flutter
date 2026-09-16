import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/money.dart';
import '../core/theme.dart';

class ProductBuyersScreen extends StatefulWidget {
  const ProductBuyersScreen({
    super.key,
    required this.api,
    required this.tenantId,
    required this.product,
    required this.onExpired,
  });

  final MuskyApi api;
  final int tenantId;
  final Map<String, dynamic> product;
  final VoidCallback onExpired;

  @override
  State<ProductBuyersScreen> createState() => _ProductBuyersScreenState();
}

class _ProductBuyersScreenState extends State<ProductBuyersScreen> {
  final _loadCancellation = ApiRequestCancellation();
  final _horizontal = ScrollController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  int get _productId => widget.product['id'] as int;
  String get _productTitle => '${widget.product['title'] ?? ''}';

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
      final data = await widget.api.requestWithCancellation(
        'GET',
        'tenants/${widget.tenantId}/products/$_productId/buyers?limit=50&offset=0',
        cancellation: _loadCancellation,
      );
      if (!mounted) return;
      setState(() {
        _rows = ((data['data'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        widget.onExpired();
      } else {
        setState(() => _error = e.message);
      }
    } on ApiRequestCancelled {
      // The user left the screen before the request completed.
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذّر تحميل مشتري الصنف. حاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _invoiceNumber(dynamic value) =>
      value == null ? 'بدون رقم' : value.toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      backgroundColor: paper,
      elevation: 0,
      leading: const BackButton(color: ink),
      title: Text('حركة الصنف', style: Theme.of(context).textTheme.titleLarge),
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
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _productTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'العملاء الذين اشتروا هذا الصنف في أذونات صادرة مؤكدة.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
              : _rows.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد مبيعات مؤكدة لهذا الصنف حتى الآن.',
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
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('العميل')),
                          DataColumn(label: Text('العنوان')),
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('النوع')),
                          DataColumn(label: Text('رقم الإذن')),
                          DataColumn(
                            label: Text('عدد الكراتين'),
                            numeric: true,
                          ),
                          DataColumn(label: Text('العبوة'), numeric: true),
                          DataColumn(label: Text('سعر الوحدة'), numeric: true),
                          DataColumn(label: Text('الإجمالي'), numeric: true),
                        ],
                        rows: _rows.map((row) {
                          final total = (row['total_minor'] as num).toInt();
                          final price = (row['unit_price_minor'] as num)
                              .toInt();
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    '${row['client_name']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    '${row['client_address'] ?? ''}'.isEmpty
                                        ? '—'
                                        : '${row['client_address']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(_date('${row['issue_date']}'))),
                              DataCell(
                                Text(invoiceTypeLabel(row['document_type'])),
                              ),
                              DataCell(
                                Text(_invoiceNumber(row['invoice_number'])),
                              ),
                              DataCell(Text('${row['package_count']}')),
                              DataCell(Text('${row['units_per_package']}')),
                              DataCell(Text(egp(price))),
                              DataCell(
                                Text(
                                  egp(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
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
