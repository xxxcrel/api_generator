import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:dart_style/dart_style.dart';
import 'package:json_to_dart/model_generator.dart';
import 'package:json_to_dart/syntax.dart';

class ModelGenerator {
  // static String templatePath = "template.json";
  static String _savePath;
  static HashMap<String, bool> genericModels = HashMap();

  static List<ClassModel> classModels = List<ClassModel>();

  static void generate(String url, String savePath) async {
    _savePath = savePath;
    var file = await http.get(url);
    String jsonString = file.body.replaceAll("«", "<").replaceAll("»", ">");

    var map = json
        .decode(jsonString)["definitions"]
        .map((k, v) => MapEntry(k, v["properties"]));
    //收集泛型
    map.entries.forEach((e) {
      if (e.key.toString().contains('<')) {
        String realName = e.key;
        genericModels['${realName.substring(0, realName.indexOf('<'))}'] = true;
      }
    });
    map.entries.forEach((e) {
      handleModel(e);
    });
  }

  static void handleModel(MapEntry entry) {
    String modelName = entry.key;
    // remove Generic info, Result<User> => Result
    String realName = modelName.contains("<")
        ? modelName.substring(0, modelName.indexOf("<"))
        : modelName;
    Map properties = Map();

    if (genericModels.containsKey(realName)) {
      handleGenericeModel(entry.value);
      // genericProperties.putIfAbsent(realName, () => );
    } else {
      // print("handle non generice");
      properties = handleNonGenericModel(entry.value);
      classModels.add(ClassModel(className: realName, properties: properties));
      // print(JsonEncoder.withIndent('  ').convert(properties));
    }
    classModels.forEach((element) {
      generateDartModel("helo", element);
    });
  }

  static Map handleGenericeModel(var properties) {}

  static void generateDartModel(String path, ClassModel classModel) {
    List<String> fieldDefinition = List();
    Set<String> referenceImports = Set();
    classModel.properties
        .map((key, value) => MapEntry(key, convertToDartType(value)))
        .forEach((key, value) {
      if (!isPrimitive(value)) {
        if (isList(value)) {
          referenceImports.add(
              "import '${value.substring(value.indexOf("<") + 1, value.length - 1)}.dart';");
        } else
          referenceImports.add("import '$value.dart';");
      }
      fieldDefinition.add("$value $key;\n");
    });

    String modelString = """
    import 'package:json_annotation/json_annotation.dart';
    ${referenceImports.join()}

    part '${classModel.className}.g.dart';

    @JsonSerializable(explicitToJson: true)
    class ${classModel.className}{
      ${classModel.className}();

      ${fieldDefinition.join()}

      factory ${classModel.className}.fromJson(Map<String, dynamic> json) =>
      _\$${classModel.className}FromJson(json);
      Map<String, dynamic> toJson() => _\$${classModel.className}ToJson(this);
    }
    """;
    var formatter = DartFormatter();
    modelString =
        DartCode(formatter.format(modelString), [Warning("", "")]).code;
    // print(modelString);
    _saveToFile(classModel.className, modelString);
  }

  static Future<File> _saveToFile(String fileName, String data) async {
    var file = File("$_savePath/models/$fileName.dart");
    if (!file.parent.existsSync()) file.parent.createSync();
    return file.writeAsString(data);
  }

  static bool isPrimitive(String value) {
    List<String> primitiveType = [
      'String',
      'num',
      'bool',
      'int',
    ];
    return primitiveType.contains(value);
  }

  static bool isList(String value) {
    RegExp regExp = new RegExp(r'List<\w+>');
    return regExp.hasMatch(value);
  }

  //解析非泛型model的属性名字与类型
  //因swagger限制不能解析Map类型的字段, 只有当特别配置了swagger @ApiMo
  static Map handleNonGenericModel(var properties) {
    return properties.map((key, value) {
      String type = "";
      if (value.containsKey('\$ref')) {
        //字段类型是自定义类型
        type = value['\$ref'];
        type = type.substring(type.lastIndexOf('\/') + 1);
      } else {
        type = value['type'];
        if (type == 'array') {
          String subType = value['items']['\$ref'];
          String listType =
              'List<${subType.substring(subType.lastIndexOf('\/') + 1)}>';
          type = listType;
        }
      }
      return MapEntry(key, type);
    });
  }

  static String convertToDartType(String originalType) {
    switch (originalType) {
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
      case "object":
        return "Object";
        break;
      default:
        return originalType;
    }
  }
}

class ClassModel {
  final String className;
  final Map properties;
  ClassModel({this.className, this.properties});
}

// void main() {
//   ModelGenerator.generate();
// }
