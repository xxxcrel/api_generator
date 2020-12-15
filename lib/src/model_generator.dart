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

    Map map = json.decode(jsonString)["definitions"];
    //去除类似JSONObject等第三方model对象
    map.removeWhere((key, value) => !value.containsKey("properties"));
    map = map.map((k, v) => MapEntry(k, v["properties"]));

    // 收集泛型
    map.entries.forEach((e) {
      if (e.key.toString().contains('<')) {
        String realName = e.key;
        genericModels['${realName.substring(0, realName.indexOf('<'))}'] = true;
      }
    });
    map.entries.forEach((e) {
      handleModel(e);
    });
    classModels.forEach((element) => generateDartModel(element));
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
    } else {
      properties = handleNonGenericModel(entry.value);
      classModels.add(ClassModel(className: realName, properties: properties));
      // print(JsonEncoder.withIndent('  ').convert(properties));
    }
  }

  static Map handleGenericeModel(var properties) {}

  //解析非泛型model的属性名字与类型
  //因swagger限制不能解析Map类型的字段, 只有当特别配置了swagger
  static Map handleNonGenericModel(var properties) {
    return properties.map((key, value) {
      String type = "";
      if (value.containsKey('\$ref')) {
        //字段类型是自定义类型
        type = value['\$ref'];
        // print(type);
        type = type.substring(type.lastIndexOf('\/') + 1);
      } else {
        type = value['type'];
        if (type == 'array') {
          String listType = "";
          var subType = value['items'];
          if (subType.containsKey('type')) {
            listType = 'List<${convertToDartType(subType['type'])}>';
          } else if (subType.containsKey('\$ref')) {
            subType = subType['\$ref'];
            listType =
                'List<${convertToDartType(subType.substring(subType.lastIndexOf('\/') + 1))}>';
          }
          type = listType;
        }
      }
      // print("fieldName:$key, fieldType:$type");
      return MapEntry(key, type);
    });
  }

  static void generateDartModel(ClassModel classModel) {
    List<String> fieldDefinition = List();
    Set<String> referenceImports = Set();
    classModel.properties
        .map((key, value) => MapEntry(key, convertToDartType(value)))
        .forEach((key, value) {
      if (!isPrimitive(value)) {
        String reference = value;
        if (isList(value)) {
          reference =
              "${value.substring(value.indexOf("<") + 1, value.length - 1)}";
          if (!isPrimitive(reference)) {
            referenceImports.add("import '$reference.dart';");
          }
        } else
          referenceImports.add("import '$reference.dart';");
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
    var file;
    try {
      file = File("$_savePath/models/$fileName.dart");
      if (!file.parent.existsSync()) file.parent.createSync();
    } catch (e) {
      print(e);
    }

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

  static String convertToDartType(String originalType) {
    String dartType = originalType;
    switch (originalType) {
      case "string":
        dartType = "String";
        break;
      case "boolean":
        dartType = "bool";
        break;
      case "integer":
        dartType = "int";
        break;
      case "number":
        dartType = "num";
        break;
      case "object":
        dartType = "Object";
        break;
      default:
        break;
    }
    return dartType;
  }
}

class ClassModel {
  final String className;
  final Map properties;
  ClassModel({this.className, this.properties});
}

// void main() {
//   ModelGenerator.generate("");
// }
