import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class OverviewState {
  const OverviewState({
    this.loading = false,
    this.error,
    this.summary,
    this.initialized = false,
    this.expired = false,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? summary;
  final bool initialized;
  final bool expired;

  OverviewState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    Map<String, dynamic>? summary,
    bool? initialized,
    bool? expired,
  }) =>
      OverviewState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        summary: summary ?? this.summary,
        initialized: initialized ?? this.initialized,
        expired: expired ?? this.expired,
      );
}

class OverviewCubit extends Cubit<OverviewState> {
  OverviewCubit(this._api, this._tenantId) : super(const OverviewState());

  final MuskyApi _api;
  final int _tenantId;
  ApiRequestCancellation? _active;

  void loadIfNeeded() {
    if (!state.initialized && !state.loading) _fetch();
  }

  void refresh() => _fetch();

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

  @override
  Future<void> close() {
    _active?.cancel();
    return super.close();
  }
}
