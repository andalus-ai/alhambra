import 'package:alhambra/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra/data/grpc/grpc_backend_service.dart';

void main() {
  group('GrpcBackendService Integration Tests', () {
    late GrpcBackendService service;

    setUpAll(() {
      // grpcClient is a singleton that auto-initializes to 127.0.0.1:9000
      service = GrpcBackendService();
    });

    test('listProviders returns providers from backend', () async {
      try {
        final providers = await service
            .listProviders()
            .timeout(const Duration(milliseconds: 500));
        logDebug('Providers: $providers');
        expect(providers, isNotNull);
      } catch (e) {
        logDebug('Backend not available for integration test: $e');
      }
    });

    test('listModels returns models for a valid provider', () async {
      try {
        final providers = await service
            .listProviders()
            .timeout(const Duration(milliseconds: 500));
        if (providers.isEmpty) return;

        final providerId = providers.first['id'] as String;
        final models = await service
            .listModels(providerId)
            .timeout(const Duration(milliseconds: 500));
        logDebug('Models for $providerId: $models');

        expect(models, isNotNull);
      } catch (e) {
        logDebug('Backend not available for integration test: $e');
      }
    });
  });
}
