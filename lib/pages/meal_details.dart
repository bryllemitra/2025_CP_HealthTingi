import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class MealDetailsPage extends StatelessWidget {
  final int mealId;

  const MealDetailsPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECD9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Meal Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'Orbitron',
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: _loadMealData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final mealData = snapshot.data as Map<String, dynamic>;
            final ingredients = mealData['ingredients'] as List<Map<String, dynamic>>;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Image Card
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFF66),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          mealData['mealPicture'] ?? 'assets/placeholder.jpg',
                          height: 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mealData['mealName'],
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '(Serving Size: ${mealData['servings']})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Orbitron',
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ingredients and Cost
                  const Text(
                    'Ingredients and Cost',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: ingredients.map((ingredient) {
                        return Text(
                          '${ingredient['quantity']} ${ingredient['ingredientName']}.........Php ${ingredient['price']}',
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/reverse-ingredient');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFF66),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        'Change Ingredients',
                        style: TextStyle(fontFamily: 'Orbitron'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Instructions
                  const Text(
                    'Instructions for Cooking',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mealData['instructions'],
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadMealData() async {
    final dbHelper = DatabaseHelper.instance;
    final meal = await dbHelper.getMealById(mealId);
    final ingredients = await dbHelper.getMealIngredients(mealId);
    
    return {
      ...meal!,
      'ingredients': ingredients,
    };
  }
}