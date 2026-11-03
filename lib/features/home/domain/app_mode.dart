import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { confidential, nonConfidential }

final appModeProvider = StateProvider<AppMode>((ref) => AppMode.confidential);
