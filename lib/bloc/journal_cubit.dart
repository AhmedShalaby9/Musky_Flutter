import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class JournalState {
  JournalState({
    required this.date,
    this.loading = false,
    this.error,
    this.data = const {},
    this.initialized = false,
    this.expired = false,
  });

  final DateTime date;
  final bool loading;
  final String? error;
  final Map<String, dynamic> data;
  final bool initialized;
  final bool expired;

  JournalState copyWith({
    DateTime? date,
    bool? loading,
    bool clearError = false,
    String? error,
    Map<String, dynamic>? data,
    bool? initialized,
    bool? expired,
  }) => JournalState(
    date: date ?? this.date,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    data: data ?? this.data,
    initialized: initialized ?? this.initialized,
    expired: expired ?? this.expired,
  );
}

class JournalCubit extends Cubit<JournalState> {
  JournalCubit(this._api, this._tenantId)
    : super(JournalState(date: DateTime.now()));

  final MuskyApi _api;
  final int _tenantId;
  ApiRequestCancellation? _active;

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void loadIfNeeded() {
    if (!state.initialized && !state.loading) _fetch(state.date);
  }

  void refresh() => _fetch(state.date);

  void setDate(DateTime date) {
    emit(state.copyWith(date: date));
    _fetch(date);
  }

  Future<void> deleteReceipt({
    required int clientId,
    required int receiptId,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _api.deleteClientReceipt(_tenantId, clientId, receiptId);
      await _fetch(state.date);
    } on ApiException catch (e) {
      if (!isClosed) {
        if (e.status == 401) {
          emit(state.copyWith(loading: false, expired: true));
        } else {
          emit(state.copyWith(loading: false, error: e.message));
        }
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: 'تعذر حذف الدفعة.'));
      }
    }
  }

  Future<void> _fetch(DateTime date) async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await _api.requestWithCancellation(
        'GET',
        'tenants/$_tenantId/daily-journal?date=${_fmt(date)}',
        cancellation: cancel,
      );
      if (!isClosed) {
        emit(state.copyWith(loading: false, data: result, initialized: true));
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
        emit(state.copyWith(loading: false, error: 'تعذر تحميل دفتر اليومية.'));
      }
    }
  }

  @override
  Future<void> close() {
    _active?.cancel();
    return super.close();
  }
}
