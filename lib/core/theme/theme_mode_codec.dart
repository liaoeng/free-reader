import 'package:flutter/material.dart';

class ThemeModeCodec {
  const ThemeModeCodec._();

  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';

  static ThemeMode decode(String value) {
    return switch (value) {
      dark => ThemeMode.dark,
      light => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  static String encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => dark,
      ThemeMode.light => light,
      ThemeMode.system => system,
    };
  }
}
