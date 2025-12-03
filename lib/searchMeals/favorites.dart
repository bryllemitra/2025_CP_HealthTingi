import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

class FavoritesPage extends StatefulWidget {
  final int userId;

  const FavoritesPage({super.key, required this.userId});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> favoriteRecipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    searchController.addListener(_filterFavorites);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // --- START NEW PRICE LOGIC ---
  double _parseQuantity(String quantityStr) {
    if (quantityStr.contains('.') && double.tryParse(quantityStr) != null) {
      return double.parse(quantityStr);
    }
    
    final fractionMap = {
      '⅛': 0.125, '¼': 0.25, '⅓': 0.333, '⅜': 0.375,
      '½': 0.5, '⅝': 0.625, '⅔': 0.666, '¾': 0.75, '⅞': 0.875
    };
    
    if (fractionMap.containsKey(quantityStr.trim())) {
      return fractionMap[quantityStr.trim()]!;
    }
    
    if (quantityStr.contains('/')) {
      List<String> parts = quantityStr.split('/');
      if (parts.length == 2) {
        double numerator = double.tryParse(parts[0].trim()) ?? 1.0;
        double denominator = double.tryParse(parts[1].trim()) ?? 1.0;
        return numerator / denominator;
      }
    }
    return double.tryParse(quantityStr) ?? 1.0;
  }

  Future<double> _calculateRealMealCost(int mealId) async {
    double total = 0.0;
    
    final originalIngredients = await _dbHelper.getMealIngredients(mealId);
    Map<String, dynamic> subs = {};
    
    if (widget.userId != 0) {
      final customizedMeal = await _dbHelper.getActiveCustomizedMeal(mealId, widget.userId);
      if (customizedMeal != null) {
        subs = customizedMeal['substituted_ingredients'] ?? {};
      }
    }

    for (var ing in originalIngredients) {
      String name = ing['ingredientName']?.toString() ?? '';

      if (subs.containsKey(name)) {
        final subData = subs[name];
        String type = subData['type'];

        if (type == 'removed') {
          continue; 
        } 
        else if (type == 'substituted') {
          String newName = subData['value'];
          String qtyStr = subData['quantity'] ?? '1 piece';
          
          double qty = 1.0;
          String unit = 'piece';
          final match = RegExp(r'^((?:\d*\.?\d+)|(?:\d+\s*/\s*\d+)|[⅛¼⅓⅜½⅝⅔¾⅞])\s*(.*)$').firstMatch(qtyStr);
          if (match != null) {
             qty = _parseQuantity(match.group(1) ?? '1');
             unit = match.group(2)?.trim() ?? 'piece';
          }

          final newIng = await _dbHelper.getIngredientByName(newName);
          if (newIng != null) {
             double grams = _dbHelper.convertToGrams(qty, unit, newIng);
             double baseGrams = _dbHelper.convertToGrams(1.0, newIng['unit'] ?? 'piece', newIng);
             double price = newIng['price'] as double? ?? 0.0;
             
             if (baseGrams > 0) {
               total += (grams * price) / baseGrams;
             }
          }
          continue; 
        }
      }

      double price = ing['price'] as double? ?? 0.0;
      double qty = _parseQuantity(ing['quantity']?.toString() ?? '0');
      String unit = ing['unit']?.toString() ?? 'piece';
      String baseUnit = ing['base_unit']?.toString() ?? ing['unit']?.toString() ?? 'piece'; 

      double grams = _dbHelper.convertToGrams(qty, unit, ing);
      double baseGrams = _dbHelper.convertToGrams(1.0, baseUnit, ing);
      
      if (baseGrams > 0) {
        total += (grams * price) / baseGrams;
      }
    }

    for (var entry in subs.entries) {
      if (entry.value['type'] == 'new') {
        String name = entry.key;
        String qtyStr = entry.value['quantity'] ?? '1 piece';

        double qty = 1.0;
        String unit = 'piece';
        final match = RegExp(r'^((?:\d*\.?\d+)|(?:\d+\s*/\s*\d+)|[⅛¼⅓⅜½⅝⅔¾⅞])\s*(.*)$').firstMatch(qtyStr);
        if (match != null) {
           qty = _parseQuantity(match.group(1) ?? '1');
           unit = match.group(2)?.trim() ?? 'piece';
        }

        final newIng = await _dbHelper.getIngredientByName(name);
        if (newIng != null) {
           double grams = _dbHelper.convertToGrams(qty, unit, newIng);
           double baseGrams = _dbHelper.convertToGrams(1.0, newIng['unit'] ?? 'piece', newIng);
           double price = newIng['price'] as double? ?? 0.0;

           if (baseGrams > 0) {
             total += (grams * price) / baseGrams;
           }
        }
      }
    }

    return total;
  }
  // --- END NEW PRICE LOGIC ---

