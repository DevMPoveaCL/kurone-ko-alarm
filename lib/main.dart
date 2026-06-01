import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurone_ko_alarm/presentation/screens/import_screen.dart';

void main() {
  runApp(const ProviderScope(child: KuroneKoAlarmApp()));
}

final class KuroneKoAlarmApp extends StatelessWidget {
  const KuroneKoAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kurone-ko Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF455A64),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F4EE),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
        ),
      ),
      home: const ImportScreen(),
    );
  }
}
