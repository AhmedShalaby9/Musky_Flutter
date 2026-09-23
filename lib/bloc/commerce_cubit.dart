import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class CommerceState {
  const CommerceState({
    required this.products,
    this.loading = false,
    this.error,
    this.rows = const [],
    this.offset = 0,
    this.searchQuery = '',
    this.statusFilter = '',
    this.documentTypeFilter = '',
    this.fromDate = '',
    this.toDate = '',
    this.expired = false,
  });

  final bool products;
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final int offset;
  final String searchQuery;
  final String statusFilter;
  // Nullable while hot reload transitions an existing state instance created
  // before this filter was introduced. New states always initialize it to ''.
  final String? documentTypeFilter;
  final String fromDate;
  final String toDate;
  final bool expired;

  CommerceState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    List<Map<String, dynamic>>? rows,
    int? offset,
    String? searchQuery,
    String? statusFilter,
    String? documentTypeFilter,
    String? fromDate,
    String? toDate,
    bool? expired,
  }) => CommerceState(
    products: products,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    rows: rows ?? this.rows,
    offset: offset ?? this.offset,
    searchQuery: searchQuery ?? this.searchQuery,
    statusFilter: statusFilter ?? this.statusFilter,
    documentTypeFilter: documentTypeFilter ?? this.documentTypeFilter ?? '',
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    expired: expired ?? this.expired,
  );
}

class CommerceCubit extends Cubit<CommerceState> {
  CommerceCubit(this._api, this._tenantId, {required bool products})
    : super(CommerceState(products: products));

  final MuskyApi _api;
  final int _tenantId;
  int _requestId = 0;
  ApiRequestCancellation? _active;

  String get _base =>
      'tenants/$_tenantId/${state.products ? 'products' : 'invoices'}';

  void refresh() => _fetch(
    offset: state.offset,
    q: state.searchQuery,
    status: state.statusFilter,
    documentType: state.documentTypeFilter ?? '',
    from: state.fromDate,
    to: state.toDate,
  );

  void search(String q) => _fetch(
    offset: 0,
    q: q,
    status: state.statusFilter,
    documentType: state.documentTypeFilter ?? '',
    from: state.fromDate,
    to: state.toDate,
  );

  void filterStatus(String status) => _fetch(
    offset: 0,
    q: state.searchQuery,
    status: status,
    documentType: state.documentTypeFilter ?? '',
    from: state.fromDate,
    to: state.toDate,
  );

  void filterDocumentType(String documentType) => _fetch(
    offset: 0,
    q: state.searchQuery,
    status: state.statusFilter,
    documentType: documentType,
    from: state.fromDate,
    to: state.toDate,
  );

  void filterDates({required String from, required String to}) => _fetch(
    offset: 0,
    q: state.searchQuery,
    status: state.statusFilter,
    documentType: state.documentTypeFilter ?? '',
    from: from,
    to: to,
  );

  void nextPage() => _fetch(
    offset: state.offset + 50,
    q: state.searchQuery,
    status: state.statusFilter,
    documentType: state.documentTypeFilter ?? '',
    from: state.fromDate,
    to: state.toDate,
  );

  void prevPage() {
    if (state.offset == 0) return;
    _fetch(
      offset: state.offset - 50,
      q: state.searchQuery,
      status: state.statusFilter,
      documentType: state.documentTypeFilter ?? '',
      from: state.fromDate,
      to: state.toDate,
    );
  }

  Future<void> _fetch({
    required int offset,
    required String q,
    required String status,
    required String documentType,
    required String from,
    required String to,
  }) async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;
    final id = ++_requestId;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final query = Uri(
        queryParameters: {
          'limit': '50',
          'offset': '$offset',
          if (q.isNotEmpty) 'q': q,
          if (!state.products && status.isNotEmpty) 'status': status,
          if (!state.products && documentType.isNotEmpty)
            'document_type': documentType,
          if (!state.products && from.isNotEmpty) 'from': from,
          if (!state.products && to.isNotEmpty) 'to': to,
        },
      ).query;
      final response = await _api.requestWithCancellation(
        'GET',
        '$_base?$query',
        cancellation: cancel,
      );
      if (_requestId == id && !isClosed) {
        emit(
          state.copyWith(
            loading: false,
            rows: (response['data'] as List).cast<Map<String, dynamic>>(),
            offset: offset,
            searchQuery: q,
            statusFilter: status,
            documentTypeFilter: documentType,
            fromDate: from,
            toDate: to,
          ),
        );
      }
    } on ApiException catch (e) {
      if (_requestId == id && !isClosed) {
        if (e.status == 401) {
          emit(state.copyWith(loading: false, expired: true));
        } else {
          emit(state.copyWith(loading: false, error: e.message));
        }
      }
    } on ApiRequestCancelled {
      // cancelled — ignore
    } catch (_) {
      if (_requestId == id && !isClosed) {
        emit(
          state.copyWith(
            loading: false,
            error: 'تعذّر إتمام العملية. حاول مجدداً.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _active?.cancel();
    return super.close();
  }
}
