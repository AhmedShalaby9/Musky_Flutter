import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class ChinaState {
  ChinaState({
    this.loading = false,
    this.error,
    this.entries = const [],
    this.balanceMinor = 0,
    this.expired = false,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> entries;
  final int balanceMinor;
  final bool expired;

  bool get hasOpening => entries.any((e) => e['kind'] == 'opening');

  ChinaState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    List<Map<String, dynamic>>? entries,
    int? balanceMinor,
    bool? expired,
  }) => ChinaState(
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    entries: entries ?? this.entries,
    balanceMinor: balanceMinor ?? this.balanceMinor,
    expired: expired ?? this.expired,
  );
}

class ChinaCubit extends Cubit<ChinaState> {
  ChinaCubit(this._api, this._tenantId) : super(ChinaState());

  final MuskyApi _api;
  final int _tenantId;
  ApiRequestCancellation? _active;

  void refresh() => _fetch();

  Future<void> _fetch() async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await _api.requestWithCancellation(
        'GET',
        'tenants/$_tenantId/china',
        cancellation: cancel,
      );
      if (!isClosed) {
        final entries = (result['entries'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        emit(state.copyWith(
          loading: false,
          entries: entries,
          balanceMinor: (result['balance_minor'] as num?)?.toInt() ?? 0,
        ));
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
      // cancelled
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: 'تعذر تحميل رصيد الصين.'));
      }
    }
  }

  Future<bool> addEntry(String kind, int amountMinor, String notes) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await _api.request('POST', 'tenants/$_tenantId/china', {
        'kind': kind,
        'amount_minor': amountMinor,
        'notes': notes,
      });
      if (!isClosed) {
        await _fetch();
      }
      return true;
    } on ApiException catch (e) {
      if (!isClosed) {
        if (e.status == 401) {
          emit(state.copyWith(loading: false, expired: true));
        } else {
          emit(state.copyWith(loading: false, error: e.message));
        }
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: 'تعذر إضافة الحركة.'));
      }
      return false;
    }
  }

  Future<bool> deleteEntry(int entryId) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _api.request('DELETE', 'tenants/$_tenantId/china/$entryId');
      if (!isClosed) {
        await _fetch();
      }
      return true;
    } on ApiException catch (e) {
      if (!isClosed) {
        if (e.status == 401) {
          emit(state.copyWith(loading: false, expired: true));
        } else {
          emit(state.copyWith(loading: false, error: e.message));
        }
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: 'تعذر حذف الحركة.'));
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    _active?.cancel();
    return super.close();
  }
}
