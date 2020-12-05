library api_generator;

import 'dart:convert';
import 'dart:io';
import '../lib/src/swager_to_dart_api.dart';
import '../lib/src/swaget_to_dart_json.dart';

var encoding = Encoding.getByName("utf-8");

String template =
    "/// \$Summary\$ static Future<\$ReturnType\$> \$GeneratedApiName\$(\$ApiParameters\$) async => await httpPost<\$ReturnType\$>(\"\$ApiUrl\$\", \$ApiParametersMap\$, converter: (data) => \$ReturnType\$.fromJson(data));";
String _defaultSavePath = "./lib";

void main() {
  String url, savePath;
  stdout.write("please enter api url:");
  url = stdin.readLineSync(encoding: encoding);
  while (url.isEmpty || url.length == 0) {
    stdout.write("Please enter api url:");
    url = stdin.readLineSync(encoding: encoding);
  }
  // print("The api url: $url");
  while (true) {
    stdout.write("Please enter save path(default:lib/api):");
    savePath = stdin.readLineSync(encoding: encoding);
    if (savePath.isEmpty || savePath.length == 0) {
      savePath = _defaultSavePath;
    }
    if(pathExist(savePath)){
      break;
    }else{
      print("can't find path \"$savePath\", please create first");
    }
  }
  print("default template:\n $template");

  swagerToDartJson(url, savePath);
  swagerToDartApi(url, template, savePath);
}

bool pathExist(String path) {
  var file = Directory(path);
  if (!file.existsSync()) {
    return false;
  }
  return true;
}
