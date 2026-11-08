/// Epistemic classification describes the ontological source and certainty type of a claim
/// to prevent inferences, forecasts, or simulated figures from being mistaken for official statistics.
enum EpistemicClass {
  official,
  reported,
  estimated,
  observed,
  inferred,
  predicted,
  simulated,
  reviewed;

  /// Returns true if this data represents an empirical or official claim rather than an AI forecast.
  bool get isGrounded =>
      this == EpistemicClass.official ||
      this == EpistemicClass.reported ||
      this == EpistemicClass.observed;

  /// Returns true if this data was generated through AI inference, simulation, or forward prediction.
  bool get isSyntheticOrProjected =>
      this == EpistemicClass.inferred ||
      this == EpistemicClass.predicted ||
      this == EpistemicClass.simulated;
}
