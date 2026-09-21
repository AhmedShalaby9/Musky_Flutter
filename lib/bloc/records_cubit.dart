import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class RecordsState {
  const RecordsState({
    this.loading = false,
    this.error,
    this.rows = const [],
    this.offset = 0,
    this.searchQuery = '',
    this.daysFilter,
    this.initialized = false,
    this.expired = false,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final int offset;
  final String searchQuery;
  final int? daysFilter;
  final bool initialized;
  final bool expired;

  static const _keep = Object();

  RecordsState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    List<Map<String, dynamic>>? rows,
    int? offset,
    String? searchQuery,
    Object? daysFilter = _keep,
    bool? initialized,
    bool? expired,
  }) => RecordsState(
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    rows: rows ?? this.rows,
    offset: offset ?? this.offset,
    searchQuery: searchQuery ?? this.searchQuery,
    daysFilter: identical(daysFilter, _keep)
        ? this.daysFilter
        : daysFilter as int?,
    initialized: initialized ?? this.initialized,
    expired: expired ?? this.expired,
  );
}

class RecordsCubit extends Cubit<RecordsState> {
  RecordsCubit(this._api, this._section, this._tenantId)
    : super(const RecordsState());

  final MuskyApi _api;
  final String _section;
  final int? _tenantId;
  int _requestId = 0;
  ApiRequestCancellation? _active;

  bool get _isClients => _section == 'العملاء' || _section == 'الموردين';
  bool get _isBusinesses => _section == 'الأعمال';
  String? get _balanceFilter => _section == 'الموردين' ? 'payable' : null;

  String get _path => _isBusinesses
      ? 'tenants'
      : 'tenants/$_tenantId/${_isClients ? 'clients' : 'users'}';

  void loadIfNeeded() {
    if (!state.initialized && !state.loading) {
      _fetch(offset: 0, q: '', daysFilter: null);
    }
  }

  void refresh() => _fetch(
    offset: state.offset,
    q: state.searchQuery,
    daysFilter: state.daysFilter,
  );

  void search(String q) =>
      _fetch(offset: 0, q: q, daysFilter: state.daysFilter);

  void filterDays(int? days) =>
      _fetch(offset: 0, q: state.searchQuery, daysFilter: days);

  void nextPage() => _fetch(
    offset: state.offset + 50,
    q: state.searchQuery,
    daysFilter: state.daysFilter,
  );

  void prevPage() {
    if (state.offset == 0) return;
    _fetch(
      offset: state.offset - 50,
      q: state.searchQuery,
      daysFilter: state.daysFilter,
    );
  }

  Future<void> _fetch({
    required int offset,
    required String q,
    required int? daysFilter,
  }) async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;
    final id = ++_requestId;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final rows = await _api.list(
        _path,
        offset: offset,
        q: _isClients ? q : '',
        daysWithoutPayment: _isClients ? daysFilter : null,
        balance: _isClients ? _balanceFilter : null,
        cancellation: cancel,
      );
      if (_requestId == id && !isClosed) {
        emit(
          state.copyWith(
            loading: false,
            rows: rows,
            offset: offset,
            searchQuery: q,
            daysFilter: daysFilter,
            initialized: true,
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
            error: 'تعذّر تحميل السجلات. حاول مجدداً.',
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
