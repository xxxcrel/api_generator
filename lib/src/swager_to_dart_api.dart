import 'dart:convert';
import 'dart:io';
import 'package:dart_style/dart_style.dart';
import 'package:http/http.dart' as http;
import 'package:darq/darq.dart';
import 'package:json_to_dart/model_generator.dart';
import 'package:json_to_dart/syntax.dart';

String _template = "";
String _savePath = "";

String tp = "";

Future swagerToDartApi(String url, String template, String savePath) async {
  _savePath = savePath;
  _template = template;
  //  Downlaod it first
  var file = await http.get(url);

  var map = json.decode(file.body.replaceAll('«', '<').replaceAll("»", ">"));

  //  API parts

  var apis = await _getApis(map["paths"]);

  var apiList = _apiToDart(apis);
  var apiImports = _apiImports(apis);
  var apiTags = _apiTags(apis);
  var saveApi = apiList.entries.map(
    (x) => _saveToFile(
      x.key,
      _formatDart(
          _withClassScope(x.key, x.value, apiImports[x.key], apiTags[x.key])),
    ),
  );

  return Future.wait(saveApi);
}

/// 格式化Dart代码
String _formatDart(String code) {
  var formatter = new DartFormatter();
  return DartCode(formatter.format(code), [Warning("", "")]).code;
}

/// 从返回的json生成[ApiModel]
Future<List<ApiModel>> _getApis(Map<String, dynamic> map) {
  var apis = List<ApiModel>();

  map.forEach(
    (key, value) {
      var m = value as Map<String, dynamic>;

      var u = key; //  URL
      List<String> t = m["post"]["tags"].cast<String>();
      var s = m["post"]["summary"]; //  Summary
      var o = m["post"]["operationId"]; //  OperationID
      List<ApiParameter> p = List<ApiParameter>();
      //  有参数遍历所有, 赋值到p
      if (m["post"]["parameters"] != null)
        p = m["post"]["parameters"]
            .map((e) => ApiParameter(
                  name: e["name"],
                  description: e["description"],
                  type: ApiParameter.formatType(e["type"]),
                ))
            .toList()
            .cast<ApiParameter>();

      //  返回值类型
      var r = (m["post"]["responses"]["200"]["schema"]["\$ref"] as String)
          .split('/')
          .last;

      apis.add(
        ApiModel(
          catagory: u.split("/")[1],
          url: u,
          tag: t,
          //  Comments here
          summary: s +
              "\n\/\/\/\n" +
              p
                  .map((e) => "\/\/\/  Where [${e.name}] is ${e.description}")
                  .join("\n\/\/\/\n"),
          operationId: o,
          params: p,
          result: r.replaceAll("<", "").replaceAll(">", ""),
        ),
      );
    },
  );
  return Future.value(apis);
}

/// API转dart
Map<String, String> _apiToDart(List<ApiModel> apis) {
  var keys = apis.map((e) => e.catagory).distinct().toList();

  Map<String, List<ApiModel>> grouped = Map();

  keys.forEach((key) {
    grouped.addAll({key: apis.where((x) => x.catagory == key).toList()});
  });

  return List.generate(keys.length, (int index) => index).toMap((i) =>
      MapEntry(keys[i], _apiModelToDart(keys[i], grouped[keys[i]], _template)));
}

/// 拿API Tags
Map<String, String> _apiTags(List<ApiModel> apis) {
  var keys = apis.map((e) => e.catagory).distinct().toList();
  Map<String, List<ApiModel>> grouped = Map();
  keys.forEach((key) {
    grouped.addAll({key: apis.where((x) => x.catagory == key).toList()});
  });
  return List.generate(keys.length, (int index) => index).toMap(
    (i) => MapEntry(
      keys[i],
      grouped[keys[i]].map((e) => "${e.tag}").distinct().join("\n"),
    ),
  );
}

/// 拿API imports
Map<String, String> _apiImports(List<ApiModel> apis) {
  var keys = apis.map((e) => e.catagory).distinct().toList();
  Map<String, List<ApiModel>> grouped = Map();
  keys.forEach((key) {
    grouped.addAll({key: apis.where((x) => x.catagory == key).toList()});
  });
  return List.generate(keys.length, (int index) => index).toMap(
    (i) => MapEntry(
      keys[i],
      grouped[keys[i]]
          .map((e) => "import '../models/${e.result}.dart';")
          .distinct()
          .join("\n"),
    ),
  );
}

/// 给API套class等东西
String _withClassScope(
    String name, String content, String imports, String tag) {
  return """
import 'package:flutter/material.dart';
import '../api.dart';
$imports

/// $tag
class ${_toClassName(name)}Api{
$content
}
""";
}

/// 转成类名(首字母大写)
String _toClassName(String name) {
  var f = name[0].toUpperCase();
  return "$f${name.substring(1)}";
}

/// 写文件
Future<File> _saveToFile(String fileName, String data) async {
  var file = File(
      "$_savePath/api/${fileName.replaceAll("<", "").replaceAll(">", "")}.dart");
  if (!file.parent.existsSync()) file.parent.createSync();
  if (!file.existsSync()) file.createSync();
  return file.writeAsString(data);
}

/// 替换占位符
String _apiModelToDart(String name, List<ApiModel> apis, String template) {
  var api = apis.map<String>(
    (e) {
      var d = template;
      d = d.replaceAll("\$Summary\$", e.summary);
      d = d.replaceAll("\$Tag\$", e.tag.join(" "));
      d = d.replaceAll("\$GeneratedApiName\$", e.operationId);
      d = d.replaceAll("\$ApiUrl\$", e.url);
      d = d.replaceAll(
        "\$ApiParameters\$",
        e.params.length != 0
            ? "{${e.params.select((x, i) => "@required ${x.type} ${x.name}").join(",")}}"
            : "",
      );
      d = d.replaceAll(
        "\$ApiParametersMap\$",
        e.params
            .toMap<String, String>((x) => MapEntry("\"${x.name}\"", x.name))
            .toString(),
      );
      d = d.replaceAll("\$ReturnType\$", e.result);
      return d;
    },
  );

  return api.join("\n");
}

class ApiModel {
  final String catagory;
  final String url;
  final List<String> tag;
  final String summary;

  /// Method name
  final String operationId;
  final List<ApiParameter> params;
  final String result;

  ApiModel({
    this.catagory,
    this.url,
    this.tag,
    this.summary,
    this.operationId,
    this.params,
    this.result,
  });
}

class ApiParameter {
  final String name;
  final String type;
  final String description;

  static String formatType(String type) {
    switch (type) {
      case "string":
        return "String";
        break;
      case "boolean":
        return "bool";
        break;
      case "integer":
        return "int";
        break;
      case "number":
        return "num";
        break;
      default:
        return "String";
        break;
    }
  }

  ApiParameter({this.name, this.type, this.description});
}
