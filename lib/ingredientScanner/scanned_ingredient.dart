import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'ingredient_details.dart';
import '../pages/meal_scan.dart';
import '../pages/meal_details.dart';
import '../database/db_helper.dart';

class ScannedIngredientPage extends StatefulWidget {
  final int userId;
  final List<String>? detectedIngredients;

  const ScannedIngredientPage({
    super.key, 
    required this.userId,
    this.detectedIngredients,
  });

  @override
  State<ScannedIngredientPage> createState() => _ScannedIngredientPageState();
}

class _ScannedIngredientPageState extends State<ScannedIngredientPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late List<String> ingredients;
  Map<String, Map<String, dynamic>> _ingredientDetails = {};
  List<Map<String, dynamic>> allIngredients = [];
  List<Map<String, dynamic>> suggestedGroups = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoadingRecipes = false;
  
  // NEW: Debounce timer for search
  Timer? _searchDebounce;
  // NEW: Cache for search results
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  @override
  void initState() {
    super.initState();
    ingredients = widget.detectedIngredients ?? ['Chicken', 'Sayote', 'Petchay'];
    _loadAllIngredients();
    _loadIngredientDetails();
    _loadRecipeSuggestions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllIngredients() async {
    try {
      final loadedIngredients = await _dbHelper.getAllIngredients();
      setState(() {
        allIngredients = loadedIngredients;
      });
    } catch (e) {
      print('Error loading all ingredients: $e');
    }
  }

  Future<void> _loadIngredientDetails() async {
    for (var ingredientName in ingredients) {
      try {
        final detail = await _dbHelper.getIngredientByName(ingredientName);
        if (detail != null) {
          setState(() {
            _ingredientDetails[ingredientName] = detail;
          });
        }
      } catch (e) {
        print('Error loading details for $ingredientName: $e');
      }
    }
  }

  // NEW: Optimized search handler with debouncing
  void _onSearchChanged(String value) {
    // Cancel previous timer if it exists
    _searchDebounce?.cancel();
    
    // Set new timer for debouncing
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchQuery != value) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
  }

  // NEW: Optimized filtered ingredients with caching
  List<Map<String, dynamic>> get filteredIngredients {
    if (_searchQuery.isEmpty) return [];
    
    // Check cache first
    if (_searchCache.containsKey(_searchQuery)) {
      return _searchCache[_searchQuery]!;
    }
    
    final lowerQuery = _searchQuery.toLowerCase();
    final lowerExisting = ingredients.map((i) => i.toLowerCase()).toSet();
    
    final results = allIngredients.where((ing) {
      final name = ing['ingredientName']?.toString().toLowerCase() ?? '';
      return name.contains(lowerQuery) && !lowerExisting.contains(name);
    }).toList();
    
    // Cache the results
    _searchCache[_searchQuery] = results;
    
    // Limit cache size to prevent memory issues
    if (_searchCache.length > 20) {
      final firstKey = _searchCache.keys.first;
      _searchCache.remove(firstKey);
    }
    
    return results;
  }

  // NEW: Enhanced recipe suggestion algorithm with first ingredient priority
  Future<void> _loadRecipeSuggestions() async {
    setState(() {
      _isLoadingRecipes = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final allMeals = await dbHelper.getAllMeals();
      final user = widget.userId != 0 ? await dbHelper.getUserById(widget.userId) : null;
      final userRestriction = user != null && (user['hasDietaryRestriction'] ?? 0) == 1
          ? user['dietaryRestriction']?.toString().toLowerCase().trim() ?? ''
          : '';

      Map<int, List<Map<String, dynamic>>> multiGroups = {};
      Map<String, List<Map<String, dynamic>>> singleGroups = {};

      for (var meal in allMeals) {
        final mealIngredients = await dbHelper.getMealIngredients(meal['mealID']);
        
        // NEW: Check if meal has ingredients and get the first one
        String? firstIngredientName;
        if (mealIngredients.isNotEmpty) {
          firstIngredientName = mealIngredients.first['ingredientName']?.toString().toLowerCase();
        }

        final mealIngredientNames = mealIngredients
            .map((ing) => ing['ingredientName']?.toString().toLowerCase())
            .where((name) => name != null)
            .toSet();

        final matchingIng = ingredients.where((ing) => mealIngredientNames.contains(ing.toLowerCase())).toList();
        final matchingIngredients = matchingIng.length;

        if (matchingIngredients > 0) {
          final mealRestrictionsString = meal['hasDietaryRestrictions']?.toString().toLowerCase() ?? '';
          final mealRestrictions = mealRestrictionsString.split(',').map((r) => r.trim()).toList();
          final hasConflict = userRestriction.isNotEmpty &&
              mealRestrictions.any((mealRestriction) =>
                  mealRestriction.contains(userRestriction) ||
                  userRestriction.contains(mealRestriction));

          // NEW: Calculate if scanned ingredient is the FIRST ingredient in the meal
          bool isMainIngredient = false;
          for (var scannedIng in matchingIng) {
            final scannedIngLower = scannedIng.toLowerCase();
            // Check if this scanned ingredient is the FIRST ingredient in the meal
            if (firstIngredientName != null && firstIngredientName == scannedIngLower) {
              isMainIngredient = true;
              break;
            }
          }

          final recipeData = {
            ...meal,
            'matchingIngredients': matchingIngredients,
            'matchingList': matchingIng,
            'hasConflict': hasConflict,
            'isMainIngredient': isMainIngredient, // NEW: Flag for main ingredient (first in list)
            'firstIngredient': firstIngredientName, // NEW: Store for debugging/display
          };

          if (matchingIngredients > 1) {
            multiGroups.putIfAbsent(matchingIngredients, () => []).add(recipeData);
          } else if (matchingIngredients == 1) {
            final ing = matchingIng[0];
            singleGroups.putIfAbsent(ing, () => []).add(recipeData);
          }
        }
      }

      List<Map<String, dynamic>> orderedGroups = [];

      // Sort multi groups by match count descending, then by main ingredient priority
      final matchKeys = multiGroups.keys.toList()..sort((a, b) => b.compareTo(a));
      for (var key in matchKeys) {
        var groupRecipes = multiGroups[key]!;
        
        // NEW: Enhanced sorting - prioritize meals where scanned ingredients are FIRST ingredients
        groupRecipes.sort((a, b) {
          // First, prioritize meals where scanned ingredients are first ingredients
          if (a['isMainIngredient'] && !b['isMainIngredient']) return -1;
          if (!a['isMainIngredient'] && b['isMainIngredient']) return 1;
          
          // Then, prioritize meals without dietary conflicts
          if (a['hasConflict'] && !b['hasConflict']) return 1;
          if (!a['hasConflict'] && b['hasConflict']) return -1;
          
          return 0;
        });
        
        // NEW: Limit to 5 meals per group
        if (groupRecipes.length > 5) {
          groupRecipes = groupRecipes.sublist(0, 5);
        }
        
        orderedGroups.add({
          'type': 'multi',
          'matchCount': key,
          'recipes': groupRecipes,
        });
      }

      // Add single groups in order of ingredients
      for (var ing in ingredients) {
        var groupRecipes = singleGroups[ing] ?? [];
        
        // NEW: Enhanced sorting for single groups - prioritize if this ingredient is FIRST
        groupRecipes.sort((a, b) {
          final ingLower = ing.toLowerCase();
          
          // Check if this specific ingredient is the FIRST ingredient in each meal
          final isFirstIngredientA = a['firstIngredient'] == ingLower;
          final isFirstIngredientB = b['firstIngredient'] == ingLower;
          
          // First, prioritize meals where this specific ingredient is the FIRST ingredient
          if (isFirstIngredientA && !isFirstIngredientB) return -1;
          if (!isFirstIngredientA && isFirstIngredientB) return 1;
          
          // Then, prioritize meals without dietary conflicts
          if (a['hasConflict'] && !b['hasConflict']) return 1;
          if (!a['hasConflict'] && b['hasConflict']) return -1;
          
          return 0;
        });
        
        // NEW: Limit to 5 meals per group
        if (groupRecipes.length > 5) {
          groupRecipes = groupRecipes.sublist(0, 5);
        }
        
        orderedGroups.add({
          'type': 'single',
          'ingredient': ing,
          'recipes': groupRecipes,
        });
      }

      setState(() {
        suggestedGroups = orderedGroups;
      });
    } catch (e) {
      print('Error loading recipe suggestions: $e');
    } finally {
      setState(() {
        _isLoadingRecipes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = screenHeight * 0.5;

    return Scaffold(
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
              // Fixed Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MealScanPage(userId: widget.userId),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "Scanned Ingredients",
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Search Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F2DF),
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
                            const Text(
                              "Can't find an ingredient?",
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 14,
                                color: Color(0xFF184E77),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search, color: Color(0xFF184E77)),
                                  hintText: "Search ingredients...",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onChanged: _onSearchChanged,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_searchQuery.isNotEmpty && filteredIngredients.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                              const Text(
                                "Search Results",
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF184E77),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...filteredIngredients.take(10).map((ing) {
                                final name = ing['ingredientName'] as String;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F2DF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB5E48C),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: ing['ingredientPicture'] != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(20),
                                              child: Image.asset(
                                                ing['ingredientPicture'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.fastfood, size: 20, color: Color(0xFF184E77)),
                                              ),
                                            )
                                          : const Icon(Icons.fastfood, size: 20, color: Color(0xFF184E77)),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Orbitron',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF184E77),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${ing['calories'] ?? 'N/A'} kcal',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF184E77),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        ingredients.add(name);
                                        _ingredientDetails[name] = ing;
                                        _searchController.clear();
                                        _searchQuery = '';
                                        _searchCache.clear();
                                        _loadRecipeSuggestions();
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                              if (filteredIngredients.length > 10)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '... and ${filteredIngredients.length - 10} more results',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Detected Ingredients Section
                      Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Detected Ingredients",
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Color(0xFF184E77),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: ingredients.map((ingredient) {
                                final detail = _ingredientDetails[ingredient];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => IngredientDetailsPage(
                                          userId: widget.userId,
                                          ingredientName: ingredient,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F2DF),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: const Color(0xFFB5E48C).withOpacity(0.4),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (detail?['ingredientPicture'] != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.asset(
                                              detail!['ingredientPicture'],
                                              width: 24,
                                              height: 24,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 16, color: Color(0xFF184E77)),
                                            ),
                                          )
                                        else
                                          const Icon(Icons.fastfood, size: 16, color: Color(0xFF184E77)),
                                        const SizedBox(width: 8),
                                        Text(
                                          ingredient,
                                          style: const TextStyle(
                                            fontFamily: 'Orbitron',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF184E77),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (detail != null)
                                          Text(
                                            '${detail['calories'] ?? 'N/A'} kcal',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Recipe Suggestions Section
                      Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Recipe Suggestions",
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Color(0xFF184E77),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _isLoadingRecipes
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF184E77),
                                    ),
                                  )
                                : suggestedGroups.isEmpty
                                    ? Container(
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
                                              'No recipes found for the selected ingredients.',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey,
                                                fontFamily: 'Orbitron',
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: suggestedGroups.length,
                                        itemBuilder: (context, groupIndex) {
                                          final group = suggestedGroups[groupIndex];
                                          final recipes = group['recipes'] as List<Map<String, dynamic>>;
                                          String header;
                                          if (group['type'] == 'multi') {
                                            header = "Recipes with ${group['matchCount']} matching ingredients";
                                          } else {
                                            header = "Recipes with ${group['ingredient']}";
                                          }

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(bottom: 16),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF184E77),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  header,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontFamily: 'Orbitron',
                                                  ),
                                                ),
                                              ),
                                              
                                              if (recipes.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(vertical: 20),
                                                  child: Text(
                                                    'No recipes found',
                                                    style: TextStyle(fontSize: 14, color: Colors.grey),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                )
                                              else
                                                CarouselSlider.builder(
                                                  itemCount: recipes.length,
                                                  itemBuilder: (context, index, realIndex) {
                                                    final recipe = recipes[index];
                                                    return Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 8),
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
                                                        children: [
                                                          // Recipe Image
                                                          ClipRRect(
                                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                            child: Stack(
                                                              children: [
                                                                Image.asset(
                                                                  recipe['mealPicture'] ?? 'assets/placeholder.jpg',
                                                                  width: double.infinity,
                                                                  height: 120,
                                                                  fit: BoxFit.cover,
                                                                  errorBuilder: (context, error, stackTrace) =>
                                                                      Container(
                                                                        width: double.infinity,
                                                                        height: 120,
                                                                        color: const Color(0xFFF3F2DF),
                                                                        child: const Icon(Icons.restaurant, size: 40, color: Color(0xFF184E77)),
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
                                                                // NEW: Main Ingredient Badge
                                                                if (recipe['isMainIngredient'])
                                                                  Positioned(
                                                                    top: 8,
                                                                    right: 8,
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.green.withOpacity(0.9),
                                                                        borderRadius: BorderRadius.circular(12),
                                                                      ),
                                                                      child: const Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          Icon(Icons.star, size: 12, color: Colors.white),
                                                                          SizedBox(width: 4),
                                                                          Text(
                                                                            'Main Ingredient',
                                                                            style: TextStyle(
                                                                              fontSize: 10,
                                                                              color: Colors.white,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                          
                                                          // Recipe Info
                                                          Padding(
                                                            padding: const EdgeInsets.all(16),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    const Icon(Icons.schedule, size: 14, color: Color(0xFF184E77)),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      '~${recipe['cookingTime']}',
                                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF184E77)),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Text(
                                                                  recipe['mealName'],
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
                                                                Text(
                                                                  recipe['content'] ?? 'No description available',
                                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                if (recipe['hasConflict']) ...[
                                                                  const SizedBox(height: 8),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.orange.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(6),
                                                                      border: Border.all(color: Colors.orange),
                                                                    ),
                                                                    child: Text(
                                                                      '⚠️ Conflicts with dietary restriction',
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        color: Colors.orange[700],
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                                const SizedBox(height: 12),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        '${recipe['matchingIngredients']} matching ingredient${recipe['matchingIngredients'] == 1 ? '' : 's'}',
                                                                        style: const TextStyle(
                                                                          fontSize: 12,
                                                                          color: Colors.grey,
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                    ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: const Color(0xFF184E77),
                                                                        foregroundColor: Colors.white,
                                                                        elevation: 3,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(12),
                                                                        ),
                                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                                      ),
                                                                      onPressed: () {
                                                                        Navigator.push(
                                                                          context,
                                                                          MaterialPageRoute(
                                                                            builder: (context) => MealDetailsPage(
                                                                              userId: widget.userId,
                                                                              mealId: recipe['mealID'],
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                      child: const Text(
                                                                        'View Recipe',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          fontFamily: 'Orbitron',
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  options: CarouselOptions(
                                                    height: carouselHeight.clamp(350.0, 400.0),
                                                    enlargeCenterPage: true,
                                                    viewportFraction: 0.85,
                                                    enableInfiniteScroll: recipes.length > 1,
                                                    autoPlay: recipes.length > 1,
                                                  ),
                                                ),
                                              const SizedBox(height: 24),
                                            ],
                                          );
                                        },
                                      ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      
                      // Subtle Footer
                      const Center(
                        child: Text(
                          'Discover delicious recipes with your ingredients',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}