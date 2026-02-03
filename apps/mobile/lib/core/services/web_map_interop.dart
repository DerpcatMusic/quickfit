@JS()
library;

import 'dart:js_interop';

@JS('QuickFitMap.getDarkStyleJson')
external String? _jsGetDarkStyleJson(String tilesPath);

@JS('QuickFitMap.getLightStyleJson')
external String? _jsGetLightStyleJson(String tilesPath);

String? getDarkStyleJson(String tilesPath) => _jsGetDarkStyleJson(tilesPath);
String? getLightStyleJson(String tilesPath) => _jsGetLightStyleJson(tilesPath);
