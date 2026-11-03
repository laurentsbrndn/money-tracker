import 'package:dio/dio.dart';

import '../api_exception.dart';

/// Reports `426 upgrade_required` (API.md §1.1) so the app can show the
/// "Perbarui aplikasi" screen. The error itself still propagates.
class UpgradeRequiredInterceptor extends Interceptor {
  UpgradeRequiredInterceptor(this._onUpgradeRequired);

  final void Function() _onUpgradeRequired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final problem = err.error;
    if (problem is ApiException && problem.code == 'upgrade_required') {
      _onUpgradeRequired();
    }
    handler.next(err);
  }
}
