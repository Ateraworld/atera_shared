import "dart:math";

import "package:atera_shared/atera_shared.dart";
import "package:omnimodel/omnimodel.dart";

void adjustRewards(OmniModel model) {
  var minTokens = 60;
  var minRank = 6;
  var scalingCoeff = 1;
  var roundingSeed = 2;
  var maxTokens = 300;
  var rankRatio = 7.5;
  int tokens = 0;
  int rank = 0;
  switch (model.tokenOrNull("category")) {
    case "0":
      var difficulty = model.tokenOr<num>("metrics.difficoltà", 1) / 100;
      var technique = model.tokenOr<num>("metrics.tecnica", 1) / 100;
      var exposition = model.tokenOr<num>("metrics.esposizione", 1) / 100;
      var physical = model.tokenOr<num>("metrics.impegno fisico", 1) / 100;

      num coeff = pow([difficulty, technique, exposition, physical].average(), scalingCoeff) * maxTokens;
      tokens = coeff.clamp(minTokens, double.infinity).roundSeed(roundingSeed).toInt();
      rank = (coeff / rankRatio).clamp(minRank, double.infinity).roundSeed(roundingSeed).toInt();
      break;
    case "1":
      var difficulty = model.tokenOr<num>("metrics.difficoltà", 1) / 100;
      var length = model.tokenOr<num>("metrics.lunghezza", 1) / 100;
      var physical = model.tokenOr<num>("metrics.impegno fisico", 1) / 100;

      num coeff = [difficulty, length, physical].average();
      coeff = pow(coeff, scalingCoeff) * maxTokens;

      tokens = coeff.clamp(minTokens, double.infinity).roundSeed(roundingSeed).toInt();
      rank = (coeff / rankRatio).clamp(minRank, double.infinity).roundSeed(roundingSeed).toInt();
      break;
  }
  model.edit({"attestation.tokens": tokens, "attestation.rank": rank});
}

void adjustMetrics(OmniModel model) {
  switch (model.tokenOrNull("category")) {
    case "0":
      var dislivIti = _readInsightToken(insight: model.tokenOr("insights.dislivello itinerario", "600 m"), toRemove: "m");
      var length = _readInsightToken(insight: model.tokenOr("insights.lunghezza", "12 km"), toRemove: "km");

      //var dislivFerr = _readInsightToken(insight: model.tokenOr("insights.dislivello ferrata", "600 m"), toRemove: "m", bounds: (10, 700));
      var iti = _readInsightDuration(insight: model.tokenOr("insights.itinerario", "5:00h"), bounds: (0.5, 12));
      var ferr = _readInsightDuration(insight: model.tokenOr("insights.ferrata", "4:00h"), bounds: (0.5, 8));

      var slopeRatio = 1 + (2 * dislivIti / (length * 1000)).clamp(0, 1);
      dislivIti = dislivIti.remap((10, 1500)).toDouble();
      length = length.remap((0, 30)).toDouble();

      var avg = [dislivIti, length, iti, ferr].average();
      var impegnoFisico = (avg * slopeRatio * model.tokenOr("metrics.multipliers.impegno fisico", 1) * 100).round().clamp(0, 100);
      var difficolta = ((20 * model.tokenOr("metrics.esposizione", 0) + 45 * model.tokenOr("metrics.tecnica", 0) + 35 * impegnoFisico) / 100).round();

      model.edit({"metrics.impegno fisico": impegnoFisico, "metrics.difficoltà": difficolta});

    case "1":
      var dislivIti = _readInsightToken(insight: model.tokenOr("insights.dislivello", "600 m"), toRemove: "m");
      var length = _readInsightToken(insight: model.tokenOr("insights.lunghezza", "12 km"), toRemove: "km");
      var iti = _readInsightDuration(insight: model.tokenOr("insights.itinerario", "4:00h"), bounds: (0.5, 12));

      var slopeRatio = 1 + (2 * dislivIti / (length * 1000)).clamp(0, 1);
      dislivIti = dislivIti.remap((10, 1500)).toDouble();
      length = length.remap((0, 30)).toDouble();
      var avg = [dislivIti, length, iti].average();
      var impegnoFisico = (avg * slopeRatio * 100).round().clamp(0, 100);

      model.edit({"metrics.lunghezza": (length * 100).round(), "metrics.impegno fisico": impegnoFisico});
  }
}

double _readInsightDuration({
  required String insight,
  required (double, double) bounds,
}) {
  var res = insight.toLowerCase().replaceAll("h", "").split(":");
  var hours = res[0].trim();
  var minutes = res.length > 1 ? res[1].trim() : "0";
  var val = double.parse("$hours.${(100 * num.parse(minutes) / 60).round()}").clamp(bounds.$1, bounds.$2);
  return (val - bounds.$1) / (bounds.$2 - bounds.$1);
}

double _readInsightToken({
  required String insight,
  required String toRemove,
  (double, double)? bounds,
}) {
  var res = insight.toLowerCase().replaceAll(toRemove.toLowerCase(), "").trim();
  var val = double.parse(res);
  if (bounds != null) {
    val = val.clamp(bounds.$1, bounds.$2);
    return (val - bounds.$1) / (bounds.$2 - bounds.$1);
  }
  return val;
}
