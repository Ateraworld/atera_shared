import "dart:convert";
import "dart:io";

import "package:atera_shared/src/common/extensions/directory_extensions.dart";
import "package:atera_shared/src/common/extensions/string_extensions.dart";
import "package:omnimodel/omnimodel.dart";
import "package:path/path.dart";

RegExp markedTextRegExp = RegExp(r"\$\{\[(?<text>.+?(?=]))\](?<id>[a-zA-z0-9]+)\((?<payload>.*?(?=\)))\)\}");

RegExp attestationPeriodRegExp = RegExp(r"^(?<startd>0?[1-9]|[12][0-9]|3[01])-(?<startm>0?[1-9]|1[0-2])/(?<endd>0?[1-9]|[12][0-9]|3[01])-(?<endm>0?[1-9]|1[0-2])$");

class SanitizationResult {
  SanitizationResult(this.subject) {
    errors = List.empty(growable: true);
    warnings = List.empty(growable: true);
    maxFileSize = 0;
    maxFileSize = 0;
  }
  bool get success => errors.isEmpty;
  late List<String> errors;
  late List<String> warnings;
  late double maxFileSize;
  String subject;
  late double folderSize;
}

/// Sanitize an activity folder.
/// The folder must be located in the local file system and the [folder] param must be an absolute path to it.
/// The [existingActivities] should be a list of all the existing activities. The parameter is used to validate existing links to other activities.
///
/// Returns the result of the sanitarization.
Future<SanitizationResult> sanitizeActivityFolder(
  String folder, {
  List<OmniModel>? existingActivities,
  OmniModel? definitions,
  int warningSizeKB = 900,
}) async {
  if (!validateActivityFolder(folder)) {
    return SanitizationResult(folder)..errors.add("activity folder is not valid");
  }
  var subElems = Directory(folder).listSync();
  var index = subElems.indexWhere((element) => extension(element.path) == ".json");
  var res = SanitizationResult(folder);
  for (final f in subElems) {
    var currentDir = Directory(f.path);
    if (currentDir.existsSync()) {
      res.folderSize = (await currentDir.sizeKb()) / 1024;
      if (basename(currentDir.path) == "storage") {
        for (final a in currentDir.listSync()) {
          var size = File(a.path).statSync().size / 1024;
          if (size > (res.maxFileSize)) {
            res.maxFileSize = size;
          }
          if (size > warningSizeKB) {
            res.warnings.add("${basename(a.path)} asset is ${size.toStringAsFixed(2)} KB");
          }
        }
      }
    }
  }
  var file = File(subElems.elementAt(index).path);
  var model = OmniModel.fromDynamic(jsonDecode(await file.readAsString()));

  model = sanitizeActivityModel(
    model: model,
    result: res,
    existingActivities: existingActivities,
    definitions: definitions,
  );
  await file.writeAsString(model.toRawJson(indent: "  "));
  return res;
}

/// Check whether a file system folder is a valid activity folder.
bool validateActivityFolder(String folder) {
  try {
    var subElems = Directory(folder).listSync();
    var index = subElems.indexWhere((element) => extension(element.path) == ".json");
    if (index < 0) return false;
    var file = File(subElems.elementAt(index).path);
    jsonDecode(file.readAsStringSync());
    return true;
  } catch (error) {
    return false;
  }
}

Iterable<String> _getMissingStringLogs(OmniModel model, Iterable<String> fieldPaths) {
  var missing = List<String>.empty(growable: true);
  for (final f in fieldPaths) {
    if (model.tokenOr<String>(f, "").isEmpty) {
      missing.add("$f: value is missing");
    }
  }
  return missing;
}

