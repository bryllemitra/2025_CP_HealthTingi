import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'reverse_ingredient.dart';
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'meal_steps.dart';

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

  // Helper method to convert decimal to fraction string
  String _decimalToFraction(double value) {
    const tolerance = 0.001;
    
    if ((value - 0.125).abs() < tolerance) return '⅛';
    if ((value - 0.25).abs() < tolerance) return '¼';
    if ((value - 0.333).abs() < tolerance) return '⅓';
    if ((value - 0.375).abs() < tolerance) return '⅜';
    if ((value - 0.5).abs() < tolerance) return '½';
    if ((value - 0.625).abs() < tolerance) return '⅝';
    if ((value - 0.666).abs() < tolerance) return '⅔';
    if ((value - 0.75).abs() < tolerance) return '¾';
    if ((value - 0.875).abs() < tolerance) return '⅞';
    
    // For whole numbers, return without decimal
    if (value == value.roundToDouble()) return value.round().toString();
    
    // For other decimals, return as is with 2 decimal places
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  // Helper method to parse quantity string to double (handles fractions)
  double _parseQuantity(String quantityStr) {
    if (quantityStr.contains('.') && double.tryParse(quantityStr) != null) {
      return double.parse(quantityStr);
    }
    
    // First try to parse common fractions
    final fractionMap = {
      '⅛': 0.125, '¼': 0.25, '⅓': 0.333, '⅜': 0.375,
      '½': 0.5, '⅝': 0.625, '⅔': 0.666, '¾': 0.75, '⅞': 0.875
    };
    
    // Check if it's already a fraction character
    if (fractionMap.containsKey(quantityStr.trim())) {
      return fractionMap[quantityStr.trim()]!;
    }
    
    // Handle fractions like "1/4", "1/2", "3/4"
    if (quantityStr.contains('/')) {
      List<String> parts = quantityStr.split('/');
      if (parts.length == 2) {
        double numerator = double.tryParse(parts[0].trim()) ?? 1.0;
        double denominator = double.tryParse(parts[1].trim()) ?? 1.0;
        return numerator / denominator;
      }
    }
    // Handle whole numbers and decimals
    return double.tryParse(quantityStr) ?? 1.0;
  }

  // Helper method to format quantity for display
  String _formatQuantityForDisplay(String quantity) {
    if (quantity.isEmpty) return '';
    
    try {
      double value = _parseQuantity(quantity);
      return _decimalToFraction(value);
    } catch (e) {
      return quantity; // Return original if parsing fails
    }
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

  // === NEW METHOD: Calculate total price adjusting for Substitutions/Removals/Additions ===
  Future<double> _calculateAdjustedTotal(List<Map<String, dynamic>> originalIngredients) async {
    double total = 0.0;
    final dbHelper = DatabaseHelper();

    // 1. Get Customizations
    Map<String, dynamic> subs = {};
    if (_showCustomized && _customizedMeal != null) {
      subs = _customizedMeal!['substituted_ingredients'] ?? {};
    }

    // 2. Process ORIGINAL Ingredients
    for (var ing in originalIngredients) {
      String name = ing['ingredientName']?.toString() ?? '';

      // CHECK: Is this ingredient modified?
      if (_showCustomized && subs.containsKey(name)) {
        final subData = subs[name];
        String type = subData['type'];

        if (type == 'removed') {
          continue; // Skip cost completely
        } 
        else if (type == 'substituted') {
          // Calculate cost of the SUBSTITUTE instead of original
          String newName = subData['value'];
          String qtyStr = subData['quantity'] ?? '1 piece';
          
          // Parse "2 cups" -> qty: 2.0, unit: "cups"
          double qty = 1.0;
          String unit = 'piece';
          final match = RegExp(r'^((?:\d*\.?\d+)|(?:\d+\s*/\s*\d+)|[⅛¼⅓⅜½⅝⅔¾⅞])\s*(.*)$').firstMatch(qtyStr);
          if (match != null) {
             qty = _parseQuantity(match.group(1) ?? '1');
             unit = match.group(2)?.trim() ?? 'piece';
          }

          // Fetch price of the NEW ingredient from DB
          final newIng = await dbHelper.getIngredientByName(newName);
          if (newIng != null) {
             double grams = dbHelper.convertToGrams(qty, unit, newIng);
             // For ingredients table, 'unit' column IS the base unit
             double baseGrams = dbHelper.convertToGrams(1.0, newIng['unit'] ?? 'piece', newIng);
             double price = newIng['price'] as double? ?? 0.0;
             
             if (baseGrams > 0) {
               total += (grams * price) / baseGrams;
             }
          }
          continue; // Done with this ingredient
        }
      }

      // Handle UNTOUCHED Original Ingredients (Apply the Unit Fix here too)
      double price = ing['price'] as double? ?? 0.0;
      double qty = _parseQuantity(ing['quantity']?.toString() ?? '0');
      String unit = ing['unit']?.toString() ?? 'piece';
      // Use base_unit from the joined query, or fallback to 'unit'
      String baseUnit = ing['base_unit']?.toString() ?? ing['unit']?.toString() ?? 'piece'; 

      double grams = dbHelper.convertToGrams(qty, unit, ing);
      double baseGrams = dbHelper.convertToGrams(1.0, baseUnit, ing);
      
      if (baseGrams > 0) {
        total += (grams * price) / baseGrams;
      }
    }

    // 3. Process NEWLY ADDED Ingredients
    if (_showCustomized) {
      for (var entry in subs.entries) {
        if (entry.value['type'] == 'new') {
          String name = entry.key;
          String qtyStr = entry.value['quantity'] ?? '1 piece';

          // Parse quantity
          double qty = 1.0;
          String unit = 'piece';
          final match = RegExp(r'^((?:\d*\.?\d+)|(?:\d+\s*/\s*\d+)|[⅛¼⅓⅜½⅝⅔¾⅞])\s*(.*)$').firstMatch(qtyStr);
          if (match != null) {
             qty = _parseQuantity(match.group(1) ?? '1');
             unit = match.group(2)?.trim() ?? 'piece';
          }

          final newIng = await dbHelper.getIngredientByName(name);
          if (newIng != null) {
             double grams = dbHelper.convertToGrams(qty, unit, newIng);
             double baseGrams = dbHelper.convertToGrams(1.0, newIng['unit'] ?? 'piece', newIng);
             double price = newIng['price'] as double? ?? 0.0;

             if (baseGrams > 0) {
               total += (grams * price) / baseGrams;
             }
          }
        }
      }
    }

    return total;
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
    Map<String, dynamic>? substituted,
  ) async {
    List<Widget> widgets = [];
    final dbHelper = DatabaseHelper(); // Create instance

    for (var ing in ingredients) {
      final name = ing['ingredientName']?.toString() ?? 'Unknown';
      String displayName = name;
      String quantity = ing['quantity']?.toString() ?? '';
      String unit = ing['unit']?.toString() ?? '';
      String content = ing['content']?.toString() ?? '';

      if (substituted != null && substituted.containsKey(name)) {
        final sub = substituted[name];
        final value = sub is Map ? sub['value'] : sub;
        if (value == 'REMOVED') continue;
        if (value != name) displayName = value;
      }

      double? price = ing['price'] as double?;
      double cost = 0.0;

      if (price != null && quantity.isNotEmpty) {
        double qtyValue = _parseQuantity(quantity);
        String qtyUnit = unit.toLowerCase();
        double grams = dbHelper.convertToGrams(qtyValue, qtyUnit, ing);
        double baseUnitGrams = dbHelper.convertToGrams(1.0, ing['base_unit']?.toString().toLowerCase() ?? 'piece', ing);
        if (baseUnitGrams > 0) {
          double pricePerGram = price / baseUnitGrams;
          cost = grams * pricePerGram;
        }
      }

      String displayQuantity = _formatQuantityForDisplay(quantity);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ingredient details - takes most of the space
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main ingredient line
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins', // Updated to Poppins
                          color: Colors.black87,
                          fontStyle: substituted != null &&
                                  substituted.containsKey(name) &&
                                  (substituted[name] is Map
                                      ? substituted[name]['value'] != name
                                      : substituted[name] != name)
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        children: [
                          if (displayQuantity.isNotEmpty)
                            TextSpan(
                              text: '$displayQuantity ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          if (unit.isNotEmpty)
                            TextSpan(text: '$unit '),
                          TextSpan(text: displayName),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Content/preparation details on a new line if needed
                    if (content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '($content)',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins', // Updated to Poppins
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Price - fixed width
              Container(
                width: 110, // Fixed width for price to ensure alignment
                child: Text(
                  'Php ${cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Exo', // Updated to Exo for price emphasis
                    color: Color(0xFF76C893),
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (substituted != null) {
      for (final e in substituted.entries) {
        final name = e.key;
        final data = e.value;
        final isNew = data is Map && data['type'] == 'new' && !ingredients.any((i) => i['ingredientName'] == name);
        if (!isNew) continue;

        // Retrieve the combined string "2 cups"
        final qty = data['quantity'] ?? '1 piece';
        
        // --- Parse Quantity and Unit ---
        String qtyNumberStr = '1';
        String qtyUnit = 'piece';

        final match = RegExp(r'^((?:\d*\.?\d+)|(?:\d+\s*/\s*\d+)|[⅛¼⅓⅜½⅝⅔¾⅞])\s*(.*)$').firstMatch(qty.toString());
        
        if (match != null) {
          qtyNumberStr = match.group(1) ?? '1';
          qtyUnit = match.group(2)?.trim() ?? 'piece';
          if (qtyUnit.isEmpty) qtyUnit = 'piece';
        } else {
           qtyNumberStr = qty.toString(); 
        }

        final db = DatabaseHelper();
        final info = await db.getIngredientByName(name);
        String priceText = 'Php ?';

        if (info != null) {
          double? price = info['price'] as double?;
          if (price != null) {
            double qtyValue = _parseQuantity(qtyNumberStr);
            double grams = db.convertToGrams(qtyValue, qtyUnit, info);
            double baseUnitGrams = db.convertToGrams(1.0, info['unit']?.toString().toLowerCase() ?? 'piece', info);
            
            if (baseUnitGrams > 0) {
              double pricePerGram = price / baseUnitGrams;
              final cost = grams * pricePerGram;
              priceText = 'Php ${cost.toStringAsFixed(2)}';
            }
          }
        }

        String displayQtyNum = _formatQuantityForDisplay(qtyNumberStr);

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$displayQtyNum $qtyUnit $name',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins', // Updated to Poppins
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  child: Text(
                    priceText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Exo', // Updated to Exo
                      color: Color(0xFF76C893),
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  void _showFullScreenImage(int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: PageController(initialPage: startIndex),
              itemCount: _imagePaths.length,
              builder: (context, index) {
                final path = _imagePaths[index];
                final isAsset = path.startsWith('assets/');
                return PhotoViewGalleryPageOptions(
                  imageProvider: isAsset
                      ? AssetImage(path)
                      : FileImage(File(path)) as ImageProvider,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                );
              },
              scrollPhysics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (_imagePaths.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _imagePaths.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentImageIndex ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentImageIndex ? Colors.white : Colors.white60,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB5E48C), Color(0xFF76C893), Color(0xFF184E77)],
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
                  fontFamily: 'Exo', // Updated to Exo
                  fontSize: 24,
                  shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6)],
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
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.white70,
                            size: 20,
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
                        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, shadows: [
                          Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                        ]),
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
                        child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
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
                      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, shadows: [
                                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                ])),
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
                              child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Text('No meal data found',
                            style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, shadows: [
                              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                            ])),
                      );
                    }

                    final mealData = snapshot.data!;
                    final hasRestriction = mealData['hasSpecificRestriction'] ?? false;
                    final userRestriction = mealData['userRestriction'] ?? '';
                    final mealRestrictions = mealData['mealRestrictions'] ?? '';
                    final ingredients = mealData['ingredients'] as List<Map<String, dynamic>>;
                    final categories = (mealData['category'] as String?)?.split(', ') ?? [];

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
                                BoxShadow(color: Colors.black12, blurRadius: 25, offset: Offset(0, -10)),
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
                                        fontFamily: 'Exo', // Updated to Exo
                                        fontWeight: FontWeight.bold,
                                        fontSize: 28,
                                        color: Color(0xFF184E77),
                                        shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6)],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      '(Serving Size: ${mealData['servings']})',
                                      style: const TextStyle(fontSize: 14, fontFamily: 'Poppins', color: Colors.black54),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // --- UPDATED PRICE DISPLAY ---
                                  Center(
                                    child: FutureBuilder<double>(
                                      future: _calculateAdjustedTotal(ingredients),
                                      initialData: 0.0,
                                      builder: (context, priceSnapshot) {
                                        if (priceSnapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            height: 20, 
                                            width: 20, 
                                            child: CircularProgressIndicator(strokeWidth: 2)
                                          );
                                        }
                                        return Text(
                                          'Price: Php ${priceSnapshot.data?.toStringAsFixed(2) ?? "0.00"}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontFamily: 'Exo', // Updated to Exo
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF76C893),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (categories.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: categories.map((c) => Chip(
                                              label: Text(c,
                                                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.white)),
                                              backgroundColor: const Color(0xFF184E77),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                            )).toList(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  if (hasRestriction)
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
                                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.white),
                                                  children: [
                                                    const TextSpan(text: 'Dietary Alert: '),
                                                    TextSpan(text: 'This meal contains ingredients that conflict with your '),
                                                    TextSpan(
                                                        text: userRestriction.isNotEmpty ? userRestriction : 'dietary restriction',
                                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    TextSpan(text: '. Meal restrictions: $mealRestrictions.'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  const Text('Ingredients and Cost',
                                      style: TextStyle(fontFamily: 'Exo', fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF184E77))),
                                  const SizedBox(height: 12),
                                  if (_customizedMeal != null)
                                    Row(
                                      children: [
                                        const Text('Show Customized Ingredients',
                                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF184E77))),
                                        Switch(
                                          value: _showCustomized,
                                          onChanged: (v) => setState(() => _showCustomized = v),
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
                                              child: Text('No ingredients listed',
                                                  style: TextStyle(fontStyle: FontStyle.italic, fontFamily: 'Poppins', color: Colors.black54)),
                                            )
                                          : FutureBuilder<List<Widget>>(
                                              future: _buildIngredientWidgets(
                                                  ingredients, _showCustomized ? _customizedMeal!['substituted_ingredients'] : null),
                                              builder: (c, s) {
                                                if (s.connectionState == ConnectionState.waiting) {
                                                  return const Center(child: CircularProgressIndicator());
                                                }
                                                if (s.hasError) {
                                                  return Center(child: Text('Error: ${s.error}', style: const TextStyle(color: Colors.red)));
                                                }
                                                return Column(children: s.data ?? []);
                                              },
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (widget.userId != 0)
                                    Center(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.edit, size: 20),
                                        label: Text(_customizedMeal != null ? 'Modify Customization' : 'Change Ingredients',
                                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
                                        onPressed: () {
                                          final names = ingredients.map((i) => i['ingredientName'] as String).toList();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ReverseIngredientPage(
                                                ingredients: names,
                                                userId: widget.userId,
                                                mealId: widget.mealId,
                                              ),
                                            ),
                                          ).then((_) {
                                            _loadCustomizedMeal();
                                            setState(() => _showCustomized = false);
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
                                  const Text('Cooking Quest Steps',
                                      style: TextStyle(fontFamily: 'Exo', fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF184E77))),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    shadowColor: Colors.black26,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: SelectableText(
                                        mealData['instructions'] ?? 'No instructions available',
                                        style: const TextStyle(fontSize: 14, height: 1.5, fontFamily: 'Poppins', color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MealStepsPage(
                                            mealId: widget.mealId,
                                            userId: widget.userId,
                                            mealData: mealData,
                                          ),
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF184E77),
                                        elevation: 10,
                                        shadowColor: Colors.greenAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: const Text('Start Cooking Quest',
                                          style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
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
    List<String> paths = [];
    String? main = mealData['mealPicture'];
    if (main != null && main.isNotEmpty) paths.add(main);
    String? extra = mealData['additionalPictures'];
    if (extra != null && extra.isNotEmpty) paths.addAll(extra.split(',').where((p) => p.isNotEmpty));
    return paths;
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.white.withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.broken_image, size: 80, color: Colors.white70),
      ),
    );
  }

  Widget _buildMealImages(Map<String, dynamic> mealData) {
    if (_imagePaths.isEmpty) {
      _imagePaths = _extractImagePaths(mealData);
      if (_imagePaths.isNotEmpty) _startCarouselTimer();
    }

    if (_imagePaths.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, 10)),
          ],
        ),
        child: const Center(child: Icon(Icons.fastfood, size: 100, color: Colors.white70)),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, 10)),
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
                final path = _imagePaths[index];
                final isAsset = path.startsWith('assets/');
                return GestureDetector(
                  behavior: HitTestBehavior.translucent, // Critical for emulator
                  onTap: () {
                    print("Image tapped: $path"); // Debug in terminal
                    _showFullScreenImage(index);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.black12,
                    child: isAsset
                        ? Image.asset(
                            path,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildErrorImage(),
                          )
                        : FutureBuilder<bool>(
                            future: File(path).exists(),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => _buildErrorImage(),
                                );
                              }
                              return _buildErrorImage();
                            },
                          ),
                  ),
                );
              },
            ),
            // Zoom Icon
            const Positioned(
              bottom: 16,
              right: 16,
              child: Icon(Icons.zoom_in, color: Colors.white, size: 28),
            ),
            // Dots
            if (_imagePaths.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _imagePaths.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentImageIndex ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentImageIndex ? Colors.white : Colors.white60,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            // Top Gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
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