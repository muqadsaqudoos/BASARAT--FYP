import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/object_detection_screen.dart';
import 'screens/text_reader_screen.dart';
import 'state/app_settings.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'بصارت',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: settings.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
      routes: {
        '/object_detection': (context) => const ObjectDetectionScreen(),
        '/text_reader': (context) => const TextReaderScreen(),
      },
    );
  }
}
