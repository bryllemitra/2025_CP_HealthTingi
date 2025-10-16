import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/reverse_ingredient.dart';
import 'pages/index.dart';
import 'pages/login.dart';
import 'pages/register.dart';
import 'pages/meal_scan.dart';
import 'searchMeals/categories.dart';
//test

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
      initialRoute: '/',
      routes: {
        '/': (context) => const IndexPage(),
        '/guest': (context) => MealScanPage(userId: 0),
        '/home': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return HomePage(
            title: 'HealthTingi',
            userId: args['userId'],
          );
        },
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/meal-scan': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return MealScanPage(userId: args['userId']);
        },
        '/reverse-ingredient': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map? ?? {};
          return ReverseIngredientPage(
            ingredients: args['ingredients'],
            userId: args['userId'] ?? 0, // Default to 0 (guest) if not provided
          );
        },
        '/searchIngredient/categories': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return CategoryPage(
            category: args['category'],
            userId: args['userId'],
          );
        },
      },
    );
  }
}