/// Sanitize an activity model.
///
/// The function returns the sanitized model. The [definitions] param should be set to the definitions model and is used to check the existence of tags and metrics.
/// The [existingActivities] should be a list of all the existing activities. The parameter is used to validate existing links to other activities.
/// If provided, all te warnings and errors are appended to the [result] parameter.
OmniModel sanitizeActivityModel({
  required OmniModel model,
  OmniModel? definitions,
  List<OmniModel>? existingActivities,
  SanitizationResult? result,
}) {
  result ??= SanitizationResult(model.tokenOr("id", "uknown"));

  var images = model.tokenAsModel("images").entries.toList();
  var points = model.tokenAsModel("location.points").entries.toList();
  var category = model.tokenOrNull<String>("category");

  //* name, description, sections and insights format
  model = model.copyWith({
    "name": model.tokenOr("name", "").capitalized(),
    "description": _formatActivityString(model.tokenOr("description", "")).capitalized(),
    "relation.sections": OmniModel.fromEntries(
      model.tokenAsModel("relation.sections").entries.map((section) {
        var sectionModel = OmniModel.fromDynamic(section.value);
        var title = sectionModel.tokenOr("title", "").capitalized();
        var content = _formatActivityRelationSection(sectionModel.tokenOr("content", "")).capitalized();
        for (final match in markedTextRegExp.allMatches(content)) {
          var id = match.namedGroup("id");
          var payload = match.namedGroup("payload");
          if (id == "ph") {
            if (images.indexWhere((element) => element.key == payload) < 0) {
              result!.errors.add("referenced image $payload does not exist");
            }
          } else if (id == "pos") {
            if (points.indexWhere((element) => element.key == payload) < 0) {
              result!.errors.add("referenced point $payload does not exist");
            }
          } else if (id == "act" && existingActivities != null) {
            if (existingActivities.indexWhere((element) => payload == element.tokenOrNull("id")) < 0) {
              result!.errors.add("referenced activity $payload does not exist");
            }
          }
        }
        var nCount = content.split("\n").length;
        if (nCount < content.split(" ").length / 25) {
          result!.warnings.add("${section.value["title"]}: maybe you have few breaklines");
        }
        if (content.isEmpty) {
          result!.warnings.add("${section.value["title"]}: empty section");
        }
        return MapEntry(section.key, sectionModel.copyWith({"title": title, "content": content}).json);
      }).toList(),
    ).json,
    "insights":
        OmniModel.fromEntries(model.tokenAsModel("insights").entries.map((insight) => MapEntry(insight.key, _formatActivityInsightValue(insight.value.toString()))).toList()).json,
  });

  //* missing strings
  result.errors.addAll(
    _getMissingStringLogs(model, [
      "name",
      "category",
      "location.country",
      "location.region",
      "location.province",
      "location.zone",
    ]),
  );
  if (category == "0") {
    result.errors.addAll(
      _getMissingStringLogs(model, [
        "insights.dislivello ferrata",
        "insights.dislivello itinerario",
        "insights.itinerario",
        "insights.ferrata",
        "insights.lunghezza",
      ]),
    );
  }
  if (category == "1") {
    result.errors.addAll(
      _getMissingStringLogs(model, [
        "insights.dislivello",
        "insights.itinerario",
        "insights.lunghezza",
      ]),
    );
  }

  //* attestation
  var attestation = model.tokenOrNull<OmniModel>("attestation");
  if (attestation != null) {
    var lat = attestation.tokenOrNull<num>("latitude");
    var long = attestation.tokenOrNull<num>("longitude");
    if (lat == null || lat == 0 || long == null || long == 0) {
      result.errors.add("attestation coodinates are not set");
    }
    if (attestation.tokenOr("enabled", true)) {
      var entry = attestation.tokenOrNull<String>("period");
      if (!(entry == null || entry.isEmpty || attestationPeriodRegExp.hasMatch(entry))) {
        result.errors.add("attestation period not formatted");
      }
      if (attestation.tokenOr<num>("tokens", 0) <= 0) {
        result.errors.add("tokens: value is missing");
      }
      if (attestation.tokenOr<num>("rank", 0) <= 0) {
        result.errors.add("rank: value is missing");
      }
    }
  }

  //* points
  if (category != "2" && points.indexWhere((p) => p.key.contains("parcheggio")) < 0) {
    result.warnings.add("parking: point is missing");
  }
  if (category == "0") {
    if (points.indexWhere((p) => p.key.contains("attacco")) < 0) {
      result.warnings.add("attacco: point is missing");
    }
    if (points.indexWhere((p) => p.key.contains("stacco")) < 0) {
      result.warnings.add("stacco: point is missing");
    }
  }

  //* tags and metrics
  if (definitions != null) {
    var storedTags = definitions.tokenAsModel("tags").entries.toList();
    for (final t in model.tokenAsModel("tags").entries) {
      if (storedTags.indexWhere((element) => element.key == t.key) < 0) {
        result.errors.add("$t tag does not exist");
      }
    }
    var categoryMetrics = definitions.tokenAsModel("metrics.${model.tokenOr("category", "")}");
    var modelMetrics = model.tokenAsModel("metrics");
    for (final m in categoryMetrics.entries) {
      if (!modelMetrics.json.keys.contains(m.key)) {
        result.errors.add("$m metric does not exist");
      }
    }
  }
  return model;
}

String _formatActivityString(String source) {
  var reg = RegExp(r"[ ]+\n[ ]+|\n[ ]+|[ ]+\n");
  source = source.replaceAll(reg, "\n");
  source = source.replaceAll(RegExp("[ ]{2,}"), " ");
  source = source.replaceAll("A'", "À");
  source = source.replaceAll("E'", "È");
  source = source.replaceAll("I'", "Ì");
  source = source.replaceAll("O'", "Ò");
  source = source.replaceAll("U'", "Ù");
  return source;
}

String _formatActivityRelationSection(String sectionSource) {
  sectionSource = _formatActivityString(sectionSource);
  sectionSource = sectionSource.replaceAll(RegExp("/\bcai\b/gi"), "CAI");
  sectionSource = sectionSource.replaceAll(RegExp("/\bsat\b/gi"), "SAT");
  return sectionSource;
}

String _formatActivityInsightValue(String insightValue) {
  insightValue = insightValue.replaceAll(RegExp("[ ]+"), " ");
  insightValue = insightValue.replaceAll("Km", "km");
  insightValue = insightValue.replaceAll("M", "m");

  var regexp = RegExp("(?<val>[0-9])m");
  var match = regexp.firstMatch(insightValue);
  if (match != null) {
    insightValue = insightValue.replaceAll(match.pattern, "${match.namedGroup("val")} m");
  }

  regexp = RegExp("(?<val>[0-9])km");
  match = regexp.firstMatch(insightValue);
  if (match != null) {
    insightValue = insightValue.replaceAll(match.pattern, "${match.namedGroup("val")} km");
  }

  return insightValue.replaceAll(" h", "h");
}
