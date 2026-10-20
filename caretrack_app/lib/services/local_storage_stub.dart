final Map<String, String> _memoryCache = {};

void saveLocal(String key, String value) {
  _memoryCache[key] = value;
}

String? loadLocal(String key) {
  return _memoryCache[key];
}

void removeLocal(String key) {
  _memoryCache.remove(key);
}
