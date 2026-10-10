import 'dart:io' show Platform;

bool get isWeb => false;
bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
String get operatingSystem => Platform.operatingSystem;
