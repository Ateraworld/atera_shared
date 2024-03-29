import "dart:convert";
import "dart:io";

import "package:atera_shared/atera_shared.dart";
import "package:omnimodel/omnimodel.dart";
import "package:path/path.dart";

final RegExp markedTextRegExp = RegExp(r"\$\{\[(?<text>.+?(?=]))\](?<id>[a-zA-z0-9]+)\((?<payload>.*?(?=\)))\)\}");

class SanitizationResult {
  SanitizationResult(this.subject) {
    errors = List.empty(growable: true);
    warnings = List.empty(growable: true);
    sanitizedModel = OmniModel.empty();
  }

  bool get success => errors.isEmpty;

  final String subject;
  late OmniModel sanitizedModel;

  late List<String> errors;
  late List<String> warnings;
  double? maxFileSize;
  double? folderSize;
}

/// Sanitize an activity folder.
///
/// The folder must be located in the local file system and the [folder] param must be an absolute path to it.
///
/// - [modelOverride]: sanitize the provided model. If not provided, read the model from the folder.
///
/// - [existingActivities]: list of all the existing activities. Used to validate existing links to other activities.
///
/// - [definitions]: the model of the common definitions. Used to check categories, tags, metrics and more.
///
/// - [warningSizeKB]: the size in KB at which a warning is triggered.
///
/// - [checkAssetsExtensions]: whether to check that the assets are in the *.webp* format.
///
/// Returns the result of the sanitization.
Future<SanitizationResult> sanitizeActivityFolder(
  String folder, {
  OmniModel? modelOverride,
  List<OmniModel>? existingActivities,
  OmniModel? definitions,
  int warningSizeKB = 900,
  bool checkAssetsExtensions = true,
}) async {
  var res = SanitizationResult(folder);
  if (!validateActivityFolder(folder)) {
    res.errors.add("activity folder is not valid, json model or storage folder missing");
    if (modelOverride == null) return res;
  }
  var subElems = Directory(folder).listSync();
  var index = subElems.indexWhere((element) => extension(element.path) == ".json");
  var file = File(subElems.elementAt(index).path);
  var model = modelOverride ?? OmniModel.fromDynamic(jsonDecode(await file.readAsString()));
  var images = model.tokenAsModel("images");
  var posterFile = basename(model.tokenOr("poster.url", ""));

  for (final f in subElems) {
    var currentDir = Directory(f.path);
    if (!currentDir.existsSync()) continue;
    res.folderSize = (await currentDir.sizeKb()) / 1024;
    if (basename(currentDir.path) != "storage") continue;
    var storageElems = currentDir.listSync();
    if (checkAssetsExtensions && storageElems.any((element) => extension(element.path) != ".webp")) {
      res.warnings.add("storage folder contains non webp asets, they will be ignored");
    }
    if (!storageElems.any(
      (element) => checkAssetsExtensions ? basename(posterFile) == basename(element.path) : basenameWithoutExtension(posterFile) == basenameWithoutExtension(element.path),
    )) {
      res.errors.add("poster is referencing an unexistent asset");
    }
    for (final img in images.entries) {
      if (!storageElems.any(
        (element) => checkAssetsExtensions
            ? basename(OmniModel.fromDynamic(img.value).tokenOr("url", "")) == basename(element.path)
            : basenameWithoutExtension(OmniModel.fromDynamic(img.value).tokenOr("url", "")) == basenameWithoutExtension(element.path),
      )) {
        res.errors.add("image ${img.key} is referencing an unexistent asset");
      }
    }
    for (final a in storageElems) {
      var size = File(a.path).statSync().size / 1024;
      if (size > (res.maxFileSize ?? 0)) {
        res.maxFileSize = size;
      }
      if (size > warningSizeKB) {
        res.warnings.add("${basename(a.path)} asset is ${size.toStringAsFixed(2)} KB");
      }
    }
  }

  res = sanitizeActivityModel(
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
/// The folder must be located in the local file system and the [folder] param must be an absolute path to it.
///
/// - [existingActivities]: list of all the existing activities. Used to validate existing links to other activities.
///
/// - [definitions]: the model of the common definitions. Used to check categories, tags, metrics and more.
///
/// - [result]: if provided, append the result of the model sanitization to the result.
///
/// Returns the result of the sanitization.
SanitizationResult sanitizeActivityModel({
  required OmniModel model,
  List<OmniModel>? existingActivities,
  OmniModel? definitions,
  SanitizationResult? result,
}) {
  result ??= SanitizationResult(model.tokenOr("name", "uknown"));

  var images = model.tokenAsModel("images").entries.toList();
  var points = model.tokenAsModel("location.points").entries.toList();
  var category = model.tokenOrNull<String>("category");

  var imgUrlRegExp = RegExp(r"activities\/[a-z0-9-]*\/[a-z0-9_]*\.(webp|jpeg|jpg|png)", caseSensitive: false);

  //* poster and images
  if (model.tokenAsModel("poster").isEmpty) {
    result.errors.add("poster image is missing");
  } else {
    if (!imgUrlRegExp.hasMatch(model.tokenOr("poster.url", ""))) {
      result.errors.add("poster url not formatted correctly");
    }
    var type = model.tokenOr("poster.type", "");
    var types = ["storage", "web", "local"];
    if (!types.contains(type)) {
      result.errors.add("poster unsupported poster type $type");
    }
  }
  //* activities links
  var links = model.tokenAsModel("activities_links").entries;
  if (existingActivities != null) {
    for (final l in links) {
      if (!existingActivities.any((element) => element.tokenOr("id", "") == l.key)) {
        result.errors.add("linked activity ${l.key} does not exist");
      }
    }
  }

  //* name, description, sections and insights format
  model = model.copyWith({
    "name": model.tokenOr("name", "").capitalized(),
    "description": _formatActivityString(model.tokenOr("description", "")).capitalized(),
    "images": OmniModel.fromEntries(
      model.tokenAsModel("images").entries.map((img) {
        var imgModel = OmniModel.fromDynamic(img.value);
        imgModel.edit({"title": imgModel.tokenOr("title", "").capitalized()});
        if (!imgUrlRegExp.hasMatch(imgModel.tokenOr("url", ""))) {
          result!.errors.add("${img.key} url not formatted correctly");
        }
        var type = imgModel.tokenOr("type", "");
        var types = ["storage", "web", "local"];
        if (!types.contains(type)) {
          result!.errors.add("${img.key} unsupported poster type $type");
        }
        return MapEntry(img.key, imgModel.json);
      }),
    ).json,
    "location.points": OmniModel.fromEntries(
      model.tokenAsModel("location.points").entries.map((point) {
        var pointModel = OmniModel.fromDynamic(point.value);
        pointModel.edit({"description": pointModel.tokenOr("description", "").capitalized()});
        return MapEntry(point.key, pointModel.json);
      }),
    ).json,
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
      if (!(entry == null || entry.isEmpty || AttestationPeriod.hasMatch(entry))) {
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
        result.errors.add("${t.key} tag does not exist");
      }
    }
    var categoryMetrics = definitions.tokenAsModel("metrics.${model.tokenOr("category", "")}");
    var modelMetrics = model.tokenAsModel("metrics");
    for (final m in categoryMetrics.entries) {
      if (!modelMetrics.json.keys.contains(m.key)) {
        result.errors.add("${m.key} metric does not exist");
      }
    }
  }
  result.sanitizedModel = model;
  return result;
}

String _formatActivityString(String source) {
  // TODO check
  source = source.replaceAll(RegExp(r"[ ]+\n[ ]+|\n[ ]+|[ ]+\n"), r"\n");
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
  sectionSource = sectionSource.replaceAllMapped(
    RegExp(r"\b(cai|sat)[ ]?([0-9]+)?", caseSensitive: false),
    (match) {
      var number = match.group(2);
      if (number == null) return "${match.group(1)?.toUpperCase() ?? ""} ";
      return "${match.group(1)?.toUpperCase() ?? ""} ${match.group(2)}";
    },
  );
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
