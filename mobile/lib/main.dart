import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'src/preferences_store.dart';
import 'src/quotes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final raw = await rootBundle.loadString('assets/data.json');
    final quotes = loadQuotes(jsonDecode(raw));
    PreferencesScrollStore? store;
    try {
      store = PreferencesScrollStore(await SharedPreferences.getInstance());
    } catch (error, stack) {
      debugPrint('The scroll position will not be saved.\n$error\n$stack');
    }
    runApp(PhiloApp(quotes: quotes, store: store));
  } catch (error, stack) {
    debugPrint('$error\n$stack');
    runApp(const PhiloApp(quotes: [], loadError: 'The teachings could not be opened.'));
  }
}
