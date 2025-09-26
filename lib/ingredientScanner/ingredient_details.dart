import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';
//import 'scanned_ingredient.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.ingredientName,
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F5DC), Color(0xFFECECD9)],
              ),
            ),
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _ingredientFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final ingredient = snapshot.data;
              final imagePath = ingredient?['ingredientPicture']?.toString() ?? 
                              'assets/default_ingredient.jpg';
              
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Header image
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.fastfood, size: 100, color: Colors.grey),
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFECECD9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name centered
                          Center(
                            child: Text(
                              widget.ingredientName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Info card
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Details',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Orbitron',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.monetization_on, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Estimated Cost: ${_getCostEstimate(ingredient)}",
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.local_fire_department, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Calories: ${_getCalories(ingredient)}",
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Nutritional Value:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Orbitron',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._getNutritionalInfo(ingredient),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Related Meals
                          const Text(
                            'Related Meals',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          const SizedBox(height: 16),
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
                                return const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No meals found containing this ingredient',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                              
                              return SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: relatedMeals.length,
                                  itemBuilder: (context, index) {
                                    return _buildMealCard(relatedMeals[index], context);
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
      final nutritionalValue = ingredient['nutritionalValue'].toString().split(';');
      return nutritionalValue.map((value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(value.trim(), style: const TextStyle(fontSize: 14))),
          ],
        ),
      )).toList();
    }
    return [const Text("Nutritional information not available", style: TextStyle(color: Colors.grey))];
  }

  Widget _buildMealCard(Map<String, dynamic> meal, BuildContext context) {
    final mealName = meal['mealName']?.toString() ?? 'Unknown Meal';
    final imagePath = meal['mealPicture']?.toString() ?? 'assets/default_meal.jpg';
    final mealId = meal['mealID'] as int?;

    return GestureDetector(
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
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                imagePath,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.fastfood, size: 50),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Php ${meal['price']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}