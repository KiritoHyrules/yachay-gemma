import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/database/database_service.dart';
import 'core/state/student_state.dart';
import 'modules/diagnostico/diagnostico_screen.dart';
import 'modules/yachay/screens/yachay_scaffold.dart';
import 'modules/aprendizaje/leccion_service.dart';
import 'modules/gemma/gemma_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On-device inference runs on the flutter_gemma 1.4.2 path (CPU backend);
  // no dev-mode override needed for real device testing.

  final databaseService = DatabaseService.instance;
  final studentState = StudentState(databaseService);
  final leccionService = LeccionService();
  final gemmaService = GemmaService.instance;

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider<StudentState>.value(value: studentState),
        Provider<LeccionService>.value(value: leccionService),
        Provider<GemmaService>.value(value: gemmaService),
      ],
      child: const AprendoPlusApp(),
    ),
  );
}

class AprendoPlusApp extends StatelessWidget {
  const AprendoPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aprendo+',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GemmaService.useYachayOrchestrator
          ? const YachayScaffold()
          : const DiagnosticoScreen(),
    );
  }
}

