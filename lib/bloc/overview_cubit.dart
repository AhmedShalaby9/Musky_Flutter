import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class OverviewState {
  const OverviewState({
    this.loading = false,
    this.error,
    this.summary,
    this.initialized = false,
    this.expired = false,
    this.overdueLoading = false,
    this.overdueError,
    this.overdueClients = const [],
    this.overdueDays = 7,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? summary;
  final bool initialized;
  final bool expired;

  final bool overdueLoading;
  final String? overdueError;
  final List<Map<String, dynamic>> overdueClients;
  final int overdueDays;

  OverviewState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    Map<String, dynamic>? summary,
    bool? initialized,
    bool? expired,
    bool? overdueLoading,
    bool clearOverdueError = false,
    String? overdueError,
    List<Map<String, dynamic>>? overdueClients,
    int? overdueDays,
  }) =>
      OverviewState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        summary: summary ?? this.summary,
        initialized: initialized ?? this.initialized,
        expired: expired ?? this.expired,
        overdueLoading: overdueLoading ?? this.overdueLoading,
        overdueError: clearOverdueError ? null : (overdueError ?? this.overdueError),
        overdueClients: overdueClients ?? this.overdueClients,
        overdueDays: overdueDays ?? this.overdueDays,
      );
}

class OverviewCubit extends Cubit<OverviewState> {
  OverviewCubit(this._api, this._tenantId) : super(const OverviewState());

  final MuskyApi _api;
  final int _tenantId;
  ApiRequestCancellation? _active;
  ApiRequestCancellation? _overdueActive;

  void loadIfNeeded() {
    if (!state.initialized && !state.loading) {
      _fetch();
      _fetchOverdue(state.overdueDays);
    }
  }

  void refresh() {
    _fetch();
    _fetchOverdue(state.overdueDays);
  }

  void setOverdueDays(int days) => _fetchOverdue(days);

  Future<void> _fetch() async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final summary = await _api.requestWithCancellation(
        'GET',
        'tenants/$_tenantId/financial-summary',
        cancellation: cancel,
      );
      if (!isClosed) {
        emit(state.copyWith(loading: false, summary: summary, initialized: true));
      }
    } on ApiException catch (e) {
      if (!isClosed) {
        if (e.status == 401) {
          emit(state.copyWith(loading: false, expired: true));
        } else {
          emit(state.copyWith(loading: false, error: e.message));
        }
      }
    } on ApiRequestCancelled {
      // cancelled — ignore
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: 'تعذّر تحميل الأرصدة. حاول مجدداً.'));
      }
    }
  }

  Future<void> _fetchOverdue(int days) async {
    _overdueActive?.cancel();
    final cancel = ApiRequestCancellation();
    _overdueActive = cancel;

    emit(state.copyWith(overdueLoading: true, clearOverdueError: true, overdueDays: days));
    try {
      final rows = await _api.list(
        'tenants/$_tenantId/clients',
        offset: 0,
        daysWithoutPayment: days,
        cancellation: cancel,
      );
      if (!isClosed) {
        emit(state.copyWith(overdueLoading: false, overdueClients: rows));
      }
    } on ApiException catch (e) {
      if (!isClosed) {
        if (e.status == 401) {
          emit(state.copyWith(overdueLoading: false, expired: true));
        } else {
          emit(state.copyWith(overdueLoading: false, overdueError: e.message));
        }
      }
    } on ApiRequestCancelled {
      // cancelled — ignore
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(overdueLoading: false, overdueError: 'تعذّر تحميل العملاء.'));
      }
    }
  }

  @override
  Future<void> close() {
    _active?.cancel();
    _overdueActive?.cancel();
    return super.close();
  }
}
