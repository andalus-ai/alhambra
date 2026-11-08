import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_sdk/alhambra_sdk.dart';

void main() {
  test('AlhambraSdk version metadata is valid', () {
    expect(AlhambraSdk.version, isNotEmpty);
  });
}
