import 'package:flutter/material.dart';

class TextReaderScreen extends StatelessWidget {
  const TextReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Text Reading",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          "📷 Capture text here...",
          style: TextStyle(fontSize: 20, color: Colors.black54),
        ),
      ),
    );
  }
}
