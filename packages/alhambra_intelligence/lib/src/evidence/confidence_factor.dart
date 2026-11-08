/// An inspectable factor contributing to overall confidence calculation.
final class ConfidenceFactor {
  final String name;
  final double contribution;
  final String? explanation;

  const ConfidenceFactor({
    required this.name,
    required this.contribution,
    this.explanation,
  });

  @override
  String toString() => 'ConfidenceFactor($name: $contribution)';
}
