import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';
import '../ids/id_generator.dart';
import 'dio_factory.dart';
import 'generated/money_tracker_api.dart';
import 'interceptors/client_info_interceptor.dart';
import 'interceptors/problem_interceptor.dart';

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
Dio dio(Ref ref) {
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
MoneyTrackerApi apiClient(Ref ref) => MoneyTrackerApi(ref.watch(dioProvider));
