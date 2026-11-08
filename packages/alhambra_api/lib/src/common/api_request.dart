/// Base class or mixin for API mutation requests supporting idempotency.
abstract class ApiRequest {
  final String? idempotencyKey;

  const ApiRequest({this.idempotencyKey});
}
