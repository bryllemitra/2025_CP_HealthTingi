import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class MealDetailsPage extends StatefulWidget {
  final int mealId;

  const MealDetailsPage({super.key, required this.mealId});

  @override
  State<MealDetailsPage> createState() => _MealDetailsPageState();
}

class _MealDetailsPageState extends State<MealDetailsPage> {
  Future<Map<String, dynamic>>? _mealDataFuture;

  @override
  void initState() {
    super.initState();
    _mealDataFuture = _loadMealData();
  }

  Future<Map<String, dynamic>> _loadMealData() async {
    final dbHelper = DatabaseHelper();
    final meal = await dbHelper.getMealById(widget.mealId);
    final ingredients = await dbHelper.getMealIngredients(widget.mealId);
    
    if (meal == null) {
      throw Exception('Meal not found');
    }

    return {
      ...meal,
      'ingredients': ingredients,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECD9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
        future: _mealDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No meal data found'));
          }

          final mealData = snapshot.data!;
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
                      _buildMealImage(mealData['mealPicture']),
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${ingredient['quantity'] ?? ''} ${ingredient['ingredientName']}.........Php ${ingredient['price']}',
                          style: const TextStyle(fontSize: 12),
                        ),
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
                    mealData['instructions'] ?? 'No instructions available',
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
        },
      ),
    );
  }

  Widget _buildMealImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        height: 180,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
        ),
      );
    }

    return Image.asset(
      imagePath,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 180,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
          ),
        );
      },
    );
  }
}
