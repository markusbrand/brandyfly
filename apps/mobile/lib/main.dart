import 'package:flutter/material.dart';

void main() {
  runApp(const BrandyFlyApp());
}

class BrandyFlyApp extends StatelessWidget {
  const BrandyFlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrandyFly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const Scaffold(body: Center(child: Text('BrandyFly'))),
    );
  }
}
