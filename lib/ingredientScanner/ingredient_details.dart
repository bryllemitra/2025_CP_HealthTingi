import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';
import 'scanned_ingredient.dart';

class IngredientDetailsPage extends StatefulWidget {
  final int userId;
  final String ingredientName;
  
  const IngredientDetailsPage({
    super.key, 
    required this.userId,
    required this.ingredientName,
  });

  @override
  State<IngredientDetailsPage> createState() => _IngredientDetailsPageState();
}

class _IngredientDetailsPageState extends State<IngredientDetailsPage> {
  late Future<List<Map<String, dynamic>>> _relatedMealsFuture;
  late Future<Map<String, dynamic>?> _ingredientFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _relatedMealsFuture = _fetchRelatedMeals();
    _ingredientFuture = _fetchIngredientDetails();
  }

  Future<List<Map<String, dynamic>>> _fetchRelatedMeals() async {
    try {
      final allMeals = await _dbHelper.getAllMeals();
      final relatedMeals = allMeals.where((meal) {
        final mealName = meal['mealName']?.toString().toLowerCase() ?? '';
        final categories = meal['category']?.toString().toLowerCase() ?? '';
        final content = meal['content']?.toString().toLowerCase() ?? '';
        
        final ingredientLower = widget.ingredientName.toLowerCase();
        
        // Check if meal contains the ingredient in name, category, or content
        return mealName.contains(ingredientLower) ||
               categories.contains(ingredientLower) ||
               content.contains(ingredientLower);
      }).toList();

      // Also check meals that have this ingredient in their ingredients list
      for (var meal in allMeals) {
        if (!relatedMeals.contains(meal)) {
          final mealIngredients = await _dbHelper.getMealIngredients(meal['mealID']);
          final hasIngredient = mealIngredients.any((ingredient) {
            final ingName = ingredient['ingredientName']?.toString().toLowerCase() ?? '';
            return ingName.contains(widget.ingredientName.toLowerCase());
          });
          
          if (hasIngredient && !relatedMeals.contains(meal)) {
            relatedMeals.add(meal);
          }
        }
      }

      return relatedMeals;
    } catch (e) {
      print('Error fetching related meals: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchIngredientDetails() async {
    try {
      final allIngredients = await _dbHelper.getAllIngredients();
      return allIngredients.firstWhere(
        (ingredient) => ingredient['ingredientName']?.toString().toLowerCase() == 
                       widget.ingredientName.toLowerCase(),
        orElse: () => {},
      );
    } catch (e) {
      print('Error fetching ingredient details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5DC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.ingredientName,
          style: const TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ingredient Image and Name
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _ingredientFuture,
                builder: (context, snapshot) {
                  final ingredient = snapshot.data;
                  final imagePath = ingredient?['ingredientPicture']?.toString() ?? 
                                  'assets/default_ingredient.jpg';
                  
                  return Column(
                    children: [
                      Image.asset(
                        imagePath,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.fastfood, size: 100),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.ingredientName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Ingredient Information
            FutureBuilder<Map<String, dynamic>?>(
              future: _ingredientFuture,
              builder: (context, snapshot) {
                final ingredient = snapshot.data;
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Estimated Cost: ${_getCostEstimate(ingredient)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text("Calories: ${_getCalories(ingredient)}"),
                      const SizedBox(height: 8),
                      const Text(
                        "Nutritional value:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ..._getNutritionalInfo(ingredient),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Related Meals Section
            Align(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  children: [
                    const TextSpan(
                      text: "Meals with ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: widget.ingredientName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Related Meals List
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _relatedMealsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return const Text('Error loading related meals');
                }
                
                final relatedMeals = snapshot.data ?? [];
                
                if (relatedMeals.isEmpty) {
                  return const Text(
                    'No meals found containing this ingredient',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                
                return Column(
                  children: relatedMeals.map((meal) => 
                    _buildMealCard(meal, context)
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getCostEstimate(Map<String, dynamic>? ingredient) {
    if (ingredient != null && ingredient['price'] != null) {
      return 'Php ${ingredient['price']} (per unit)';
    }
    return 'Price information not available';
  }

  String _getCalories(Map<String, dynamic>? ingredient) {
    if (ingredient != null && ingredient['calories'] != null) {
      return '${ingredient['calories']} kcal per 100g';
    }
    return 'Calorie information not available';
  }

  List<Widget> _getNutritionalInfo(Map<String, dynamic>? ingredient) {
    if (ingredient != null && ingredient['nutritionalValue'] != null) {
      final nutritionalValue = ingredient['nutritionalValue'].toString();
      return [
        Text("• $nutritionalValue"),
      ];
    }
    return [const Text("Nutritional information not available")];
  }

  Widget _buildMealCard(Map<String, dynamic> meal, BuildContext context) {
    final mealName = meal['mealName']?.toString() ?? 'Unknown Meal';
    final imagePath = meal['mealPicture']?.toString() ?? 'assets/default_meal.jpg';
    final mealId = meal['mealID'] as int?;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => 
              const Icon(Icons.fastfood, size: 50),
          ),
        ),
        title: Text(mealName),
        subtitle: Text(
          'Php ${meal['price']?.toStringAsFixed(2) ?? '0.00'} • ${meal['calories']?.toString() ?? '0'} kcal'
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (mealId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MealDetailsPage(
                  mealId: mealId,
                  userId: widget.userId,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}