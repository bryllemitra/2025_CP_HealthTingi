import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'meal_details.dart'; // Import your meal details page

class ReverseIngredientPage extends StatefulWidget {
  final List<String>? ingredients;
  final int userId; // Add userId for navigation

  const ReverseIngredientPage({super.key, this.ingredients, required this.userId});

  @override
  State<ReverseIngredientPage> createState() => _ReverseIngredientPageState();
}

class _ReverseIngredientPageState extends State<ReverseIngredientPage> {
  late List<String> allIngredients;
  Set<String> crossedOutIngredients = {};
  List<Map<String, dynamic>> recentChanges = [];
  Map<String, String?> selectedAlternatives = {};
  Map<String, String> ingredientDisplay = {};
  bool showAlternatives = false;
  Map<String, List<String>> ingredientAlternatives = {};
  
  // Dynamic similar meals loaded from database
  List<Map<String, dynamic>> similarMeals = [];
  bool isLoadingSimilarMeals = false;
  
  // Add ingredient functionality
  bool showAddIngredient = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> availableIngredients = [];
  List<Map<String, dynamic>> filteredIngredients = [];
  bool isLoadingIngredients = false;

  @override
  void initState() {
    super.initState();
    allIngredients = widget.ingredients ?? [
      'Sayote',
      'Bagoong',
      'Small Onion',
      'Garlic',
      'Tomato',
      'Oil',
      'Soy Sauce',
    ];
    selectedAlternatives = {};
    ingredientDisplay = {};
    _loadIngredientAlternatives();
    _loadSimilarMeals();
    _loadAvailableIngredients(); // Load all available ingredients
  }

  Future<void> _loadAvailableIngredients() async {
    if (mounted) {
      setState(() {
        isLoadingIngredients = true;
      });
    }

    try {
      final dbHelper = DatabaseHelper();
      final ingredients = await dbHelper.getAllIngredients();
      
      if (mounted) {
        setState(() {
          availableIngredients = ingredients;
          filteredIngredients = ingredients;
          isLoadingIngredients = false;
        });
      }
    } catch (e) {
      print('Error loading ingredients: $e');
      if (mounted) {
        setState(() {
          isLoadingIngredients = false;
        });
      }
    }
  }

