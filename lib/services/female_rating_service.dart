import '../models/animal.dart';
import '../models/female_rating.dart';
import '../models/health_event.dart';
import '../models/reproduction_event.dart';
import '../models/weight_measurement.dart';

class FemaleRatingService {
  FemaleRatingService._();

  static FemaleRating compute({
    required Animal female,
    required DateTime endDate,
    required List<ReproductionEvent> events,
    required List<Animal> offspring,
    required Map<String, List<WeightMeasurement>> weightsByOffspring,
    required List<Animal> speciesPeers,
    required Map<String, List<ReproductionEvent>> peersEvents,
    required List<HealthEvent> healthEvents,
  }) {
    final productiviteResult = _computeProductivite(female, events, endDate);
    final porteeResult = _computePortee(events, speciesPeers, peersEvents);
    final survieResult = _computeSurvie(events, offspring);
    final croissanceResult = _computeCroissance(offspring, weightsByOffspring);
    final santeResult = _computeSante(female, events, healthEvents, endDate);

    final scores = [
      productiviteResult.$1,
      porteeResult.$1,
      survieResult.$1,
      croissanceResult.$1,
      santeResult.$1,
    ].whereType<double>().toList();

    final composite = scores.isEmpty
        ? null
        : (scores.reduce((a, b) => a + b) / scores.length * 2).round() / 2.0;

    return FemaleRating(
      productiviteScore: productiviteResult.$1,
      porteeScore: porteeResult.$1,
      survieScore: survieResult.$1,
      croissanceScore: croissanceResult.$1,
      santeScore: santeResult.$1,
      composite: composite,
      birthsPerYear: productiviteResult.$2,
      avgLitterSize: porteeResult.$2,
      survivalRate: survieResult.$2,
      avgWeaningGainPercent: croissanceResult.$2,
      illnessesPerYear: santeResult.$2,
    );
  }

  // Returns (score, birthsPerYear)
  static (double?, double?) _computeProductivite(
      Animal female, List<ReproductionEvent> events, DateTime endDate) {
    final birthEvents =
        events.where((e) => e.eventType == ReproductionEventType.birth).toList();
    if (birthEvents.isEmpty) return (null, null);

    final matings =
        events.where((e) => e.eventType == ReproductionEventType.mating).toList();
    DateTime? startDate;
    if (matings.isNotEmpty) {
      startDate = matings
          .map((e) => DateTime.parse(e.eventDate))
          .reduce((a, b) => a.isBefore(b) ? a : b);
    } else if (female.birthDate != null) {
      startDate = DateTime.tryParse(female.birthDate!);
    }
    if (startDate == null) return (null, null);

    final years = endDate.difference(startDate).inDays / 365.25;
    if (years <= 0) return (null, null);

    final birthsPerYear = birthEvents.length / years;
    double score;
    if (birthsPerYear >= 1.75) score = 5;
    else if (birthsPerYear >= 1.25) score = 4;
    else if (birthsPerYear >= 0.9) score = 3;
    else if (birthsPerYear >= 0.5) score = 2;
    else score = 1;

    return (score, birthsPerYear);
  }

  // Returns (score, avgLitterSize). Score is null if fewer than 2 peers have birth data.
  static (double?, double?) _computePortee(
      List<ReproductionEvent> events,
      List<Animal> speciesPeers,
      Map<String, List<ReproductionEvent>> peersEvents) {
    double? avgFor(List<ReproductionEvent> evts) {
      final births = evts
          .where((e) =>
              e.eventType == ReproductionEventType.birth &&
              e.offspringCount != null)
          .toList();
      if (births.isEmpty) return null;
      return births.map((e) => e.offspringCount!).reduce((a, b) => a + b) /
          births.length;
    }

    final myAvg = avgFor(events);
    if (myAvg == null) return (null, null);

    final peerAvgs = speciesPeers
        .map((p) => avgFor(peersEvents[p.id] ?? []))
        .whereType<double>()
        .toList();

    // Need at least 2 females with birth data to rank
    if (peerAvgs.length < 2) return (null, myAvg);

    final belowCount = peerAvgs.where((p) => p < myAvg).length;
    final percentile = belowCount / peerAvgs.length;

    double score;
    if (percentile >= 0.8) score = 5;
    else if (percentile >= 0.6) score = 4;
    else if (percentile >= 0.4) score = 3;
    else if (percentile >= 0.2) score = 2;
    else score = 1;

    return (score, myAvg);
  }

  // Returns (score, survivalRate 0.0–1.0)
  static (double?, double?) _computeSurvie(
      List<ReproductionEvent> events, List<Animal> offspring) {
    final birthEvents =
        events.where((e) => e.eventType == ReproductionEventType.birth).toList();
    if (birthEvents.isEmpty) return (null, null);

    final totalBorn =
        birthEvents.map((e) => e.offspringCount ?? 0).reduce((a, b) => a + b);
    if (totalBorn == 0) return (null, null);

    final survived =
        offspring.where((o) => o.status != AnimalStatus.dead).length;
    final rate = survived / totalBorn;

    double score;
    if (rate >= 0.95) score = 5;
    else if (rate >= 0.80) score = 4;
    else if (rate >= 0.65) score = 3;
    else if (rate >= 0.50) score = 2;
    else score = 1;

    return (score, rate);
  }

  // Returns (score, avgGainPercent)
  static (double?, double?) _computeCroissance(
      List<Animal> offspring,
      Map<String, List<WeightMeasurement>> weightsByOffspring) {
    final gains = <double>[];
    for (final o in offspring) {
      final weights = List<WeightMeasurement>.from(
          weightsByOffspring[o.id] ?? [])
        ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
      if (weights.length < 2) continue;
      final first = weights.first.weight;
      if (first <= 0) continue;
      gains.add((weights.last.weight - first) / first * 100);
    }
    if (gains.isEmpty) return (null, null);

    final avgGain = gains.reduce((a, b) => a + b) / gains.length;

    double score;
    if (avgGain >= 200) score = 5;
    else if (avgGain >= 150) score = 4;
    else if (avgGain >= 100) score = 3;
    else if (avgGain >= 50) score = 2;
    else score = 1;

    return (score, avgGain);
  }

  // Returns (score, illnessesPerYear)
  static (double?, double?) _computeSante(
      Animal female,
      List<ReproductionEvent> events,
      List<HealthEvent> healthEvents,
      DateTime endDate) {
    final hasAnyData =
        healthEvents.isNotEmpty || events.isNotEmpty || female.birthDate != null;
    if (!hasAnyData) return (null, null);

    final illnesses = healthEvents
        .where((e) => e.eventType == HealthEventType.illness)
        .toList();
    if (illnesses.isEmpty) return (5.0, 0.0);

    final dates = [
      ...events
          .map((e) => DateTime.tryParse(e.eventDate))
          .whereType<DateTime>(),
      ...healthEvents
          .map((e) => DateTime.tryParse(e.date))
          .whereType<DateTime>(),
      if (female.birthDate != null) DateTime.tryParse(female.birthDate!),
    ].whereType<DateTime>().toList()
      ..sort();

    if (dates.isEmpty) return (null, null);
    final years = endDate.difference(dates.first).inDays / 365.25;
    if (years <= 0) return (5.0, 0.0);

    final illnessesPerYear = illnesses.length / years;

    double score;
    if (illnessesPerYear > 2) score = 1;
    else if (illnessesPerYear > 1) score = 2;
    else if (illnessesPerYear > 0.5) score = 3;
    else score = 4;

    return (score, illnessesPerYear);
  }
}
