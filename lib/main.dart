import 'package:flutter/material.dart';

void main() => runApp(const MuskyApp());

class MuskyApp extends StatelessWidget {
  const MuskyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Musky',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246B62)),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Musky')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64),
              SizedBox(height: 24),
              Text('Welcome to Musky', style: TextStyle(fontSize: 28)),
              SizedBox(height: 12),
              Text('Stock and client management'),
            ],
          ),
        ),
      ),
    );
  }
}
