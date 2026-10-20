// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void saveLocal(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

String? loadLocal(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void removeLocal(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}