  Future<void> _loadFavorites() async {
    try {
      final user = await _dbHelper.getUserById(widget.userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      final favorites = user['favorites']?.toString() ?? '';
      if (favorites.isEmpty) {
        setState(() {
          isLoading = false;
          favoriteRecipes = [];
          filteredRecipes = [];
        });
        return;
      }

      final favoriteIds = favorites.split(',').map((id) => int.parse(id)).toList();
      final allMeals = await _dbHelper.getAllMeals();
      
      // 1. Filter favorites first
      final favMeals = allMeals.where((meal) {
        return favoriteIds.contains(meal['mealID']);
      }).toList();

      List<Map<String, dynamic>> updatedMeals = [];

      // 2. Calculate prices
      for (var meal in favMeals) {
        var mealMap = Map<String, dynamic>.from(meal);
        double calculatedPrice = await _calculateRealMealCost(meal['mealID']);
        
        if (calculatedPrice > 0) {
          mealMap['price'] = calculatedPrice;
        } else {
          mealMap['price'] = (meal['price'] as num).toDouble();
        }
        updatedMeals.add(mealMap);
      }
      
      setState(() {
        favoriteRecipes = updatedMeals;
        filteredRecipes = List.from(favoriteRecipes);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load favorites: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(int mealId, bool isCurrentlyFavorite) async {
    try {
      final user = await _dbHelper.getUserById(widget.userId);
      
      if (user == null) return;

      String favorites = user['favorites']?.toString() ?? '';
      List<String> favoriteList = favorites.split(',').where((id) => id.isNotEmpty).toList();

      if (isCurrentlyFavorite) {
        favoriteList.remove(mealId.toString());
      } else {
        favoriteList.add(mealId.toString());
      }

      await _dbHelper.updateUser(widget.userId, {
        'favorites': favoriteList.join(','),
      });

      await _loadFavorites();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: ${e.toString()}')),
      );
    }
  }

  void _filterFavorites() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredRecipes = List.from(favoriteRecipes);
      } else {
        filteredRecipes = favoriteRecipes.where((recipe) {
          final name = recipe['mealName'].toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Widget _buildMealCard(Map<String, dynamic> recipe) {
    final price = recipe['price'] is double 
        ? (recipe['price'] as double).toStringAsFixed(2)
        : recipe['price']?.toString() ?? '0.00';

    return Container(
      width: 160,
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: Image.asset(
                    recipe['mealPicture'] ?? 'assets/default_meal.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () async {
                    await _toggleFavorite(recipe['mealID'], true);
                  },
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      recipe['mealName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        color: Color(0xFF184E77),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: Color(0xFF184E77)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Est. ${recipe['cookingTime']}",
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Php $price",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB5E48C),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size.fromHeight(30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MealDetailsPage(
                            mealId: recipe['mealID'],
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "VIEW INSTRUCTIONS",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search your favorite recipes',
                            hintStyle: const TextStyle(fontSize: 14, color: Colors.black54),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Color(0xFF184E77)),
                                    onPressed: () {
                                      searchController.clear();
                                    },
                                  )
                                : const Icon(Icons.search, color: Color(0xFF184E77)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                        ? Center(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : favoriteRecipes.isEmpty
                            ? const Center(
                                child: Text(
                                  'No favorites yet',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(12.0),
                                itemCount: filteredRecipes.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 260,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                itemBuilder: (context, index) {
                                  return _buildMealCard(filteredRecipes[index]);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}