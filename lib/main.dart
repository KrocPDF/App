import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the splash screen visible for 2 seconds
  await Future.delayed(const Duration(milliseconds: 2000));

  runApp(
    const ProviderScope(
      child: KrocApp(),
    ),
  );
}
