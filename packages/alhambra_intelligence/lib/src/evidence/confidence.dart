import 'confidence_factor.dart';

/// Represents calibrated, inspectable confidence in an assertion, prediction, or evidence item.
final class Confidence {
  final double value;
  final List<ConfidenceFactor> factors;

  const Confidence({
    required this.value,
    this.factors = const [],
  }) : assert(value >= 0.0 && value <= 1.0, 'Confidence value must be between 0.0 and 1.0');

  bool get isHigh => value >= 0.8;
  bool get isModerate => value >= 0.5 && value < 0.8;
  bool get isLow => value < 0.5;

  @override
  String toString() => 'Confidence(${(value * 100).toStringAsFixed(1)}%)';
}
