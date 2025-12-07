import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

class UserCustomPage extends StatefulWidget {
  final int userId;

  const UserCustomPage({
    super.key, 
    required this.userId,
  });

  @override
  State<UserCustomPage> createState() => _UserCustomPageState();
}

class _UserCustomPageState extends State<UserCustomPage> {
  late Future<List<Map<String, dynamic>>> _mealsFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<int> _favoriteMealIds = {};

  @override
  void initState() {
    super.initState();
    _mealsFuture = _fetchMeals();
    _searchController.addListener(_onSearchChanged);
    if (widget.userId != 0) {
      _loadUserFavorites();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _loadUserFavorites() async {
    final user = await _dbHelper.getUserById(widget.userId);
    if (user != null && user['favorites'] != null) {
      final favorites = user['favorites'].toString();
      setState(() {
        _favoriteMealIds = favorites.split(',').where((id) => id.isNotEmpty).map(int.parse).toSet();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMeals() async {
    List<Map<String, dynamic>> customs = await _dbHelper.getUserCustomizedMeals(widget.userId);
    
    for (var custom in customs) {
      final original = await _dbHelper.getMealById(custom['original_meal_id']);
      
      if (original != null) {
        // Create a modifiable copy of the original meal
        var mutableMeal = Map<String, dynamic>.from(original);
        
        // Calculate the real cost dynamically
        double realCost = await _calculateRealMealCost(original['mealID']);
        if (realCost > 0) {
          mutableMeal['price'] = realCost;
        } else {
          mutableMeal['price'] = (original['price'] as num).toDouble();
        }

        custom['original_meal'] = mutableMeal;
      }
    }
    return customs.where((custom) => custom['original_meal'] != null).toList();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _toggleFavorite(int mealId) async {
    if (widget.userId == 0) return;
    
    try {
      final user = await _dbHelper.getUserById(widget.userId);
      if (user == null) return;

      final isFavorite = _favoriteMealIds.contains(mealId);
      final newFavorites = Set<int>.from(_favoriteMealIds);

      if (isFavorite) {
        newFavorites.remove(mealId);
      } else {
        newFavorites.add(mealId);
      }

      await _dbHelper.updateUser(widget.userId, {
        'favorites': newFavorites.join(','),
      });

      setState(() {
        _favoriteMealIds = newFavorites;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: ${e.toString()}')),
      );
    }
  }

  List<Map<String, dynamic>> _filterMealsByName(List<Map<String, dynamic>> meals, String query) {
    if (query.isEmpty) return meals;
    return meals.where((meal) {
      final name = meal['original_meal']['mealName'] ?? '';
      return name.toString().toLowerCase().contains(query);
    }).toList();
  }

  String _getTitle() {
    return "Customized Meals";
  }

  Widget _buildMealCard(Map<String, dynamic> custom) {
    final meal = custom['original_meal'];
    final name = meal['mealName'];
    final isFavorite = widget.userId != 0 && _favoriteMealIds.contains(meal['mealID']);
    final price = meal['price'] is double 
        ? (meal['price'] as double).toStringAsFixed(2)
        : meal['price']?.toString() ?? '0.00';

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
                    meal['mealPicture'] ?? 'assets/default_meal.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (widget.userId != 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(meal['mealID']),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white70,
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        color: Color(0xFF184E77),
                        fontFamily: 'Exo', // Updated to Exo
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
                          "Est. ${meal['cookingTime']}",
                          style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'Poppins'), // Updated to Poppins
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
                            fontFamily: 'Exo', // Updated to Exo for price emphasis
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
                            mealId: meal['mealID'],
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
                        fontFamily: 'Poppins', // Updated to Poppins
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
                          controller: _searchController,
                          style: const TextStyle(fontFamily: 'Poppins'), // Updated
                          decoration: InputDecoration(
                            hintText: 'Search ${_getTitle().toLowerCase()}',
                            hintStyle: const TextStyle(fontSize: 14, color: Colors.black54, fontFamily: 'Poppins'), // Updated
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Color(0xFF184E77)),
                                    onPressed: () {
                                      _searchController.clear();
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
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _mealsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Updated
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No customized meals available',
                          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Updated
                        ),
                      );
                    }

                    var filteredMeals = _filterMealsByName(snapshot.data!, _searchQuery);

                    if (filteredMeals.isEmpty) {
                      return const Center(
                        child: Text(
                          'No meals found matching your criteria',
                          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Updated
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12.0),
                      itemCount: filteredMeals.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        return _buildMealCard(filteredMeals[index]);
                      },
                    );
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