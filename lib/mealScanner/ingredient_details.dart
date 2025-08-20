import 'package:flutter/material.dart';
import 'scanned_ingredient.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

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

  Future<List<Map<String, dynamic>>> _getAllIngredients() async {
    try {
      final db = await _dbHelper.database;
      return await db.query('ingredients');
    } catch (e) {
      print('Error getting all ingredients: $e');
      return [];
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ScannedIngredientPage(userId: widget.userId),
              ),
            );
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
                                  'assets/${widget.ingredientName.toLowerCase()}.jpg';
                  
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
      return '₱${ingredient['price']} (per unit)';
    }
    
    // Fallback to hardcoded values if database doesn't have the ingredient
    switch (widget.ingredientName.toLowerCase()) {
      case 'sayote':
        return '₱10–₱15 (per medium-sized piece)';
      case 'chicken':
        return '₱150–₱200 (per kilo)';
      case 'petchay':
        return '₱20–₱30 (per bundle)';
      default:
        return 'Price varies';
    }
  }

  String _getCalories(Map<String, dynamic>? ingredient) {
    if (ingredient != null && ingredient['calories'] != null) {
      return '${ingredient['calories']} kcal per 100g';
    }
    
    // Fallback to hardcoded values
    switch (widget.ingredientName.toLowerCase()) {
      case 'sayote':
        return '19 kcal per 100g';
      case 'chicken':
        return '239 kcal per 100g (breast)';
      case 'petchay':
        return '13 kcal per 100g';
      default:
        return 'Calories vary';
    }
  }

  List<Widget> _getNutritionalInfo(Map<String, dynamic>? ingredient) {
    if (ingredient != null && ingredient['nutritionalValue'] != null) {
      final nutritionalValue = ingredient['nutritionalValue'].toString();
      return [
        Text("• $nutritionalValue"),
      ];
    }
    
    // Fallback to hardcoded values
    switch (widget.ingredientName.toLowerCase()) {
      case 'sayote':
        return [
          const Text("• Rich in Vitamin C – boosts immune system"),
          const Text("• Contains Folate (Vitamin B9)"),
          const Text("• Low in Calories – good for weight management"),
          const Text("• High in Fiber – supports digestion"),
        ];
      case 'chicken':
        return [
          const Text("• High in Protein – supports muscle growth"),
          const Text("• Rich in B Vitamins – supports energy production"),
          const Text("• Contains Selenium – antioxidant properties"),
        ];
      case 'petchay':
        return [
          const Text("• Rich in Vitamin A – supports eye health"),
          const Text("• Good source of Vitamin C – immune support"),
          const Text("• Contains Calcium – supports bone health"),
        ];
      default:
        return [const Text("Nutritional information not available")];
    }
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
          '₱${meal['price']?.toStringAsFixed(2) ?? '0.00'} • ${meal['calories']?.toString() ?? '0'} kcal'
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

// Add this method to your DatabaseHelper class if it doesn't exist
extension DatabaseHelperExtensions on DatabaseHelper {
  Future<List<Map<String, dynamic>>> getAllIngredients() async {
    final db = await database;
    return await db.query('ingredients');
  }
}