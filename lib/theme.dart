import 'package:flutter/material.dart';

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 22,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
    ),
  ),
); 