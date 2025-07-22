import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/meal_details.dart';
import 'pages/reverse_ngredient.dart';
import 'pages/index.dart'; 
import 'pages/login.dart';
import 'pages/register.dart';

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
      home: const IndexPage(), // Set IndexPage as the initial page
      routes: {
        '/meal-details': (context) => const MealDetailsPage(),
        '/reverse-ingredient': (context) => const ReverseIngredientPage(),
        '/home': (context) => const HomePage(title: 'HealthTingi'),
        '/login': (context) => const LoginPage(),      
        '/register': (context) => const RegisterPage(), 
      },
    );
  }
}
