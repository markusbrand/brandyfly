import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'demo/vario_screen.dart';

// Set to true (or pass --dart-define=DEMO=true) to show the mock vario UI.
// Automatically true in debug builds so the PC development workflow always
// shows the instrument display.
const bool _demoMode =
    bool.fromEnvironment('DEMO', defaultValue: kDebugMode);

void main() {
  runApp(const BrandyFlyApp());
}

class BrandyFlyApp extends StatelessWidget {
  const BrandyFlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrandyFly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: _demoMode
          ? const VarioScreen()
          : const Scaffold(body: Center(child: Text('BrandyFly'))),
    );
  }
}
