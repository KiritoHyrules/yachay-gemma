import 'package:flutter/material.dart';

void main() {
  runApp(const YachayGemmaApp());
}

class YachayGemmaApp extends StatelessWidget {
  const YachayGemmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yachay Gemma',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yachay Gemma')),
      body: const Center(
        child: Text('Tutor de IA offline para estudiantes de secundaria'),
      ),
    );
  }
}
