import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/database/database_service.dart';
import 'core/state/student_state.dart';
import 'modules/diagnostico/diagnostico_screen.dart';
import 'modules/yachay/screens/yachay_scaffold.dart';
import 'modules/aprendizaje/leccion_service.dart';
import 'modules/gemma/gemma_service.dart';
import 'modules/gemma/model_download_page.dart';
import 'modules/gemma/model_installer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);

  // On-device inference runs on the flutter_gemma 1.4.2 path (CPU backend);
  // no dev-mode override needed for real device testing.

  final databaseService = DatabaseService.instance;
  final studentState = StudentState(databaseService);
  final leccionService = LeccionService();
  final gemmaService = GemmaService.instance;
  final modelInstalled = await _isModelInstalled();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider<StudentState>.value(value: studentState),
        Provider<LeccionService>.value(value: leccionService),
        Provider<GemmaService>.value(value: gemmaService),
      ],
      child: AprendoPlusApp(modelInstalled: modelInstalled),
    ),
  );
}

Future<bool> _isModelInstalled() async {
  try {
    return await FlutterGemmaModelInstaller().isModelInstalled();
  } catch (e) {
    debugPrint('Aprendo+: boot model check failed — $e');
    return false;
  }
}

class AprendoPlusApp extends StatelessWidget {
  const AprendoPlusApp({super.key, this.modelInstalled = true});

  final bool modelInstalled;

  Widget get _home {
    if (!modelInstalled) return const ModelDownloadPage();
    return GemmaService.useYachayOrchestrator
        ? const YachayScaffold()
        : const DiagnosticoScreen();
  }

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
      home: _home,
    );
  }
}
