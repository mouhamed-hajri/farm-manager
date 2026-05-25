class FemaleRating {
  const FemaleRating({
    this.productiviteScore,
    this.porteeScore,
    this.survieScore,
    this.croissanceScore,
    this.santeScore,
    this.composite,
    this.birthsPerYear,
    this.avgLitterSize,
    this.survivalRate,
    this.avgWeaningGainPercent,
    this.illnessesPerYear,
  });

  final double? productiviteScore;
  final double? porteeScore;
  final double? survieScore;
  final double? croissanceScore;
  final double? santeScore;
  final double? composite; // average of non-null scores, rounded to nearest 0.5

  // Raw values for display hints
  final double? birthsPerYear;
  final double? avgLitterSize;
  final double? survivalRate;        // 0.0–1.0
  final double? avgWeaningGainPercent;
  final double? illnessesPerYear;
}
