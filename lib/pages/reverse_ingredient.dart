import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'meal_details.dart';

class ReverseIngredientPage extends StatefulWidget {
  final List<String>? ingredients;
  final int userId;
  final int mealId;

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
  Map<String, Map<String, String>> ingredientDetails = {};
  
  // Stores original recipe values to use as fallbacks
  Map<String, Map<String, String>> originalDefaults = {};

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
    
    // Initialize display and safe defaults
    for (final ingredient in allIngredients) {
      ingredientDisplay[ingredient] = ingredient;
      if (!ingredientDetails.containsKey(ingredient)) {
        ingredientDetails[ingredient] = {'qty': '1', 'unit': 'piece'};
      }
    }
    
    selectedAlternatives = {};
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadAvailableIngredients();
    await _loadOriginalMealIngredients(); // Load real recipe quantities first
    await _loadExistingCustomization(); 
    await _loadIngredientAlternatives();
    await _loadSimilarMeals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingCustomization();
    });
  }

  // --- NEW: Load Original Quantities from DB ---
  Future<void> _loadOriginalMealIngredients() async {
    try {
      final dbHelper = DatabaseHelper();
      final originalIngredients = await dbHelper.getMealIngredients(widget.mealId);
      
      final Map<String, Map<String, String>> defaults = {};

      for (var ing in originalIngredients) {
        final name = ing['ingredientName'] as String;
        
        // Format quantity (e.g., 0.25 -> "0.25", 2.0 -> "2")
        dynamic rawQty = ing['quantity'];
        String qty = '1';
        if (rawQty != null) {
           if (rawQty is num) {
             qty = rawQty == rawQty.toInt() ? rawQty.toInt().toString() : rawQty.toString();
           } else {
             qty = rawQty.toString();
           }
        }
        
        final unit = ing['unit']?.toString() ?? 'piece';
        defaults[name] = {'qty': qty, 'unit': unit};
      }

      if (mounted) {
        setState(() {
          originalDefaults = defaults;
          
          // Apply these defaults to our current list
          for (var entry in defaults.entries) {
            if (allIngredients.contains(entry.key)) {
               ingredientDetails[entry.key] = entry.value;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading original meal ingredients: $e');
    }
  }

  // --- NEW: Edit Quantity Logic ---
  void _updateIngredientDetails(String ingredientName, String qty, String unit) {
    setState(() {
      ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
      recentChanges.add({'type': 'edited', 'ingredient': ingredientName});
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated $ingredientName to $qty $unit', style: const TextStyle(fontFamily: 'Orbitron')),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _showEditQtyDialog(String ingredientName) async {
    final currentDetails = ingredientDetails[ingredientName] ?? {'qty': '1', 'unit': 'piece'};
    String selectedQty = currentDetails['qty']!;
    String selectedUnit = currentDetails['unit']!;
    
    final List<String> units = ['piece', 'kg', 'g', 'cup', 'tbsp', 'tsp', 'pack', 'can', 'clove', 'head', 'bottle']; 

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit $ingredientName', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: selectedQty),
                    onChanged: (val) => selectedQty = val,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    value: units.contains(selectedUnit) ? selectedUnit : units[0],
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
                    _updateIngredientDetails(ingredientName, selectedQty, selectedUnit);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF184E77)),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadExistingCustomization() async {
    try {
      final dbHelper = DatabaseHelper();
      final customized = await dbHelper.getActiveCustomizedMeal(widget.mealId, widget.userId);
      
      if (customized != null && mounted) {
        final substituted = customized['substituted_ingredients'] as Map<String, dynamic>;
        
        final Set<String> newCrossedOut = {};
        final Map<String, String?> newSelectedAlternatives = {};
        final Map<String, String> newIngredientDisplay = {};
        final Map<String, Map<String, String>> newIngredientDetails = {}; 
        final List<String> newAllIngredients = List.from(widget.ingredients ?? []);
        
        for (final entry in substituted.entries) {
          final original = entry.key;
          final substituteData = entry.value as Map<String, dynamic>;
          final substituteType = substituteData['type'] as String;
          final substituteValue = substituteData['value'] as String;
          
          Map<String, String> parseQuantity(String? quantityStr) {
             String qStr = quantityStr?.toString() ?? '1 piece';
             List<String> parts = qStr.split(' ');
             String qty = parts.isNotEmpty ? parts[0] : '1';
             String unit = parts.length > 1 ? parts.sublist(1).join(' ') : 'piece';
             return {'qty': qty, 'unit': unit};
          }

          final wasInOriginal = (widget.ingredients ?? []).contains(original);
          
          if (!wasInOriginal && substituteType == 'new') {
            if (!newAllIngredients.contains(original)) {
              newAllIngredients.add(original);
            }
            newIngredientDisplay[original] = original;
            newIngredientDetails[original] = parseQuantity(substituteData['quantity']);

          } else if (substituteType == 'removed') {
            newCrossedOut.add(original);
            newIngredientDisplay[original] = original;
            // Keep original details for reference even if removed
            newIngredientDetails[original] = originalDefaults[original] ?? {'qty': '1', 'unit': 'piece'};
          } else if (substituteType == 'substituted') {
            newSelectedAlternatives[original] = substituteValue;
            newIngredientDisplay[original] = substituteValue;
            newIngredientDetails[original] = parseQuantity(substituteData['quantity']);
          } else {
            // TYPE == 'ORIGINAL'
            newIngredientDisplay[original] = original;
            
            // Priority: 1. Saved Quantity, 2. Original Recipe Default, 3. '1 piece' fallback
            if (substituteData['quantity'] != null) {
               newIngredientDetails[original] = parseQuantity(substituteData['quantity']);
            } else {
               newIngredientDetails[original] = originalDefaults[original] ?? {'qty': '1', 'unit': 'piece'};
            }
          }
        }
        
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
      }
    } catch (e) {
      print('Error loading existing customization: $e');
    }
  }

  Future<void> _loadAvailableIngredients() async {
    if (mounted) setState(() => isLoadingIngredients = true);
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
      if (mounted) setState(() => isLoadingIngredients = false);
    }
  }

  void _filterIngredients(String query) {
    if (query.isEmpty) {
      setState(() => filteredIngredients = availableIngredients);
      return;
    }
    setState(() {
      filteredIngredients = availableIngredients.where((ingredient) {
        final name = ingredient['ingredientName']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _addIngredient(String ingredientName, {String qty = '1', String unit = 'piece'}) {
    setState(() {
      if (crossedOutIngredients.contains(ingredientName)) {
        crossedOutIngredients.remove(ingredientName);
        ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
        recentChanges.add({'type': 'add_back', 'ingredient': ingredientName});
      } 
      else if (!allIngredients.contains(ingredientName)) {
        allIngredients.add(ingredientName);
        ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
        ingredientDisplay[ingredientName] = ingredientName;
      } else {
        ingredientDetails[ingredientName] = {'qty': qty, 'unit': unit};
      }
      _searchController.clear();
      showAddIngredient = false;
      _loadSimilarMeals();
    });
  }

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

  void _undoReplace(String original) {
    setState(() {
      selectedAlternatives.remove(original);
      ingredientDisplay.remove(original);
      crossedOutIngredients.remove(original);
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
    if (mounted) setState(() {});
  }

  Future<void> _loadSimilarMeals() async {
    if (mounted) setState(() => isLoadingSimilarMeals = true);

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
          .toList();
      
      Map<String, String> originalIngredientsMap = {};
      Map<String, Map<String, dynamic>> substitutedIngredientsMap = {};
      
      for (final ingredientName in allIngredients) {
        originalIngredientsMap[ingredientName] = ingredientName;
        
        if (selectedAlternatives.containsKey(ingredientName)) {
          final details = ingredientDetails[ingredientName];
          String userQty = details?['qty'] ?? '1';
          String userUnit = details?['unit'] ?? 'piece';

          substitutedIngredientsMap[ingredientName] = {
            'type': 'substituted',
            'value': selectedAlternatives[ingredientName]!,
            'quantity': '$userQty $userUnit' 
          };
        } else if (crossedOutIngredients.contains(ingredientName)) {
          substitutedIngredientsMap[ingredientName] = {
            'type': 'removed',
            'value': 'REMOVED'
          };
        } else if (!originalIngredientNames.contains(ingredientName)) {
          final details = ingredientDetails[ingredientName];
          String userQty = details?['qty'] ?? '1';
          String userUnit = details?['unit'] ?? 'piece';
          
          substitutedIngredientsMap[ingredientName] = {
            'type': 'new',
            'value': ingredientName,
            'quantity': '$userQty $userUnit' 
          };
        } else {
          // ORIGINAL INGREDIENT (Possibly Edited)
          final details = ingredientDetails[ingredientName];
          String userQty = details?['qty'] ?? '1';
          String userUnit = details?['unit'] ?? 'piece';
          
          substitutedIngredientsMap[ingredientName] = {
            'type': 'original',
            'value': ingredientName,
            'quantity': '$userQty $userUnit' // Save the current quantity state
          };
        }
      }
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e', style: const TextStyle(fontFamily: 'Orbitron')), backgroundColor: Colors.red),
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
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                const Expanded(
                  child: Text(
                    'Add More Ingredients',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF184E77),
                    ),
                    softWrap: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF184E77)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredIngredients.length,
                          itemBuilder: (context, index) {
                            final ingredient = filteredIngredients[index];
                            final name = ingredient['ingredientName'] as String? ?? 'Unknown';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(
                                name, 
                                style: const TextStyle(fontFamily: 'Orbitron'),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _showAddIngredientDialog(name),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF76C893),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 12),
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
                          
                          // CHANGED: Use Counts instead of Percentage
                          final matching = meal['matching_ingredients'] ?? 0;
                          final total = meal['total_ingredients'] ?? 0;
                          
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
                                  '$matching/$total match', // CHANGED DISPLAY
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

  Future<void> _confirmSubstitution(String original, String alternative) async {
    String selectedQty = '1';
    String selectedUnit = 'piece';
    final List<String> units = ['piece', 'kg', 'g', 'cup', 'tbsp', 'tsp', 'pack', 'can', 'clove', 'head', 'bottle'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Confirm Substitution', style: TextStyle(fontFamily: 'Orbitron')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replace $original with $alternative?', style: const TextStyle(fontFamily: 'Orbitron')),
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
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Orbitron')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF76C893)),
                child: const Text('Confirm', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white)),
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

  void _applySimpleSubstitution(String original, String alternative, {String qty = '1', String unit = 'piece'}) {
    setState(() {
      ingredientDisplay[original] = alternative;
      selectedAlternatives[original] = alternative;
      crossedOutIngredients.remove(original);
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
              Color(0xFFB5E48C), 
              Color(0xFF76C893), 
              Color(0xFF184E77), 
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
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayText,
                                          style: TextStyle(
                                            fontFamily: 'Orbitron',
                                            decoration: isCrossed
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            color: isCrossed ? Colors.grey : const Color(0xFF184E77),
                                            fontSize: constraints.maxWidth > 600 ? 16 : 14,
                                            fontWeight: FontWeight.bold,
                                            shadows: const [
                                              Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3),
                                            ],
                                          ),
                                        ),
                                        // --- UPDATED: Show subtitle if not crossed out ---
                                        if (!isCrossed && ingredientDetails.containsKey(ingredient))
                                          Text(
                                            "${ingredientDetails[ingredient]!['qty']} ${ingredientDetails[ingredient]!['unit']}",
                                            style: const TextStyle(
                                              fontFamily: 'Orbitron',
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // --- UPDATED: Edit Button ---
                                        if (!isCrossed)
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                            tooltip: 'Edit Quantity',
                                            onPressed: () => _showEditQtyDialog(ingredient),
                                          ),
                                        isCrossed
                                            ? IconButton(
                                                icon: const Icon(Icons.undo, color: Color(0xFF76C893)),
                                                onPressed: () => _undoRemoveIngredient(ingredient),
                                              )
                                            : IconButton(
                                                icon: const Icon(Icons.close, color: Colors.red),
                                                onPressed: () => _removeIngredient(ingredient),
                                              ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (showAddIngredient) ...[
                        const SizedBox(height: 16),
                        _buildAddIngredientSection(),
                      ],
                      
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
                                      recentChanges.map((change) {
                                        if (change['type'] == 'remove') return 'Removed ${change['ingredient']}';
                                        if (change['type'] == 'replace') return 'Replaced ${change['original']} with ${change['alt']}';
                                        if (change['type'] == 'edited') return 'Edited ${change['ingredient']}';
                                        return 'Modified ingredient';
                                      }).join(', '),
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
                                      } else if (lastChange['type'] == 'replace') {
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