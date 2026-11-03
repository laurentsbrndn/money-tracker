import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/auth_tokens.dart';
import '../auth/session_controller.dart';
import '../auth/token_refresher.dart';
import '../auth/token_storage.dart';
import '../config/app_config.dart';
import '../database/app_database_provider.dart';
import '../ids/id_generator.dart';
import 'dio_factory.dart';
import 'generated/clients/auth_api.dart';
import 'generated/models/refresh_request.dart';
import 'generated/money_tracker_api.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/client_info_interceptor.dart';
import 'interceptors/problem_interceptor.dart';
import 'interceptors/upgrade_required_interceptor.dart';

part 'api_client_provider.g.dart';

const String _deviceIdKey = 'device_id';

@Riverpod(keepAlive: true)
Future<ClientInfo> clientInfo(Ref ref) async {
  final syncState = ref.watch(appDatabaseProvider).syncStateDao;
  var deviceId = await syncState.read(_deviceIdKey);
  if (deviceId == null) {
    deviceId = const IdGenerator().newId();
    await syncState.write(_deviceIdKey, deviceId);
  }
  final package = await PackageInfo.fromPlatform();
  return ClientInfo(deviceId: deviceId, appVersion: package.version);
}

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => TokenStorage();

/// Set when the server answers `426 upgrade_required` (API.md §1.1).
@Riverpod(keepAlive: true)
class UpgradeRequired extends _$UpgradeRequired {
  @override
  bool build() => false;

  void flag() => state = true;
}

/// Client without the auth interceptor, used only to refresh tokens (a
/// refresh must never trigger another refresh).
@Riverpod(keepAlive: true)
Dio bareDio(Ref ref) {
  return createDio(
    apiBaseUrl: AppConfig.apiBaseUrl,
    interceptors: [
      ClientInfoInterceptor(
        loadClientInfo: () => ref.read(clientInfoProvider.future),
        newRequestId: const IdGenerator().newId,
      ),
      ProblemInterceptor(),
    ],
  );
}

@Riverpod(keepAlive: true)
TokenRefresher tokenRefresher(Ref ref) {
  return TokenRefresher(
    storage: ref.watch(tokenStorageProvider),
    requestRefresh: (refreshToken) async {
      final response = await AuthApi(ref.read(bareDioProvider))
          .refreshTokens(body: RefreshRequest(refreshToken: refreshToken));
      final tokens = response.tokens;
      return AuthTokens(
        accessToken: tokens.accessToken,
        accessExpiresAt: tokens.accessExpiresAt,
        refreshToken: tokens.refreshToken,
        refreshExpiresAt: tokens.refreshExpiresAt,
      );
    },
    onSessionExpired: () =>
        ref.read(sessionControllerProvider.notifier).markNeedsLogin(),
  );
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  late final Dio client;
  client = createDio(
    apiBaseUrl: AppConfig.apiBaseUrl,
    interceptors: [
      ClientInfoInterceptor(
        loadClientInfo: () => ref.read(clientInfoProvider.future),
        newRequestId: const IdGenerator().newId,
      ),
      ProblemInterceptor(),
      UpgradeRequiredInterceptor(
        () => ref.read(upgradeRequiredProvider.notifier).flag(),
      ),
      AuthInterceptor(
        refresher: ref.read(tokenRefresherProvider),
        dio: () => client,
      ),
    ],
  );
  return client;
}

@Riverpod(keepAlive: true)
MoneyTrackerApi apiClient(Ref ref) => MoneyTrackerApi(ref.watch(dioProvider));
