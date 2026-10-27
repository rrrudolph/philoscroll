import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

class PreferencesScrollStore implements ScrollStore {
  PreferencesScrollStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getItem(String key) => _preferences.getString(key);

  @override
  void setItem(String key, String value) {
    try {
      _preferences.setString(key, value).catchError((Object _) => false);
    } catch (_) {
      // Keep scrolling if the platform refuses the write.
    }
  }
}
