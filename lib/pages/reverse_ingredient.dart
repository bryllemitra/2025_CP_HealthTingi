import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'meal_details.dart'; // Import your meal details page

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
  
  // Stores details (quantity/unit) for ingredients.
  // Key: Ingredient Name (Original name for substitutions, New name for additions)
  Map<String, Map<String, String>> ingredientDetails = {}; 

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
        final Map<String, Map<String, String>> newIngredientDetails = {}; 
        final List<String> newAllIngredients = List.from(widget.ingredients ?? []);
        
        // Process all entries in substituted_ingredients
        for (final entry in substituted.entries) {
          final original = entry.key;
          final substituteData = entry.value as Map<String, dynamic>;
          final substituteType = substituteData['type'] as String;
          final substituteValue = substituteData['value'] as String;
          
          // Helper to parse "2 cups" into qty="2", unit="cups"
          Map<String, String> parseQuantity(String? quantityStr) {
             String qStr = quantityStr?.toString() ?? '1 piece';
             List<String> parts = qStr.split(' ');
             String qty = parts.isNotEmpty ? parts[0] : '1';
             String unit = parts.length > 1 ? parts.sublist(1).join(' ') : 'piece';
             return {'qty': qty, 'unit': unit};
          }

          // Check if this ingredient was in the original meal
          final wasInOriginal = (widget.ingredients ?? []).contains(original);
          
          if (!wasInOriginal && substituteType == 'new') {
            // Case 1: NEW Ingredient
            if (!newAllIngredients.contains(original)) {
              newAllIngredients.add(original);
            }
            newIngredientDisplay[original] = original;
            newIngredientDetails[original] = parseQuantity(substituteData['quantity']);

          } else if (substituteType == 'removed') {
            // Case 2: REMOVED Ingredient
            newCrossedOut.add(original);
            newIngredientDisplay[original] = original; 
          } else if (substituteType == 'substituted') {
            // Case 3: SUBSTITUTED Ingredient
            newSelectedAlternatives[original] = substituteValue;
            newIngredientDisplay[original] = substituteValue;
            // Load the saved quantity for the substitution
            newIngredientDetails[original] = parseQuantity(substituteData['quantity']);
          } else {
            // Case 4: Original kept
            newIngredientDisplay[original] = original;
          }
        }
        
        // Update state all at once
        setState(() {
          allIngredients = newAllIngredients;
          crossedOutIngredients = newCrossedOut;
          selectedAlternatives = newSelectedAlternatives;
          ingredientDisplay = newIngredientDisplay;
          ingredientDetails = newIngredientDetails; 
          
          showAlternatives = newCrossedOut.isNotEmpty;
        });
        
        _loadSimilarMeals();
        _loadIngredientAlternatives();
      } else {
        // No customization found, initialize default
        setState(() {
          for (final ingredient in allIngredients) {
            ingredientDisplay[ingredient] = ingredient;
          }
        });
      }
    } catch (e) {
      print('Error loading existing customization: $e');
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

  // UPDATED: Logic to add ingredient with specific quantity and unit
  void _addIngredient(String ingredientName, {String qty = '1', String unit = 'piece'}) {
    setState(() {
      // 1. Check if the ingredient exists but is currently crossed out (REMOVED)
      if (crossedOutIngredients.contains(ingredientName)) {
        // Un-cross it
        crossedOutIngredients.remove(ingredientName);
        
        // UPDATE the details with the NEW quantity and unit from the dialog
        ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
        
        // Log this change so the "Undo" button works correctly
        recentChanges.add({'type': 'add_back', 'ingredient': ingredientName});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $ingredientName with new quantity', style: const TextStyle(fontFamily: 'Orbitron')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } 
      // 2. If it is a completely new ingredient
      else if (!allIngredients.contains(ingredientName)) {
        allIngredients.add(ingredientName);
        
        // Store the user's specific input
        ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
        
        ingredientDisplay[ingredientName] = ingredientName;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $qty $unit of $ingredientName', style: const TextStyle(fontFamily: 'Orbitron')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // 3. Optional: If it exists and is NOT crossed out, maybe just update the quantity?
        ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $ingredientName to $qty $unit', style: const TextStyle(fontFamily: 'Orbitron')),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Common cleanup actions
      _searchController.clear();
      showAddIngredient = false;
      _loadSimilarMeals();
    });
  }

  // Dialog to ask user for Quantity and Unit (Used for Add & Substitute)
  Future<void> _showAddIngredientDialog(String ingredientName) async {
    String selectedQty = '1';
    String selectedUnit = 'piece';
    final List<String> units = ['piece', 'kg', 'g', 'cup', 'tbsp', 'tsp', 'pack', 'can', 'clove', 'head', 'bottle']; 

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add $ingredientName', style: const TextStyle(fontFamily: 'Orbitron')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => selectedQty = val,
                    controller: TextEditingController(text: selectedQty),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedUnit,
                    isExpanded: true,
                    items: units.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        selectedUnit = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addIngredient(ingredientName, qty: selectedQty, unit: selectedUnit);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.add(ingredient);
      recentChanges.add({'type': 'remove', 'ingredient': ingredient});

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

  // Not strictly used anymore since we use _confirmSubstitution, but good to keep
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
      // Also clear the details for this substitution
      ingredientDetails.remove(original);
      
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
      
      final originalMeal = await dbHelper.getMealById(widget.mealId);
      final originalIngredients = await dbHelper.getMealIngredients(widget.mealId);
      final originalIngredientNames = originalIngredients
          .map((ing) => ing['ingredientName']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      
      Map<String, String> originalIngredientsMap = {};
      Map<String, Map<String, dynamic>> substitutedIngredientsMap = {};
      
      for (final ingredientName in allIngredients) {
        originalIngredientsMap[ingredientName] = ingredientName;
        
        if (selectedAlternatives.containsKey(ingredientName)) {
          // SUBSTITUTED INGREDIENT CASE
          
          // UPDATED: Retrieve the specific details (Qty/Unit) for substitution
          final details = ingredientDetails[ingredientName];
          String userQty = details?['qty'] ?? '1';
          String userUnit = details?['unit'] ?? 'piece';

          substitutedIngredientsMap[ingredientName] = {
            'type': 'substituted',
            'value': selectedAlternatives[ingredientName]!,
            'quantity': '$userQty $userUnit' // Uses your specific input now
          };
        } else if (crossedOutIngredients.contains(ingredientName)) {
          // REMOVED INGREDIENT CASE
          substitutedIngredientsMap[ingredientName] = {
            'type': 'removed',
            'value': 'REMOVED'
          };
        } else if (!originalIngredientNames.contains(ingredientName)) {
          // NEW INGREDIENT CASE
          
          final details = ingredientDetails[ingredientName];
          String userQty = details?['qty'] ?? '1';
          String userUnit = details?['unit'] ?? 'piece';
          
          substitutedIngredientsMap[ingredientName] = {
            'type': 'new',
            'value': ingredientName,
            'quantity': '$userQty $userUnit' 
          };
        } else {
          // ORIGINAL KEPT CASE
          substitutedIngredientsMap[ingredientName] = {
            'type': 'original',
            'value': ingredientName
          };
        }
      }
      
      // Handle originals that were completely removed from list
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
                                onPressed: () => _showAddIngredientDialog(name),
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

  // UPDATED: Confirm substitution with QUANTITY and UNIT input
  Future<void> _confirmSubstitution(String original, String alternative) async {
    String selectedQty = '1';
    String selectedUnit = 'piece';
    final List<String> units = ['piece', 'kg', 'g', 'cup', 'tbsp', 'tsp', 'pack', 'can', 'clove', 'head', 'bottle'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Confirm Substitution',
              style: TextStyle(fontFamily: 'Orbitron'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replace $original with $alternative?',
                  style: const TextStyle(fontFamily: 'Orbitron'),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Quantity of new ingredient'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => selectedQty = val,
                  controller: TextEditingController(text: selectedQty),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedUnit,
                  isExpanded: true,
                  items: units.map((String unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      selectedUnit = newValue!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'Orbitron'),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF76C893),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontFamily: 'Orbitron', color: Colors.white),
                ),
              ),
            ],
          );
        }
      ),
    );

    if (result == true) {
      _applySimpleSubstitution(original, alternative, qty: selectedQty, unit: selectedUnit);
    }
  }

  // UPDATED: Substitution now accepts and stores quantity/unit
  void _applySimpleSubstitution(String original, String alternative, {String qty = '1', String unit = 'piece'}) {
    setState(() {
      ingredientDisplay[original] = alternative;
      selectedAlternatives[original] = alternative;
      crossedOutIngredients.remove(original);
      
      // Store the quantity details for this original ingredient key
      ingredientDetails[original] = {'qty': qty, 'unit': unit};

      recentChanges.add({'type': 'replace', 'original': original, 'alt': alternative});
    });
    
    _loadSimilarMeals(); 
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
                                        color: isCrossed ? Colors.grey : const Color(0xFF184E77),
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
                                        color: const Color(0xFF184E77),
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
                                                color: const Color(0xFF184E77),
                                                fontSize: constraints.maxWidth > 600 ? 16 : 14,
                                              ),
                                            ),
                                            value: alternative,
                                            groupValue: selectedAlternatives[original],
                                            onChanged: (val) {
                                              if (val != null) {
                                                _confirmSubstitution(original, val);
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