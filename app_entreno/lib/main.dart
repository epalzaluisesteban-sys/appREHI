import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs)..load();
  runApp(
    ChangeNotifierProvider.value(value: store, child: const EntrenoApp()),
  );
}

class EntrenoApp extends StatelessWidget {
  const EntrenoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'REHI',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(paletteById(context.select<AppStore, String>((s) => s.paletteId))),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      );
}
