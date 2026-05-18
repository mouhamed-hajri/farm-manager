import 'package:flutter/material.dart';

class AppColors {
  static const green = Color(0xFF2E7D32);
  static const greenLight = Color(0xFF66BB6A);
  static const red = Color(0xFFC62828);
  static const redLight = Color(0xFFEF5350);
  static const blue = Color(0xFF1565C0);
  static const blueLight = Color(0xFF42A5F5);
  static const surface = Color(0xFFF5F5F5);
  static const card = Colors.white;
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        cardTheme: const CardThemeData(
          color: AppColors.card,
          elevation: 2,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 15),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          extendedTextStyle:
              TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: AppColors.green,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 13),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
      );
}
