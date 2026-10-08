import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  runApp(const BarbershopApp());
}
