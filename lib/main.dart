import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/demo/demo_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DemoGuard.isExpired();

  runApp(const ProviderScope(child: KrocApp()));
}
