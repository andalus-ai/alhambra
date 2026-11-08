/// alhambra_network_dio
///
/// Dio implementation of the [NetworkClient] contract from `alhambra_network`.
///
/// Register in your app bootstrap:
/// ```dart
/// registry.register<NetworkClient>(DioNetworkClient(NetworkClientConfig(
///   baseUri: Uri.parse('https://api.example.com'),
/// )));
/// ```
///
/// For tests, inject a mock adapter:
/// ```dart
/// final client = DioNetworkClient(config);
/// client.dio.httpClientAdapter = _MockAdapter();
/// ```
library alhambra_network_dio;

export 'src/dio_network_client.dart';
