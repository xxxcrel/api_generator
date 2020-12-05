import 'dart:convert';
import 'dart:io';
import 'package:dart_style/dart_style.dart';
import 'package:json_to_dart/model_generator.dart';
import 'package:json_to_dart/syntax.dart';
import 'package:http/http.dart' as http;
import 'package:darq/darq.dart';

String _savePath = "";

Future swagerToDartJson(String url, String savePath) async {
  _savePath = savePath;
  var file = await http.get(url);

  var map = json.decode(file.body.replaceAll('«', '<').replaceAll("»", ">"));

  var x = _swagerToJson(map["definitions"]);

  var saves = x.entries.map((e) => _saveToFile(e.key, _formatDart(e.value)));

  return Future.wait(saves);
}

Future<File> _saveToFile(String fileName, String data) async {
  var file = File(
      "$_savePath/models/${fileName.replaceAll("<", "").replaceAll(">", "")}.dart");
  if (!file.parent.existsSync()) file.parent.createSync();
  return file.writeAsString(data);
}

Map<String, String> _swagerToJson(Map<String, dynamic> jsons) {
  var j = jsons
      .map((key, m) => MapEntry(key, m["properties"]))
      .entries
      .select((x, i) {
    var className = x.key;
    List<JsonModel> p = x.value.entries
        .map((m) => _propertiesToJsonFiled(m.key, m.value))
        .toList()
        .cast<JsonModel>();
    return _jsonToDart(className, p.toList());
  }).toList();

  return List.generate(jsons.keys.length, (int index) => index)
      .toMap((i) => MapEntry(jsons.keys.toList()[i], j[i]));
}

String _jsonToDart(String name, List<JsonModel> models) {
  bool importFromList = false;
  var listImports = "";
  var subList = models.where((x) => x.subtype.isNotEmpty);
  if (subList.length != 0) {
    importFromList = true;
    listImports =
        subList.map((e) => "import '${e.subtype}.dart';\n").distinct().join();
    name = name.replaceAll("<", "").replaceAll(">", "");
  }

  if (name.contains("<")) {
    name = name.replaceAll("<", "").replaceAll(">", "");
  }

  bool importFromField = false;
  var fieldImports = "";
  var singleReferences = models.where((x) => !(x.type == "String" ||
      x.type == "int" ||
      x.type == "num" ||
      x.type == "bool" ||
      x.type == "List"));
  if (singleReferences.length != 0) {
    importFromField = true;
    fieldImports = singleReferences
        .map((e) => "import '${e.type}.dart';\n")
        .distinct()
        .join();
  }

  return """
  ${importFromList ? listImports : ""}
  ${importFromField ? fieldImports : ""}

  class $name{
      ${models.map((e) => e.definition()).join()}

      ${name.split("<").first}({
        ${models.map((e) => e.toConstructor()).join()}        
      });

      ${name.split("<").first}.fromJson(Map<String, dynamic> json) {
        ${models.map((e) => e.fromJson()).join()}
      }

      Map<String, dynamic> toJson() {
        final Map<String, dynamic> data = new Map<String, dynamic>();
        ${models.map((e) => e.toJson()).join()}
        return data;
      }
    }
    """;
}

JsonModel _propertiesToJsonFiled(String name, Map<String, dynamic> j) {
  var type = "";
  var subtype = "";
  switch (j["type"]) {
    case "string":
      type = "String";
      break;
    case "integer":
      type = "int";
      break;
    case "number":
      type = "num";
      break;
    case "boolean":
      type = "bool";
      break;
    case "array":
      type = "List";
      subtype = j["items"]["originalRef"];
      break;
    default:
      type = "String";
      break;
  }
  if (j["originalRef"] != null) type = j["originalRef"];

  return JsonModel(
    name: name.replaceAll("<", "").replaceAll(">", ""),
    type: type.replaceAll("<", "").replaceAll(">", ""),
    description: j["description"] ?? null,
    subtype: subtype.replaceAll("<", "").replaceAll(">", ""),
  );
}

String _formatDart(String code) {
  var formatter = DartFormatter();
  return DartCode(formatter.format(code), [Warning("", "")]).code;
}

class JsonModel {
  final String name;
  final String type;
  final String subtype;
  final String description;

  JsonModel({
    this.name,
    this.subtype,
    this.type,
    this.description,
  });

  String definition() {
    if (type == "List") {
      return """
    /// $description
    $type<$subtype> $name ;\n
    """;
    }
    return """
    /// $description
    $type $name ;\n
    """;
  }

  String toConstructor() {
    return """
    this.$name,
    """;
  }

  String fromJson() {
    if (type == "List") {
      return """      
      if (json['$name'] != null) {
        $name = new $type<$subtype>();
        json['$name'].forEach((v) {
          $name.add(new $subtype.fromJson(v));
        });
      }

      """;
    }
    if (!(type == "String" ||
        type == "int" ||
        type == "num" ||
        type == "bool" ||
        type == "List")) {
      return """
    if(json['$name']!=null)
    $name = $type.fromJson(json['$name']);

    """;
    }
    return """
    if(json['$name']!=null)
    $name = json['$name'];

    """;
  }

  String toJson() {
    if (type == "List") {
      return """    
    if (this.$name != null) {
      data['$name'] = this.$name.map((v) => v.toJson()).toList();
    }

    """;
    }
    return """    
    data['$name'] = this.$name;

    """;
  }
}
