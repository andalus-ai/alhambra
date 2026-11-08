import 'dart:async';

import 'module_context.dart';

abstract interface class AlhambraModule {
  String get id;

  Future<void> activate(ModuleContext context);

  Future<void> deactivate();
}
