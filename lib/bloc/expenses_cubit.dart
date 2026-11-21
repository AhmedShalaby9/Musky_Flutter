import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class ExpensesState {
  ExpensesState({
    this.loading = false,
    this.error,
    this.entries = const [],
    this.totalMinor = 0,
    this.expired = false,
    this.from,
    this.to,
    this.offset = 0,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> entries;
  final int totalMinor;
  final bool expired;
  final DateTime? from;
  final DateTime? to;
  final int offset;

  ExpensesState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    List<Map<String, dynamic>>? entries,
    int? totalMinor,
    bool? expired,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    int? offset,
  }) => ExpensesState(
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    entries: entries ?? this.entries,
    totalMinor: totalMinor ?? this.totalMinor,
    expired: expired ?? this.expired,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    offset: offset ?? this.offset,
  );
}

class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit(this._api, this._tenantId) : super(ExpensesState());

  final MuskyApi _api;
  final int _tenantId;
  ApiRequestCancellation? _active;

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void refresh() => _fetch();

  void setFrom(DateTime? date) {
    emit(state.copyWith(from: date, clearFrom: date == null, offset: 0));
    _fetch();
  }

  void setTo(DateTime? date) {
    emit(state.copyWith(to: date, clearTo: date == null, offset: 0));
    _fetch();
  }

  void setPage(int offset) {
    emit(state.copyWith(offset: offset));
    _fetch();
  }

  Future<void> _fetch() async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      var url = 'tenants/$_tenantId/expenses?limit=50&offset=${state.offset}';
      if (state.from != null) url += '&from=${_fmt(state.from!)}';
      if (state.to != null) url += '&to=${_fmt(state.to!)}';

      final result = await _api.requestWithCancellation(
        'GET', url, cancellation: cancel,
      );
      if (!isClosed) {
        final entries = (result['data'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        emit(state.copyWith(
          loading: false,
          entries: entries,
          totalMinor: (result['total_minor'] as num?)?.toInt() ?? 0,
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
        emit(state.copyWith(loading: false, error: 'تعذر تحميل المصروفات.'));
      }
    }
  }

  Future<bool> addExpense(int amountMinor, String description, String spentAt) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _api.request('POST', 'tenants/$_tenantId/expenses', {
        'amount_minor': amountMinor,
        'description': description,
        'spent_at': spentAt,
      });
      if (!isClosed) await _fetch();
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
        emit(state.copyWith(loading: false, error: 'تعذر إضافة المصروف.'));
      }
      return false;
    }
  }

  Future<bool> deleteExpense(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _api.request('DELETE', 'tenants/$_tenantId/expenses/$id');
      if (!isClosed) await _fetch();
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
        emit(state.copyWith(loading: false, error: 'تعذر حذف المصروف.'));
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
