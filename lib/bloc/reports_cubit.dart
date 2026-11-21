import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api.dart';

class ReportsState {
  ReportsState({
    this.loading = false,
    this.error,
    this.data = const {},
    this.expired = false,
    this.from,
    this.to,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic> data;
  final bool expired;
  final DateTime? from;
  final DateTime? to;

  ReportsState copyWith({
    bool? loading,
    bool clearError = false,
    String? error,
    Map<String, dynamic>? data,
    bool? expired,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) => ReportsState(
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    data: data ?? this.data,
    expired: expired ?? this.expired,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
  );
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._api, this._tenantId) : super(ReportsState());

  final MuskyApi _api;
  final int _tenantId;
  ApiRequestCancellation? _active;

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void refresh() => _fetch();

  void setFrom(DateTime? date) {
    emit(state.copyWith(from: date, clearFrom: date == null));
    _fetch();
  }

  void setTo(DateTime? date) {
    emit(state.copyWith(to: date, clearTo: date == null));
    _fetch();
  }

  Future<void> _fetch() async {
    _active?.cancel();
    final cancel = ApiRequestCancellation();
    _active = cancel;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      var url = 'tenants/$_tenantId/reports';
      final params = <String>[];
      if (state.from != null) params.add('from=${_fmt(state.from!)}');
      if (state.to != null) params.add('to=${_fmt(state.to!)}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final result = await _api.requestWithCancellation(
        'GET', url, cancellation: cancel,
      );
      if (!isClosed) {
        emit(state.copyWith(loading: false, data: result));
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
        emit(state.copyWith(loading: false, error: 'تعذر تحميل التقارير.'));
      }
    }
  }

  @override
  Future<void> close() {
    _active?.cancel();
    return super.close();
  }
}