  void _filterIngredients(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredIngredients = availableIngredients;
      });
      return;
    }

    setState(() {
      filteredIngredients = availableIngredients.where((ingredient) {
        final name = ingredient['ingredientName']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _addIngredient(String ingredientName) {
    if (!allIngredients.contains(ingredientName)) {
      setState(() {
        allIngredients.add(ingredientName);
        _searchController.clear();
        showAddIngredient = false;
      });
      
      // Reload similar meals with new ingredient
      _loadSimilarMeals();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $ingredientName', style: TextStyle(fontFamily: 'Orbitron')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.add(ingredient);
      recentChanges.add({'type': 'remove', 'ingredient': ingredient});

      if (ingredientAlternatives.containsKey(ingredient)) {
        showAlternatives = true;
      }
    });

    _loadSimilarMeals();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          recentChanges.removeWhere((change) =>
              change['type'] == 'remove' && change['ingredient'] == ingredient);
        });
      }
    });
  }

  void _undoRemoveIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.remove(ingredient);

      if (!crossedOutIngredients.any((ing) => ingredientAlternatives.containsKey(ing))) {
        showAlternatives = false;
      }
    });

    _loadSimilarMeals();
  }

  void _setReplacement(String original, String alt) {
    setState(() {
      selectedAlternatives[original] = alt;
      ingredientDisplay[original] = alt;
      crossedOutIngredients.remove(original);
      recentChanges.add({'type': 'replace', 'original': original, 'alt': alt});
    });

    _loadSimilarMeals();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          recentChanges.removeWhere((change) =>
              change['type'] == 'replace' && change['original'] == original);
        });
      }
    });
  }

  void _undoReplace(String original) {
    setState(() {
      selectedAlternatives.remove(original);
      ingredientDisplay.remove(original);
      crossedOutIngredients.remove(original);

      if (!crossedOutIngredients.any((ing) => ingredientAlternatives.containsKey(ing))) {
        showAlternatives = false;
      }
    });

    _loadSimilarMeals();
  }

  Future<void> _loadIngredientAlternatives() async {
    final dbHelper = DatabaseHelper();
    for (final ingredient in allIngredients) {
      final alts = await dbHelper.getAlternatives(ingredient);
      if (alts.isNotEmpty) {
        ingredientAlternatives[ingredient] = alts;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSimilarMeals() async {
    if (mounted) {
      setState(() {
        isLoadingSimilarMeals = true;
      });
    }

    try {
      final dbHelper = DatabaseHelper();
      final availableIngredients = allIngredients
          .where((ingredient) => !crossedOutIngredients.contains(ingredient))
          .toList();
      
      final similar = await dbHelper.getSimilarMeals(availableIngredients, limit: 6);
      
      if (mounted) {
        setState(() {
          similarMeals = similar;
          isLoadingSimilarMeals = false;
        });
      }
    } catch (e) {
      print('Error loading similar meals: $e');
      if (mounted) {
        setState(() {
          isLoadingSimilarMeals = false;
          similarMeals = [];
        });
      }
    }
  }

  void _navigateToMealDetails(Map<String, dynamic> meal) {
    final mealId = meal['mealID'];
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open meal details', style: TextStyle(fontFamily: 'Orbitron')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAddIngredientSection() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add More Ingredients',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF184E77),
                    shadows: [
                      Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF184E77)),
                  onPressed: () {
                    setState(() {
                      showAddIngredient = false;
                      _searchController.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                hintStyle: const TextStyle(fontFamily: 'Orbitron', color: Colors.black54),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF184E77)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF76C893)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF76C893), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: _filterIngredients,
            ),
            const SizedBox(height: 12),
            if (isLoadingIngredients)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF76C893)),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredIngredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = filteredIngredients[index];
                    final ingredientName = ingredient['ingredientName']?.toString() ?? 'Unknown';
                    final isAlreadyAdded = allIngredients.contains(ingredientName);
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ingredient['ingredientPicture'] != null
                          ? Image.asset(
                              ingredient['ingredientPicture']!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                  const Icon(Icons.fastfood, color: Color(0xFF76C893)),
                            )
                          : const Icon(Icons.fastfood, color: Color(0xFF76C893)),
                      title: Text(
                        ingredientName,
                        style: const TextStyle(fontFamily: 'Orbitron', color: Color(0xFF184E77)),
                      ),
                      subtitle: Text(
                        'Php ${ingredient['price']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Color(0xFF76C893)),
                      ),
                      trailing: isAlreadyAdded
                          ? const Text(
                              'Added',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                color: Color(0xFF76C893),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () => _addIngredient(ingredientName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF184E77),
                                elevation: 10,
                                shadowColor: Colors.greenAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarMealsSection() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meals with Similar Ingredients',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF184E77),
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on your current ingredients',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12,
                color: Colors.black54,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            if (isLoadingSimilarMeals)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF76C893)),
                  ),
                ),
              )
            else if (similarMeals.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No similar meals found',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 14,
                      color: Colors.black54,
                      shadows: [
                        Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...similarMeals.map((meal) {
                final matchingCount = meal['matching_ingredients'] ?? 0;
                final totalCount = meal['total_ingredients'] ?? 1;
                final matchPercentage = meal['match_percentage'] ?? 0;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: meal['mealPicture'] != null
                        ? Image.asset(
                            meal['mealPicture']!,
                            width: 60,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildMealPlaceholder(),
                          )
                        : _buildMealPlaceholder(),
                  ),
                  title: Text(
                    meal['mealName'] ?? 'Unknown Meal',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${matchPercentage.toStringAsFixed(0)}% match',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          color: Color(0xFF76C893),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$matchingCount/$totalCount ingredients',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF184E77)),
                  onTap: () => _navigateToMealDetails(meal),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlaceholder() {
    return Container(
      width: 60,
      height: 50,
      color: Colors.white.withOpacity(0.1),
      child: const Icon(Icons.fastfood, size: 24, color: Color(0xFF76C893)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [
            Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
          ]),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reverse Ingredients',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 24,
            shadows: [
              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFB5E48C), // soft lime green
              Color(0xFF76C893), // muted forest green
              Color(0xFF184E77), // deep slate blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                
                // Select Ingredients Card
                Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Ingredients',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Color(0xFF184E77),
                                shadows: [
                                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                ],
                              ),
                            ),
                            if (!showAddIngredient)
                              IconButton(
                                icon: const Icon(Icons.add, color: Color(0xFF76C893)),
                                onPressed: () {
                                  setState(() {
                                    showAddIngredient = true;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...allIngredients.map((ingredient) {
                          final isCrossed = crossedOutIngredients.contains(ingredient);
                          final isReplaced = ingredientDisplay.containsKey(ingredient);
                          final displayText = ingredientDisplay[ingredient] ?? ingredient;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: (isCrossed || isReplaced)
                                ? IconButton(
                                    icon: const Icon(Icons.undo, size: 20, color: Color(0xFF76C893)),
                                    onPressed: isCrossed
                                        ? () => _undoRemoveIngredient(ingredient)
                                        : () => _undoReplace(ingredient),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 20, color: Colors.red),
                                    onPressed: isCrossed ? null : () => _removeIngredient(ingredient),
                                  ),
                            title: Text(
                              displayText,
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                decoration: isCrossed
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: isCrossed ? Colors.grey : Color(0xFF184E77),
                                shadows: [
                                  Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3),
                                ],
                              ),
                            ),
                            trailing: null,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                
                // Add Ingredient Section
                if (showAddIngredient) ...[
                  const SizedBox(height: 16),
                  _buildAddIngredientSection(),
                ],
                
                // Recent Changes Card
                if (recentChanges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF184E77)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recentChanges.map((change) => change['type'] == 'remove'
                                    ? 'Removed ${change['ingredient']}'
                                    : 'Replaced ${change['original']} with ${change['alt']}').join(', '),
                                style: const TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 12,
                                  color: Color(0xFF184E77),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final lastChange = recentChanges.last;
                                if (lastChange['type'] == 'remove') {
                                  _undoRemoveIngredient(lastChange['ingredient']);
                                } else {
                                  _undoReplace(lastChange['original']);
                                }
                                setState(() {
                                  recentChanges.removeLast();
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF76C893),
                              ),
                              child: const Text(
                                'UNDO',
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF76C893),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Alternatives Section
                if (showAlternatives)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alternative Ingredients',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Color(0xFF184E77),
                                shadows: [
                                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                ],
                              ),
                            ),
                            const Text(
                              'Prices and taste may vary',
                              style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            ...crossedOutIngredients
                                .where((ingredient) => ingredientAlternatives.containsKey(ingredient))
                                .map((original) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Alternatives for $original',
                                    style: const TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF184E77),
                                    ),
                                  ),
                                  ...ingredientAlternatives[original]!.map((alternative) {
                                    return RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(alternative, style: const TextStyle(fontFamily: 'Orbitron', color: Color(0xFF184E77))),
                                      value: alternative,
                                      groupValue: selectedAlternatives[original],
                                      onChanged: (val) {
                                        if (val != null) {
                                          _setReplacement(original, val);
                                        }
                                      },
                                      activeColor: Color(0xFF76C893),
                                    );
                                  }),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Similar Meals Section
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildSimilarMealsSection(),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}