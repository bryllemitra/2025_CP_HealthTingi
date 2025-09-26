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
      backgroundColor: const Color(0xFFEDEBD1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEBD1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MealScanPage(userId: widget.userId),
              ),
            );
          },
        ),
        title: const Text(
          "Scanned Ingredients",
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          children: [
            const Text(
              "Can't find an ingredient? Search here:",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: "Search ingredients...",
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (_searchQuery.isNotEmpty && filteredIngredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Search Results",
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredIngredients.length,
                itemBuilder: (context, index) {
                  final ing = filteredIngredients[index];
                  final name = ing['ingredientName'] as String;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: ing['ingredientPicture'] != null
                          ? AssetImage(ing['ingredientPicture'])
                          : null,
                      onBackgroundImageError: (_, __) => const Icon(Icons.fastfood, size: 20),
                      child: ing['ingredientPicture'] == null
                          ? const Icon(Icons.fastfood, size: 20)
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text('${ing['calories'] ?? 'N/A'} kcal'),
                    trailing: const Icon(Icons.add),
                    onTap: () {
                      setState(() {
                        ingredients.add(name);
                        _ingredientDetails[name] = ing;
                        _searchController.clear();
                        _searchQuery = '';
                        _loadRecipeSuggestions(); // Reload suggestions when new ingredient is added
                      });
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              "Detected Ingredients",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(thickness: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                final detail = _ingredientDetails[ingredient];
                
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: detail?['ingredientPicture'] != null
                            ? Image.asset(
                                detail!['ingredientPicture'],
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.fastfood, size: 20),
                              )
                            : const Icon(Icons.fastfood, size: 20),
                      ),
                      title: Text(
                        ingredient,
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                    const Divider(thickness: 1, height: 1),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              "Recipe Suggestions",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            _isLoadingRecipes
                ? const Center(child: CircularProgressIndicator())
                : suggestedGroups.isEmpty
                    ? const Center(
                        child: Text(
                          'No recipes found for the selected ingredients.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
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
                              Text(
                                header,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (recipes.isEmpty)
                                const Text(
                                  'No recipes found',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                )
                              else
                                CarouselSlider.builder(
                                  itemCount: recipes.length,
                                  itemBuilder: (context, index, realIndex) {
                                    final recipe = recipes[index];
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            offset: Offset(2, 2),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '~${recipe['cookingTime']}',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  recipe['mealName'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  recipe['content'] ?? 'No description available',
                                                  style: const TextStyle(fontSize: 12),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (recipe['hasConflict']) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '⚠️ Conflicts with your dietary restriction',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.orange[700],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 8),
                                                Text(
                                                  '${recipe['matchingIngredients']} matching ingredient${recipe['matchingIngredients'] == 1 ? '' : 's'}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFEEF864),
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 2),
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
                                                    'View Recipe →',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.asset(
                                              recipe['mealPicture'] ?? 'assets/placeholder.jpg',
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Container(
                                                    width: 100,
                                                    height: 100,
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons.restaurant, size: 40),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  options: CarouselOptions(
                                    height: 220,
                                    enlargeCenterPage: true,
                                    viewportFraction: 0.9,
                                    enableInfiniteScroll: recipes.length > 1,
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}