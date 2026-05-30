import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UltimateRulesAssistantApp());
}

class UltimateRulesAssistantApp extends StatelessWidget {
  const UltimateRulesAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultimate Rules Assistant',
      debugShowCheckedModeBanner: false,
      
      // Global Theme System Configuration
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF7F5AF0),
        scaffoldBackgroundColor: const Color(0xFF0C0B10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7F5AF0),
          secondary: Color(0xFF2CB67D),
          background: Color(0xFF0C0B10),
          surface: Color(0xFF16151E),
          error: Color(0xFFF25F4C),
        ),
        
        // Premium custom typography using Google Fonts Outfit
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white.withOpacity(0.9),
          displayColor: Colors.white,
        ),
        
        // Input Fields decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          labelStyle: GoogleFonts.outfit(color: Colors.white60),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF7F5AF0), width: 1.5),
          ),
        ),
        
        // Tooltip, Slider, Card theme overrides
        cardTheme: CardThemeData(
          color: const Color(0xFF16151E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
      ),
      
      home: const HomeScreen(),
    );
  }
}
