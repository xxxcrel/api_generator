import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';


class ModelGenerator{

  static String templatePath = "./template.json";

  static void generate({String modelJsons})async{
      File template = File(templatePath);
      String jsonString;

      jsonString = await template.readAsString();
      jsonString = jsonString.replaceAll("«", "<").replaceAll("»", ">");
      // print(jsonString);
      var map = json.decode(jsonString)["definitions"].map((k, v) => MapEntry(k, v["properties"]));
      // map.entries.map((e) => print(e.key));
      map.entries.forEach((e){
        // print(e.key.runtimeType);
        // print(e.value.runtimeType);
        handleModel(e);
        // print("type:${e.key.toString()}");
        // print("prop:${e.value.toString()}");
        if(isCollection(type:e.key)){
          print("${e.key} is collection");
        }
      });
  }

  static bool isCollection({dynamic type}){
      if(type == "Map"){
        return true;
      }
      return false;
  }

  static bool handleModel(MapEntry entry){
    String type = entry.key;

    String realType = "";
    Map properties = Map();
    if(isGeneric(type)){
      realType = type.substring(0, type.indexOf('<'));
      properties = parseProperties(entry.value);
    }else{
      realType = type;
      parseProperties(entry.value);
    }
      print(realType);
  }

  static bool isGeneric(String key){
      return key.contains("<");
  }

  static HashMap parseProperties(var fieldInfo){
      fieldInfo.forEach((key, value) => print(value.toString()));
  }


}
void main() {
  ModelGenerator.generate();
}