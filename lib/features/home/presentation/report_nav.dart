import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot request from the home stats to open a list on a status.
class ReportListRequest {
  const ReportListRequest({required this.token, this.status});

  /// Increments on every tap so the same status can be applied again.
  final int token;

  /// `null` opens the list with every status.
  final int? status;
}

class ReportNavState {
  const ReportNavState({this.lma, this.dsr});

  final ReportListRequest? lma;
  final ReportListRequest? dsr;
}

class ReportNavController extends StateNotifier<ReportNavState> {
  ReportNavController() : super(const ReportNavState());

  int _token = 0;

  void openLma(int? status) {
    _token += 1;
    state = ReportNavState(
      lma: ReportListRequest(token: _token, status: status),
      dsr: state.dsr,
    );
  }

  void openDsr(int? status) {
    _token += 1;
    state = ReportNavState(
      lma: state.lma,
      dsr: ReportListRequest(token: _token, status: status),
    );
  }
}

final reportNavProvider =
    StateNotifierProvider<ReportNavController, ReportNavState>((ref) {
  return ReportNavController();
});
