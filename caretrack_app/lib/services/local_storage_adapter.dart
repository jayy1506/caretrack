import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart' as platform_storage;

class LocalStorageAdapter {
  static Future<void> setItem(String key, String value) async {
    platform_storage.saveLocal(key, value);
  }

  static String? getItem(String key) {
    return platform_storage.loadLocal(key);
  }

  static Future<void> removeItem(String key) async {
    platform_storage.removeLocal(key);
  }
}
