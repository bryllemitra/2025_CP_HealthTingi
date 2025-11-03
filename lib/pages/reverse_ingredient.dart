import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'meal_details.dart'; // Import your meal details page
import 'substitution_details_dialog.dart'; // New dialog import

class ReverseIngredientPage extends StatefulWidget {
  final List<String>? ingredients;
  final int userId; // Required for logging
  final int mealId; // Add mealId for logging (assume passed from parent)

  const ReverseIngredientPage({
    super.key,
    this.ingredients,
    required this.userId,
    required this.mealId,
  });

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
    allIngredients = widget.ingredients?.toList() ?? [
      'Sayote',
      'Bagoong',
      'Small Onion',
      'Garlic',
      'Tomato',
      'Oil',
      'Soy Sauce',
    ];
    
    // Initialize display with default values first
    for (final ingredient in allIngredients) {
      ingredientDisplay[ingredient] = ingredient;
    }
    
    selectedAlternatives = {};
    
    // Load data in proper sequence
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadAvailableIngredients();
    await _loadExistingCustomization(); // This should override the default initialization
    await _loadIngredientAlternatives();
    await _loadSimilarMeals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when the page becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingCustomization();
    });
  }

  Future<void> _loadExistingCustomization() async {
    try {
      final dbHelper = DatabaseHelper();
      final customized = await dbHelper.getActiveCustomizedMeal(widget.mealId, widget.userId);
      
      if (customized != null && mounted) {
        final substituted = customized['substituted_ingredients'] as Map<String, dynamic>;
        
        // Create temporary sets to build the state
        final Set<String> newCrossedOut = {};
        final Map<String, String?> newSelectedAlternatives = {};
        final Map<String, String> newIngredientDisplay = {};
        final List<String> newAllIngredients = List.from(widget.ingredients ?? []);
        
        // Process all entries in substituted_ingredients
        for (final entry in substituted.entries) {
          final original = entry.key;
          final substituteData = entry.value as Map<String, dynamic>;
          final substituteType = substituteData['type'] as String;
          final substituteValue = substituteData['value'] as String;
          
          // Check if this ingredient was in the original meal
          final wasInOriginal = (widget.ingredients ?? []).contains(original);
          
          if (!wasInOriginal && substituteType == 'new') {
            // This is a newly added ingredient
            if (!newAllIngredients.contains(original)) {
              newAllIngredients.add(original);
            }
            newIngredientDisplay[original] = original;
          } else if (substituteType == 'removed') {
            // Original ingredient was removed
            newCrossedOut.add(original);
            newIngredientDisplay[original] = original; // Still show it but crossed out
          } else if (substituteType == 'substituted') {
            // Original ingredient was substituted
            newSelectedAlternatives[original] = substituteValue;
            newIngredientDisplay[original] = substituteValue;
          } else {
            // Original ingredient kept as is
            newIngredientDisplay[original] = original;
          }
        }
        
        // Update state all at once
        setState(() {
          allIngredients = newAllIngredients;
          crossedOutIngredients = newCrossedOut;
          selectedAlternatives = newSelectedAlternatives;
          ingredientDisplay = newIngredientDisplay;
          
          // Show alternatives if any ingredients are crossed out
          showAlternatives = newCrossedOut.isNotEmpty;
        });
        
        // Reload similar meals with current state
        _loadSimilarMeals();
        
        // Reload ingredient alternatives for the updated ingredient list
        _loadIngredientAlternatives();
      } else {
        // No customization found, initialize with default display
        setState(() {
          for (final ingredient in allIngredients) {
            ingredientDisplay[ingredient] = ingredient;
          }
        });
      }
    } catch (e) {
      print('Error loading existing customization: $e');
      // Fallback: initialize display with default values
      setState(() {
        for (final ingredient in allIngredients) {
          ingredientDisplay[ingredient] = ingredient;
        }
      });
    }
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
        ingredientDisplay[ingredientName] = ingredientName;
        _searchController.clear();
        showAddIngredient = false;
      });
      
      // Reload similar meals with new ingredient
      _loadSimilarMeals();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $ingredientName', style: const TextStyle(fontFamily: 'Orbitron')),
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

      // Ensure the ingredient stays in the display
      if (!ingredientDisplay.containsKey(ingredient)) {
        ingredientDisplay[ingredient] = ingredient;
      }

      if (ingredientAlternatives.containsKey(ingredient)) {
        showAlternatives = true;
      }
    });

    _loadSimilarMeals();
  }

  void _undoRemoveIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.remove(ingredient);
      recentChanges.removeWhere((change) =>
          change['type'] == 'remove' && change['ingredient'] == ingredient);

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
  }

  void _undoReplace(String original) {
    setState(() {
      selectedAlternatives.remove(original);
      ingredientDisplay.remove(original);
      crossedOutIngredients.remove(original);
      recentChanges.removeWhere((change) =>
          change['type'] == 'replace' && change['original'] == original);

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

  Future<void> _saveCustomizedMeal() async {
    try {
      final dbHelper = DatabaseHelper();
      
      // Get the original meal ingredients
      final originalMeal = await dbHelper.getMealById(widget.mealId);
      final originalIngredients = await dbHelper.getMealIngredients(widget.mealId);
      final originalIngredientNames = originalIngredients
          .map((ing) => ing['ingredientName']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      
      // Create maps for original and substituted ingredients
      Map<String, String> originalIngredientsMap = {};
      Map<String, Map<String, dynamic>> substitutedIngredientsMap = {};
      
      // Process ALL current ingredients (original + added)
      for (final ingredientName in allIngredients) {
        originalIngredientsMap[ingredientName] = ingredientName;
        
        if (selectedAlternatives.containsKey(ingredientName)) {
          // This ingredient was substituted
          substitutedIngredientsMap[ingredientName] = {
            'type': 'substituted',
            'value': selectedAlternatives[ingredientName]!,
            'quantity': '1 piece'
          };
        } else if (crossedOutIngredients.contains(ingredientName)) {
          // This ingredient was removed
          substitutedIngredientsMap[ingredientName] = {
            'type': 'removed',
            'value': 'REMOVED'
          };
        } else if (!originalIngredientNames.contains(ingredientName)) {
          // This is a newly added ingredient that wasn't removed or substituted
          substitutedIngredientsMap[ingredientName] = {
            'type': 'new',
            'value': ingredientName,
            'quantity': '1 piece'
          };
        } else {
          // Original ingredient kept as is
          substitutedIngredientsMap[ingredientName] = {
            'type': 'original',
            'value': ingredientName
          };
        }
      }
      
      // Also include original ingredients that might have been completely removed from the list
      for (final originalName in originalIngredientNames) {
        if (!allIngredients.contains(originalName)) {
          originalIngredientsMap[originalName] = originalName;
          substitutedIngredientsMap[originalName] = {
            'type': 'removed',
            'value': 'REMOVED'
          };
        }
      }
      
      await dbHelper.saveCustomizedMeal(
        originalMealId: widget.mealId,
        userId: widget.userId,
        originalIngredients: originalIngredientsMap,
        substitutedIngredients: substitutedIngredientsMap,
        customizedName: 'Customized ${originalMeal?['mealName'] ?? 'Meal'}',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customized meal saved!', style: TextStyle(fontFamily: 'Orbitron')),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('Error saving customized meal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving customized meal: $e', style: const TextStyle(fontFamily: 'Orbitron')),
          backgroundColor: Colors.red,
        ),
      );
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
        const SnackBar(
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
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF184E77)),
                  onPressed: () {
                    setState(() {
                      showAddIngredient = false;
                      _searchController.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _filterIngredients,
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                hintStyle: const TextStyle(fontFamily: 'Orbitron'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF184E77)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF184E77)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            isLoadingIngredients
                ? const Center(child: CircularProgressIndicator())
                : filteredIngredients.isEmpty
                    ? const Center(
                        child: Text(
                          'No ingredients found',
                          style: TextStyle(fontFamily: 'Orbitron', color: Colors.black54),
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: filteredIngredients.length,
                          itemBuilder: (context, index) {
                            final ingredient = filteredIngredients[index];
                            final name = ingredient['ingredientName'] as String? ?? 'Unknown';
                            return ListTile(
                              title: Text(name, style: const TextStyle(fontFamily: 'Orbitron')),
                              trailing: ElevatedButton(
                                onPressed: () => _addIngredient(name),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF76C893),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(fontFamily: 'Orbitron', color: Colors.white),
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
              'Similar Meals',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF184E77),
              ),
            ),
            const SizedBox(height: 12),
            isLoadingSimilarMeals
                ? const Center(child: CircularProgressIndicator())
                : similarMeals.isEmpty
                    ? const Center(
                        child: Text(
                          'No similar meals found',
                          style: TextStyle(fontFamily: 'Orbitron', color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: similarMeals.length,
                        itemBuilder: (context, index) {
                          final meal = similarMeals[index];
                          final name = meal['mealName'] as String? ?? 'Unknown Meal';
                          final matchPercentage = meal['match_percentage'] as double? ?? 0.0;
                          final mealPicture = meal['mealPicture'] as String?;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              borderRadius: BorderRadius.circular(12),
                              elevation: 4,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(8),
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: mealPicture != null
                                        ? DecorationImage(
                                            image: AssetImage(mealPicture),
                                            fit: BoxFit.cover,
                                          )
                                        : const DecorationImage(
                                            image: AssetImage('assets/placeholder_meal.jpg'),
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF184E77),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${matchPercentage.toStringAsFixed(1)}% match',
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 12,
                                    color: Color(0xFF76C893),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => _navigateToMealDetails(meal),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  // New: Parse amount and unit
  Map<String, dynamic> _parseAmountAndUnit(String original) {
    RegExp pat = RegExp(r'(\d+/\d+|\d+\.\d+|\d+)\s*([a-zA-Z]+)');
    var match = pat.firstMatch(original);
    if (match == null) return {'amount': 1.0, 'unit': 'g'};
    String amountStr = match.group(1)!;
    String unit = match.group(2)!;
    double amount;
    if (amountStr.contains('/')) {
      var parts = amountStr.split('/');
      amount = double.parse(parts[0]) / double.parse(parts[1]);
    } else {
      amount = double.parse(amountStr);
    }
    return {'amount': amount, 'unit': unit};
  }

  // New: Show substitution details (from "sa-ReverseIngredientPage-enchance-mo-raw-alternative-selection.txt")
  Future<void> _showSubstitutionDetails(String original, String alternative) async {
    final amountAndUnit = _parseAmountAndUnit(original);
    final dbHelper = DatabaseHelper();
    final alternatives = await dbHelper.getEnhancedAlternatives(
      original,
      amountAndUnit['amount'],
      amountAndUnit['unit'],
    );
    final alternativeData = alternatives.firstWhere(
      (alt) => alt['substitute']['ingredient']['ingredientName'] == alternative,
      orElse: () => {},
    );
    if (alternativeData.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => SubstitutionDetailsDialog(
          substitutionData: alternativeData,
          onAccept: (data) {
            _applySubstitution(data);
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No substitution data found for $alternative')),
      );
    }
  }

  // Fixed: Apply substitution with better amount formatting
  void _applySubstitution(Map<String, dynamic> data) {
    final substitute = data['substitute']['ingredient'];
    final original = data['original']['ingredient'];
    final originalIngredientName = original['ingredientName'];
    
    setState(() {
      // Format the amount more naturally instead of showing grams
      final displayAmount = _formatSubstitutionAmount(data['display_amount']);
      ingredientDisplay[originalIngredientName] = 
          '$displayAmount ${substitute['ingredientName']}';
      selectedAlternatives[originalIngredientName] = substitute['ingredientName'];
      crossedOutIngredients.remove(originalIngredientName);
    });
    
    // Log the substitution
    DatabaseHelper().logSubstitution(
      mealId: widget.mealId,
      userId: widget.userId,
      originalIngredientId: original['ingredientID'],
      substituteIngredientId: substitute['ingredientID'],
      originalAmountG: data['original']['amount_g'],
      substituteAmountG: data['substitute']['amount_g'],
      costDelta: data['deltas']['cost'],
      calorieDelta: data['deltas']['calories'],
    );
    
    _loadSimilarMeals(); // Reload meals with new ingredients
  }

  // Helper method to format the amount more naturally
  String _formatSubstitutionAmount(String displayAmount) {
    // Remove the 'g' suffix and format more naturally
    if (displayAmount.endsWith('g')) {
      final amount = displayAmount.replaceAll('g', '').trim();
      final amountNum = double.tryParse(amount) ?? 1.0;
      
      // Convert to more natural units
      if (amountNum >= 1000) {
        return '${(amountNum / 1000).toStringAsFixed(1)} kg';
      } else if (amountNum >= 100) {
        return '${(amountNum / 100).toStringAsFixed(1)} cups'; // Approximate
      } else if (amountNum >= 15) {
        return '${(amountNum / 15).toStringAsFixed(1)} tbsp'; // Approximate
      } else if (amountNum >= 5) {
        return '${(amountNum / 5).toStringAsFixed(1)} tsp'; // Approximate
      } else {
        return '1 piece'; // Default for small amounts
      }
    }
    return displayAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reverse Ingredient Search',
          style: TextStyle(fontFamily: 'Orbitron', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF184E77),
        actions: [
          // Add this save button
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveCustomizedMeal,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              setState(() {
                showAddIngredient = !showAddIngredient;
              });
            },
          ),
        ],
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Ingredients',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cross out unavailable ingredients',
                                style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: allIngredients.map((ingredient) {
                                  final displayText = ingredientDisplay[ingredient] ?? ingredient;
                                  final isCrossed = crossedOutIngredients.contains(ingredient);
                                  
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      displayText,
                                      style: TextStyle(
                                        fontFamily: 'Orbitron',
                                        decoration: isCrossed
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        color: isCrossed ? Colors.grey : Color(0xFF184E77),
                                        fontSize: constraints.maxWidth > 600 ? 16 : 14,
                                        shadows: const [
                                          Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3),
                                        ],
                                      ),
                                    ),
                                    trailing: isCrossed
                                        ? IconButton(
                                            icon: const Icon(Icons.undo, color: Color(0xFF76C893)),
                                            onPressed: () => _undoRemoveIngredient(ingredient),
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red),
                                            onPressed: () => _removeIngredient(ingredient),
                                          ),
                                  );
                                }).toList(),
                              ),
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
                                      style: TextStyle(
                                        fontFamily: 'Orbitron',
                                        fontSize: constraints.maxWidth > 600 ? 14 : 12,
                                        color: Color(0xFF184E77),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
                                      foregroundColor: const Color(0xFF76C893),
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
                                            title: Text(
                                              alternative, 
                                              style: TextStyle(
                                                fontFamily: 'Orbitron', 
                                                color: Color(0xFF184E77),
                                                fontSize: constraints.maxWidth > 600 ? 16 : 14,
                                              ),
                                            ),
                                            value: alternative,
                                            groupValue: selectedAlternatives[original],
                                            onChanged: (val) {
                                              if (val != null) {
                                                _showSubstitutionDetails(original, val);
                                              }
                                            },
                                            activeColor: const Color(0xFF76C893),
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
            );
          },
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