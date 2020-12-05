library api_generator;

import 'dart:convert';
import 'dart:io';
import '../lib/src/swager_to_dart_api.dart';
import '../lib/src/swaget_to_dart_json.dart';

var encoding = Encoding.getByName("utf-8");

String template =
    "/// \$Summary\$ static Future<\$ReturnType\$> \$GeneratedApiName\$(\$ApiParameters\$) async => await httpPost<\$ReturnType\$>(\"\$ApiUrl\$\", \$ApiParametersMap\$, converter: (data) => \$ReturnType\$.fromJson(data));";

void main() {
  String url, savePath;
  stdout.write("please enter api url:");
  url = stdin.readLineSync(encoding: encoding);
  while (url.isEmpty || url.length == 0) {
    stdout.write("Please enter api url:");
    url = stdin.readLineSync(encoding: encoding);
  }
  print("The api url: $url");
  stdout.write("please enter save path(default: lib/api/):");
  print("default template: $template");
  savePath = "./";
  swagerToDartJson(url, savePath);
  swagerToDartApi(url, template, savePath);
}
