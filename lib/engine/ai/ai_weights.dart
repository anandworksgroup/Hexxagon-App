/// Relative importance of each factor in the board evaluation.
///
/// The defaults follow the product spec (territory 30%, capture 25%,
/// mobility 15%, future capture 15%, position 10%, strategy 5%). Every
/// difficulty reads its weights from here rather than hard-coding them in
/// the search, so tuning is a one-line change.
class AiWeights {
  const AiWeights({
    this.territory = 30,
    this.capture = 25,
    this.mobility = 15,
    this.futureCapture = 15,
    this.position = 10,
    this.strategy = 5,
  });

  final double territory;
  final double capture;
  final double mobility;
  final double futureCapture;
  final double position;
  final double strategy;

  static const standard = AiWeights();

  /// Expert leans harder on safety and threats; its deeper search already
  /// sees most immediate captures.
  static const expert = AiWeights(
    territory: 30,
    capture: 20,
    mobility: 12,
    futureCapture: 20,
    position: 13,
    strategy: 5,
  );
}
