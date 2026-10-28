import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the splash screen visible for 3 seconds so it can be clearly observed
  await Future.delayed(const Duration(milliseconds: 3000));

  runApp(
    const ProviderScope(
      child: KrocApp(),
    ),
  );
}
