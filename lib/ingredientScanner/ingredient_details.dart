import 'package:flutter/material.dart';
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
        
        return mealName.contains(ingredientLower) ||
               categories.contains(ingredientLower) ||
               content.contains(ingredientLower);
      }).toList();

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.ingredientName,
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            fontSize: 20,
            letterSpacing: 1.1,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(2, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _ingredientFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFB5E48C),
                    Color(0xFF76C893),
                    Color(0xFF184E77),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFB5E48C),
                    Color(0xFF76C893),
                    Color(0xFF184E77),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          
          final ingredient = snapshot.data;
          final imagePath = ingredient?['ingredientPicture']?.toString() ?? 
                          'assets/default_ingredient.jpg';
          
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFB5E48C),
                  Color(0xFF76C893),
                  Color(0xFF184E77),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header image with gradient overlay
                      Stack(
                        children: [
                          SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF184E77),
                                child: const Icon(
                                  Icons.fastfood, 
                                  size: 100, 
                                  color: Colors.white70
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  const Color(0xFF184E77).withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Content
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ingredient Name
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF184E77),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF184E77).withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.ingredientName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Orbitron',
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            
                            // Details Card
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ingredient Details',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                        color: Color(0xFF184E77),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Cost Estimate
                                    _buildDetailRow(
                                      icon: Icons.monetization_on,
                                      iconColor: Colors.green,
                                      title: 'Estimated Cost',
                                      value: _getCostEstimate(ingredient),
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Calories
                                    _buildDetailRow(
                                      icon: Icons.local_fire_department,
                                      iconColor: Colors.orange,
                                      title: 'Calories',
                                      value: _getCalories(ingredient),
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Nutritional Value Section
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F2DF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFB5E48C).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Nutritional Value',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Orbitron',
                                              color: Color(0xFF184E77),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ..._getNutritionalInfo(ingredient),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Related Meals Section
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Related Meals',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                        color: Color(0xFF184E77),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    FutureBuilder<List<Map<String, dynamic>>>(
                                      future: _relatedMealsFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF184E77),
                                            ),
                                          );
                                        }
                                        
                                        if (snapshot.hasError) {
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F2DF),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Error loading related meals',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          );
                                        }
                                        
                                        final relatedMeals = snapshot.data ?? [];
                                        
                                        if (relatedMeals.isEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F2DF),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              children: [
                                                const Icon(
                                                  Icons.restaurant_menu,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'No meals found containing this ingredient',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 16,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        
                                        return SizedBox(
                                          height: 220,
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
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Subtle Footer
                            const Center(
                              child: Text(
                                'Discover more ingredients',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2DF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF184E77),
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF76C893),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF184E77),
                ),
              ),
            ),
          ],
        ),
      )).toList();
    }
    return [
      const Text(
        "Nutritional information not available",
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      )
    ];
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
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Image.asset(
                    imagePath,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: const Color(0xFFF3F2DF),
                      child: const Icon(Icons.fastfood, size: 40, color: Color(0xFF184E77)),
                    ),
                  ),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Meal Info
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
                      color: Color(0xFF184E77),
                      fontFamily: 'Orbitron',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5E48C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Php ${meal['price']?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(
                        color: Color(0xFF184E77),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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