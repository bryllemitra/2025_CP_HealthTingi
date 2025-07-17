import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/mealDetails.dart';
import 'pages/reverseIngredient.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthTingi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Orbitron',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellowAccent),
      ),
      home: const HomePage(title: 'HealthTingi'),
      routes: {
        '/meal-details': (context) => const MealDetailsPage(),
        '/reverse-ingredient': (context) => const ReverseIngredientPage(),
      },
    );
  }
}
