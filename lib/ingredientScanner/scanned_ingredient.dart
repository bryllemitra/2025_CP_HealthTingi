import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    ingredients = widget.detectedIngredients ?? ['Chicken', 'Sayote', 'Petchay'];
    _loadAllIngredients();
    _loadIngredientDetails();
    _loadRecipeSuggestions();
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

          final recipeData = {
            ...meal,
            'matchingIngredients': matchingIngredients,
            'matchingList': matchingIng,
            'hasConflict': hasConflict,
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

      // Sort multi groups by match count descending
      final matchKeys = multiGroups.keys.toList()..sort((a, b) => b.compareTo(a));
      for (var key in matchKeys) {
        var groupRecipes = multiGroups[key]!;
        groupRecipes.sort((a, b) {
          if (a['hasConflict'] && !b['hasConflict']) return 1;
          if (!a['hasConflict'] && b['hasConflict']) return -1;
          return 0;
        });
        orderedGroups.add({
          'type': 'multi',
          'matchCount': key,
          'recipes': groupRecipes,
        });
      }

      // Add single groups in order of ingredients
      for (var ing in ingredients) {
        var groupRecipes = singleGroups[ing] ?? [];
        groupRecipes.sort((a, b) {
          if (a['hasConflict'] && !b['hasConflict']) return 1;
          if (!a['hasConflict'] && b['hasConflict']) return -1;
          return 0;
        });
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

  List<Map<String, dynamic>> get filteredIngredients {
    if (_searchQuery.isEmpty) return [];
    final lowerQuery = _searchQuery.toLowerCase();
    final lowerExisting = ingredients.map((i) => i.toLowerCase()).toSet();
    return allIngredients.where((ing) {
      final name = ing['ingredientName']?.toString().toLowerCase() ?? '';
      return name.contains(lowerQuery) && !lowerExisting.contains(name);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(width: 48), // For balance
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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView(
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
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  },
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
                                ...filteredIngredients.map((ing) {
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
                                          _loadRecipeSuggestions();
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
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
                              ...ingredients.asMap().entries.map((entry) {
                                final index = entry.key;
                                final ingredient = entry.value;
                                final detail = _ingredientDetails[ingredient];
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F2DF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFB5E48C).withOpacity(0.3),
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB5E48C),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: detail?['ingredientPicture'] != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(25),
                                              child: Image.asset(
                                                detail!['ingredientPicture'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.fastfood, size: 24, color: Color(0xFF184E77)),
                                              ),
                                            )
                                          : const Icon(Icons.fastfood, size: 24, color: Color(0xFF184E77)),
                                    ),
                                    title: Text(
                                      ingredient,
                                      style: const TextStyle(
                                        fontFamily: 'Orbitron',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF184E77),
                                      ),
                                    ),
                                    subtitle: detail != null
                                        ? Text(
                                            '${detail['calories'] ?? 'N/A'} kcal',
                                            style: const TextStyle(fontSize: 12),
                                          )
                                        : const Text(
                                            'Loading details...',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                    trailing: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF184E77),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                                    ),
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
                                  ),
                                );
                              }).toList(),
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
                                                                      Text(
                                                                        '${recipe['matchingIngredients']} matching ingredient${recipe['matchingIngredients'] == 1 ? '' : 's'}',
                                                                        style: const TextStyle(
                                                                          fontSize: 12,
                                                                          color: Colors.grey,
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
                                                      height: 320,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}