import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart'; // Added for animations
import '../searchMeals/history.dart'; // Import HistoryPage to access completed meals list
import 'reverse_ingredient.dart'; // Add this import for navigation
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart'; // Added for gallery support
import 'meal_steps.dart'; // Add this import for the new page

class MealDetailsPage extends StatefulWidget {
  final int mealId;
  final int userId;

  const MealDetailsPage({
    super.key, 
    required this.mealId,
    required this.userId,
  });

  @override
  State<MealDetailsPage> createState() => _MealDetailsPageState();
}

class _MealDetailsPageState extends State<MealDetailsPage> {
  Future<Map<String, dynamic>>? _mealDataFuture;
  bool _isFavorite = false;
  bool _isLoading = false;
  String? _errorMessage;
  late PageController _imagePageController;
  int _currentImageIndex = 0;
  Timer? _carouselTimer;
  List<String> _imagePaths = [];
  Map<String, dynamic>? _customizedMeal;
  bool _showCustomized = false;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _imagePageController.addListener(() {
      setState(() {
        _currentImageIndex = _imagePageController.page?.round() ?? 0;
      });
    });
    _loadData();
    _trackMealView();
    _loadCustomizedMeal();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _mealDataFuture = _loadMealData();
      if (widget.userId != 0) {
        await _checkIfFavorite();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCustomizedMeal() async {
    if (widget.userId == 0) return;
    
    try {
      final dbHelper = DatabaseHelper();
      final customized = await dbHelper.getActiveCustomizedMeal(widget.mealId, widget.userId);
      
      if (mounted) {
        setState(() {
          _customizedMeal = customized;
        });
      }
    } catch (e) {
      print('Error loading customized meal: $e');
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      final favorites = user['favorites']?.toString() ?? '';
      setState(() {
        _isFavorite = favorites.split(',').contains(widget.mealId.toString());
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to check favorites: ${e.toString()}';
        });
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> parseSteps(String instructions) {
    List<Map<String, dynamic>> steps = [];
    List<String> blocks = instructions.trim().split(RegExp(r'\n{2,}'));
    
    for (var i = 0; i < blocks.length; i++) {
      var lines = blocks[i].split('\n');
      if (lines.isEmpty) continue;
      
      var firstLine = lines[0].trim();
      var match = RegExp(r'^(\d+)\.\s*(.*)').firstMatch(firstLine);
      if (match == null) continue;
      
      String title = match.group(2)!.trim();
      String content = lines.sublist(1).join('\n').trim();
      
      int duration = 0;
      var timeMatch = RegExp(r'\((\d+)(–(\d+))?\s*mins?\)').firstMatch(title);
      if (timeMatch != null) {
        int min1 = int.parse(timeMatch.group(1)!);
        int? min2 = timeMatch.group(3) != null ? int.parse(timeMatch.group(3)!) : null;
        duration = ((min2 ?? min1) * 60);
      }
      
      title = title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      
      steps.add({
        'number': int.parse(match.group(1)!),
        'title': title,
        'content': content,
        'duration': duration,
      });
    }
    
    return steps;
  }

  Future<Map<String, dynamic>> _loadMealData() async {
    try {
      final dbHelper = DatabaseHelper();
      final meal = await dbHelper.getMealById(widget.mealId);
      final ingredients = await dbHelper.getMealIngredients(widget.mealId);

      if (meal == null) throw Exception('Meal not found');

      final steps = parseSteps(meal['instructions'] ?? '');

      if (widget.userId == 0) {
        return {
          ...meal,
          'ingredients': ingredients,
          'hasSpecificRestriction': false,
          'userRestriction': '',
          'mealRestrictions': meal['hasDietaryRestrictions'] ?? '',
          'steps': steps,
        };
      }

      final user = await dbHelper.getUserById(widget.userId);
      if (user == null) throw Exception('User not found');

      final userRestriction = user['dietaryRestriction']?.toString().toLowerCase().trim() ?? '';
      final mealRestrictionsString = meal['hasDietaryRestrictions']?.toString().toLowerCase() ?? '';
      final mealRestrictions = mealRestrictionsString.split(',').map((r) => r.trim()).toList();
      
      final userHasRestriction = (user['hasDietaryRestriction'] ?? 0) == 1;
      final hasSpecificRestriction = userHasRestriction && 
          userRestriction.isNotEmpty &&
          mealRestrictions.any((mealRestriction) => 
              mealRestriction.contains(userRestriction) || 
              userRestriction.contains(mealRestriction));

      return {
        ...meal,
        'ingredients': ingredients,
        'hasSpecificRestriction': hasSpecificRestriction,
        'userRestriction': userRestriction,
        'mealRestrictions': mealRestrictionsString,
        'steps': steps,
      };
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load meal: ${e.toString()}');
      }
      rethrow;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading || widget.userId == 0) return;

    setState(() => _isLoading = true);

    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      String favorites = user['favorites']?.toString() ?? '';
      final mealIdStr = widget.mealId.toString();
      final favoritesList = favorites.split(',').where((id) => id.isNotEmpty).toList();

      setState(() {
        _isFavorite = !_isFavorite;
        if (_isFavorite) {
          if (!favoritesList.contains(mealIdStr)) {
            favoritesList.add(mealIdStr);
          }
        } else {
          favoritesList.remove(mealIdStr);
        }
        favorites = favoritesList.join(',');
      });

      await dbHelper.updateUser(widget.userId, {'favorites': favorites});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites!' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isFavorite = !_isFavorite);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _trackMealView() async {
    if (widget.userId != 0) {
      final dbHelper = DatabaseHelper();
      await dbHelper.addToRecentlyViewed(widget.userId, widget.mealId);
    }
  }

  void _startCarouselTimer() {
    if (_imagePaths.length > 1) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_currentImageIndex < _imagePaths.length - 1) {
          _imagePageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _imagePageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<List<Widget>> _buildIngredientWidgets(
    List<Map<String, dynamic>> ingredients, 
    Map<String, dynamic>? substitutedIngredients
  ) async {
    List<Widget> ingredientWidgets = [];
    double totalPrice = 0.0;
    
    // First, process original meal ingredients
    for (var ingredient in ingredients) {
      final ingredientName = ingredient['ingredientName']?.toString() ?? 'Unknown';
      String displayName = ingredientName;
      String quantity = ingredient['quantity']?.toString() ?? '';
      
      // Use substituted ingredient if available and showing customized
      if (substitutedIngredients != null && substitutedIngredients.containsKey(ingredientName)) {
        final substituteData = substitutedIngredients[ingredientName];
        final substituteValue = substituteData is Map ? substituteData['value'] : substituteData;
        
        if (substituteValue == 'REMOVED') {
          // Skip removed ingredients
          continue;
        } else if (substituteValue != ingredientName) {
          // Use substituted ingredient name
          displayName = substituteValue;
        }
      }
      
      double? ingredientPrice = ingredient['price'] as double?;
      final unit = ingredient['unit']?.toString() ?? 'kg';

      // Compute calculatedCost
      double calculatedCost = 0.0;
      if (ingredientPrice != null && quantity.isNotEmpty) {
        final qtyMatch = RegExp(r'(\d+\.?\d*)\s*(\w+)').firstMatch(quantity);
        if (qtyMatch != null) {
          double qtyValue = double.parse(qtyMatch.group(1)!);
          String qtyUnit = qtyMatch.group(2)!.toLowerCase();

          // Convert quantity to grams
          double gramsPerQtyUnit = 1.0;
          if (qtyUnit == 'kg') {
            gramsPerQtyUnit = 1000.0;
          } else if (qtyUnit == 'g') {
            gramsPerQtyUnit = 1.0;
          } else if (qtyUnit == 'tbsp') {
            gramsPerQtyUnit = ingredient['unit_density_tbsp'] as double? ?? 15.0;
          } else if (qtyUnit == 'tsp') {
            gramsPerQtyUnit = ingredient['unit_density_tsp'] as double? ?? 5.0;
          } else if (qtyUnit == 'cup') {
            gramsPerQtyUnit = ingredient['unit_density_cup'] as double? ?? 240.0;
          }

          final qtyGrams = qtyValue * gramsPerQtyUnit;
          calculatedCost = (qtyGrams / 100.0) * ingredientPrice;
        }
      }
      totalPrice += calculatedCost;
      final priceDisplay = calculatedCost.toStringAsFixed(2);

      ingredientWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 3,
                child: Text(
                  '$quantity $displayName',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Orbitron',
                    color: Colors.black87,
                    fontStyle: substitutedIngredients != null && 
                              substitutedIngredients.containsKey(ingredientName) &&
                              (substitutedIngredients[ingredientName] is Map ? 
                               substitutedIngredients[ingredientName]['value'] != ingredientName : 
                               substitutedIngredients[ingredientName] != ingredientName)
                        ? FontStyle.italic 
                        : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                flex: 1,
                child: Text(
                  'Php $priceDisplay',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Orbitron',
                    color: Color(0xFF76C893),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Now, add any NEW ingredients that were added in customization but don't exist in original meal
    if (substitutedIngredients != null) {
      for (final entry in substitutedIngredients.entries) {
        final ingredientName = entry.key;
        final substituteData = entry.value;
        
        // Check if this is a NEW ingredient using the new data structure
        final isNewIngredient = substituteData is Map && 
            substituteData['type'] == 'new' &&
            !ingredients.any((ing) => ing['ingredientName']?.toString() == ingredientName);
        
        if (isNewIngredient) {
          final newIngredientData = substituteData;
          final quantity = newIngredientData['quantity'] ?? '1 piece';
          final dbHelper = DatabaseHelper();
          final ingredientInfo = await dbHelper.getIngredientByName(ingredientName);
          
          String displayPrice = 'Php ?';
          if (ingredientInfo != null) {
            // Calculate price based on quantity
            double? ingredientPrice = ingredientInfo['price'] as double?;
            if (ingredientPrice != null) {
              final unit = ingredientInfo['unit']?.toString()?.toLowerCase() ?? 'piece';
              double gramsPerUnit = 100.0; // Default for pieces
              
              // Convert based on unit type
              if (unit == 'kg') gramsPerUnit = 1000.0;
              else if (unit == 'g') gramsPerUnit = 1.0;
              else if (unit == 'tbsp') gramsPerUnit = ingredientInfo['unit_density_tbsp'] as double? ?? 15.0;
              else if (unit == 'tsp') gramsPerUnit = ingredientInfo['unit_density_tsp'] as double? ?? 5.0;
              else if (unit == 'cup') gramsPerUnit = ingredientInfo['unit_density_cup'] as double? ?? 240.0;
              
              // Parse quantity to get the numeric value
              final qtyMatch = RegExp(r'(\d+\.?\d*)\s*(\w+)').firstMatch(quantity);
              if (qtyMatch != null) {
                double qtyValue = double.parse(qtyMatch.group(1)!);
                String qtyUnit = qtyMatch.group(2)!.toLowerCase();
                
                // Convert quantity to grams
                double gramsPerQtyUnit = 1.0;
                if (qtyUnit == 'kg') {
                  gramsPerQtyUnit = 1000.0;
                } else if (qtyUnit == 'g') {
                  gramsPerQtyUnit = 1.0;
                } else if (qtyUnit == 'tbsp') {
                  gramsPerQtyUnit = ingredientInfo['unit_density_tbsp'] as double? ?? 15.0;
                } else if (qtyUnit == 'tsp') {
                  gramsPerQtyUnit = ingredientInfo['unit_density_tsp'] as double? ?? 5.0;
                } else if (qtyUnit == 'cup') {
                  gramsPerQtyUnit = ingredientInfo['unit_density_cup'] as double? ?? 240.0;
                } else if (qtyUnit == 'piece' || qtyUnit == 'pcs') {
                  gramsPerQtyUnit = 100.0; // Default weight per piece
                }
                
                final qtyGrams = qtyValue * gramsPerQtyUnit;
                final calculatedCost = (qtyGrams / 100.0) * ingredientPrice;
                displayPrice = 'Php ${calculatedCost.toStringAsFixed(2)}';
              } else {
                // If we can't parse the quantity, use default unit calculation
                final calculatedCost = (gramsPerUnit / 100.0) * ingredientPrice;
                displayPrice = 'Php ${calculatedCost.toStringAsFixed(2)}';
              }
            }
          }
          
          ingredientWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 3,
                    child: Text(
                      '$quantity $ingredientName',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Orbitron',
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Text(
                      displayPrice,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Orbitron',
                        color: Color(0xFF76C893),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
    
    return ingredientWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [
                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                ]),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Cooking Quest',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 24,
                  shadows: [
                    Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                  ],
                ),
              ),
              centerTitle: true,
              actions: [
               if (widget.userId != 0)
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white70,
                        size: 20, // Consistent size
                      ),
                onPressed: _isLoading ? null : _toggleFavorite,
              ),
              ],
            ),
            if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 16,
                          shadows: [
                            Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF184E77),
                          elevation: 10,
                          shadowColor: Colors.greenAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: FutureBuilder(
                  future: _mealDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Orbitron',
                                fontSize: 16,
                                shadows: [
                                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF184E77),
                                elevation: 10,
                                shadowColor: Colors.greenAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (!snapshot.hasData) {
                      return const Center(
                        child: Text(
                          'No meal data found',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontSize: 16,
                            shadows: [
                              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                            ],
                          ),
                        ),
                      );
                    }

                    final mealData = snapshot.data!;
                    if (_imagePaths.isEmpty) {
                      _imagePaths = _extractImagePaths(mealData);
                      if (_imagePaths.isNotEmpty) {
                        _startCarouselTimer();
                      }
                    }
                    final hasSpecificRestriction = mealData['hasSpecificRestriction'] ?? false;
                    final userRestriction = mealData['userRestriction'] ?? '';
                    final mealRestrictions = mealData['mealRestrictions'] ?? '';
                    final ingredients = mealData['ingredients'] as List<Map<String, dynamic>>;
                    final categories = (mealData['category'] as String?)?.split(', ') ?? [];

                    // Compute total price from ingredients
                    double totalPrice = 0.0;
                    for (var ingredient in ingredients) {
                      final ingredientName = ingredient['ingredientName']?.toString() ?? 'Unknown';
                      
                      // Skip removed ingredients in customized view
                      if (_showCustomized && _customizedMeal != null) {
                        final substituted = _customizedMeal!['substituted_ingredients'] as Map<String, dynamic>;
                        final substituteValue = substituted[ingredientName] is Map ? 
                            substituted[ingredientName]['value'] : substituted[ingredientName];
                        if (substituted.containsKey(ingredientName) && substituteValue == 'REMOVED') {
                          continue;
                        }
                      }
                      
                      final quantity = ingredient['quantity']?.toString() ?? '';
                      double? ingredientPrice = ingredient['price'] as double?;
                      final unit = ingredient['unit']?.toString() ?? 'kg';

                      // Compute calculatedCost (updated to use grams since price is per 100g)
                      double calculatedCost = 0.0;
                      if (ingredientPrice != null && quantity.isNotEmpty) {
                        final qtyMatch = RegExp(r'(\d+\.?\d*)\s*(\w+)').firstMatch(quantity);
                        if (qtyMatch != null) {
                          double qtyValue = double.parse(qtyMatch.group(1)!);
                          String qtyUnit = qtyMatch.group(2)!.toLowerCase();

                          // Convert quantity to grams
                          double gramsPerQtyUnit = 1.0; // Default for grams
                          if (qtyUnit == 'kg') {
                            gramsPerQtyUnit = 1000.0;
                          } else if (qtyUnit == 'g') {
                            gramsPerQtyUnit = 1.0;
                          } else if (qtyUnit == 'tbsp') {
                            gramsPerQtyUnit = ingredient['unit_density_tbsp'] as double? ?? 15.0;
                          } else if (qtyUnit == 'tsp') {
                            gramsPerQtyUnit = ingredient['unit_density_tsp'] as double? ?? 5.0;
                          } else if (qtyUnit == 'cup') {
                            gramsPerQtyUnit = ingredient['unit_density_cup'] as double? ?? 240.0;
                          } // Add more units as needed (e.g., ml ≈ 1g, piece based on average)

                          final qtyGrams = qtyValue * gramsPerQtyUnit;
                          calculatedCost = (qtyGrams / 100.0) * ingredientPrice;
                        }
                      }
                      totalPrice += calculatedCost;
                    }

                    return Stack(
                      children: [
                        _buildMealImages(mealData),
                        Positioned(
                          top: 250,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 25,
                                  offset: Offset(0, -10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      mealData['mealName'],
                                      style: const TextStyle(
                                        fontFamily: 'Orbitron',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 28,
                                        color: Color(0xFF184E77),
                                        shadows: [
                                          Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      '(Serving Size: ${mealData['servings']})',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Orbitron',
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      'Price: Php ${totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontFamily: 'Orbitron',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF76C893),
                                      ),
                                    ),
                                  ),
                                  if (categories.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: categories.map((category) {
                                          return Chip(
                                            label: Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'Orbitron',
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor: const Color(0xFF184E77),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  if (hasSpecificRestriction)
                                    Card(
                                      color: Colors.red[600],
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      elevation: 10,
                                      shadowColor: Colors.black54,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
                                                    fontFamily: 'Orbitron',
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                  ),
                                                  children: [
                                                    const TextSpan(text: '⚠️ Dietary Alert: '),
                                                    TextSpan(
                                                      text: 'This meal contains ingredients that conflict with your ',
                                                    ),
                                                    TextSpan(
                                                      text: userRestriction.isNotEmpty ? userRestriction : 'dietary restriction',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    TextSpan(
                                                      text: '. Meal restrictions: $mealRestrictions. Consider choosing an alternative option.',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Ingredients and Cost',
                                    style: TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Color(0xFF184E77),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Add toggle for customized view if available
                                  if (_customizedMeal != null)
                                    Row(
                                      children: [
                                        const Text(
                                          'Show Customized Ingredients',
                                          style: TextStyle(
                                            fontFamily: 'Orbitron',
                                            fontSize: 14,
                                            color: Color(0xFF184E77),
                                          ),
                                        ),
                                        Switch(
                                          value: _showCustomized,
                                          onChanged: (value) {
                                            setState(() {
                                              _showCustomized = value;
                                            });
                                          },
                                          activeColor: const Color(0xFF76C893),
                                        ),
                                      ],
                                    ),

                                  Card(
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    shadowColor: Colors.black26,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: ingredients.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No ingredients listed',
                                                style: TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                  fontFamily: 'Orbitron',
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            )
                                          : FutureBuilder<List<Widget>>(
                                              future: _buildIngredientWidgets(
                                                ingredients, 
                                                _showCustomized ? _customizedMeal!['substituted_ingredients'] : null
                                              ),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                  return const Center(
                                                    child: CircularProgressIndicator(),
                                                  );
                                                } else if (snapshot.hasError) {
                                                  return Center(
                                                    child: Text(
                                                      'Error loading ingredients: ${snapshot.error}',
                                                      style: const TextStyle(
                                                        fontFamily: 'Orbitron',
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  return Column(
                                                    children: snapshot.data ?? [],
                                                  );
                                                }
                                              },
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.edit, size: 20),
                                      label: Text(
                                        _customizedMeal != null ? 'Modify Customization' : 'Change Ingredients',
                                        style: const TextStyle(
                                          fontFamily: 'Orbitron',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: () {
                                        final ingredientNames = ingredients
                                            .map((ing) => ing['ingredientName'] as String)
                                            .toList();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReverseIngredientPage(
                                              ingredients: ingredientNames,
                                              userId: widget.userId,
                                              mealId: widget.mealId,
                                            ),
                                          ),
                                        ).then((_) {
                                          // Reload customized meal when returning from reverse ingredient page
                                          _loadCustomizedMeal();
                                          setState(() {
                                            _showCustomized = false; // Reset to original view
                                          });
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF184E77),
                                        elevation: 10,
                                        shadowColor: Colors.greenAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                  ),
                                  const SizedBox(height: 32),
                                  const Text(
                                    'Cooking Quest Steps',
                                    style: TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Color(0xFF184E77),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    shadowColor: Colors.black26,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: SelectableText(
                                        mealData['instructions'] ?? 'No instructions available',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          fontFamily: 'Orbitron',
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MealStepsPage(
                                              mealId: widget.mealId,
                                              userId: widget.userId,
                                              mealData: mealData,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF184E77),
                                        elevation: 10,
                                        shadowColor: Colors.greenAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: const Text(
                                        'Start Cooking Quest',
                                        style: TextStyle(
                                          fontFamily: 'Orbitron',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _extractImagePaths(Map<String, dynamic> mealData) {
    List<String> imagePaths = [];
    String? mealPicture = mealData['mealPicture'];
    if (mealPicture != null) {
      imagePaths.add(mealPicture);
    }
    String? additional = mealData['additionalPictures'];
    if (additional != null && additional.isNotEmpty) {
      imagePaths.addAll(additional.split(','));
    }
    return imagePaths;
  }

  Widget _buildMealImages(Map<String, dynamic> mealData) {
    if (_imagePaths.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.fastfood, size: 100, color: Colors.white70),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            PageView.builder(
              controller: _imagePageController,
              itemCount: _imagePaths.length,
              itemBuilder: (context, index) {
                String path = _imagePaths[index];
                final isAsset = path.startsWith('assets/');
                final imageProvider = isAsset ? AssetImage(path) : FileImage(File(path)) as ImageProvider;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          body: PhotoViewGallery.builder(
                            scrollPhysics: const BouncingScrollPhysics(),
                            builder: (BuildContext context, int galleryIndex) {
                              final galleryPath = _imagePaths[galleryIndex];
                              final galleryIsAsset = galleryPath.startsWith('assets/');
                              return PhotoViewGalleryPageOptions(
                                imageProvider: galleryIsAsset 
                                    ? AssetImage(galleryPath) 
                                    : FileImage(File(galleryPath)) as ImageProvider,
                                initialScale: PhotoViewComputedScale.contained,
                                minScale: PhotoViewComputedScale.contained,
                                maxScale: PhotoViewComputedScale.covered * 4.0,
                                heroAttributes: PhotoViewHeroAttributes(tag: galleryPath),
                              );
                            },
                            itemCount: _imagePaths.length,
                            loadingBuilder: (context, event) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                            pageController: PageController(initialPage: index),
                            onPageChanged: (i) => setState(() => _currentImageIndex = i),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.white.withOpacity(0.1),
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 100, color: Colors.white70),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_imagePaths.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_imagePaths.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentImageIndex == index ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}