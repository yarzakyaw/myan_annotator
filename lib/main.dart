import 'package:flutter/material.dart';
import 'package:myan_annotator/data_annotator_screen.dart';

void main() async {
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('_delta == _root.toDelta()')) {
      print('Suppressed flutter_quill compose error: ${details.exception}');
      return;
    }
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DataAnnotatorScreen(),
    );
  }
}
