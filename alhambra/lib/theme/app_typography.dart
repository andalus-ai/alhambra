import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const title = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
  );

  static const section = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    fontSize: 12.5,
    height: 18 / 12.5,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w400,
  );

  static const code = TextStyle(
    fontSize: 12.5,
    height: 18 / 12.5,
    fontFamily: 'monospace',
  );
}
