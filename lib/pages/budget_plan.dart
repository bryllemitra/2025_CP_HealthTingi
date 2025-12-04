import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import 'home.dart';
import 'meal_scan.dart';
import '../searchMeals/meal_search.dart';
import 'navigation.dart';
import 'meal_details.dart';
import '../searchMeals/price_search.dart';
import '../information/about_us.dart';
import '../information/fAQs.dart';
import 'index.dart';

class BudgetPlanPage extends StatefulWidget {
  final int userId;

  const BudgetPlanPage({super.key, required this.userId});

  @override
  State<BudgetPlanPage> createState() => _BudgetPlanPageState();
}

class _BudgetPlanPageState extends State<BudgetPlanPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _mealsFuture;
  final TextEditingController _budgetController = TextEditingController();
  String _searchQuery = '';
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    _mealsFuture = _fetchMeals();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  // --- HELPER: Parse Quantity (Copied from meal_details.dart) ---
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

  // --- HELPER: Calculate Real Cost (Adapted from meal_details.dart) ---
  Future<double> _calculateRealMealCost(int mealId) async {
    double total = 0.0;
    
    // 1. Fetch Ingredients and Customizations
    final originalIngredients = await _dbHelper.getMealIngredients(mealId);
    Map<String, dynamic> subs = {};
    
    // Only check customizations if user is logged in
    if (widget.userId != 0) {
      final customizedMeal = await _dbHelper.getActiveCustomizedMeal(mealId, widget.userId);
      if (customizedMeal != null) {
        subs = customizedMeal['substituted_ingredients'] ?? {};
      }
    }

    // 2. Process ORIGINAL Ingredients
    for (var ing in originalIngredients) {
      String name = ing['ingredientName']?.toString() ?? '';

      // CHECK: Is this ingredient modified?
      if (subs.containsKey(name)) {
        final subData = subs[name];
        String type = subData['type'];

        if (type == 'removed') {
          continue; // Skip cost completely
        } 
        else if (type == 'substituted') {
          // Calculate cost of the SUBSTITUTE instead of original
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
          continue; // Done with this ingredient
        }
      }

      // Handle UNTOUCHED Original Ingredients
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

    // 3. Process NEWLY ADDED Ingredients
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

  Future<List<Map<String, dynamic>>> _fetchMeals() async {
    final meals = await _dbHelper.getAllMeals();
    final List<Map<String, dynamic>> updatedMeals = [];

    // Iterate through all meals and calculate dynamic price
    for (var meal in meals) {
      // Create a modifiable copy of the meal map
      var mealMap = Map<String, dynamic>.from(meal);
      
      // Calculate the real cost based on ingredients and user customization
      double calculatedPrice = await _calculateRealMealCost(meal['mealID']);
      
      // If we calculated a valid price (> 0), use it. 
      // Otherwise fallback to the static price column if calculation failed or meal has no ingredients.
      if (calculatedPrice > 0) {
        mealMap['price'] = calculatedPrice;
      } else {
        mealMap['price'] = (meal['price'] as num).toDouble();
      }
      
      updatedMeals.add(mealMap);
    }
    
    return updatedMeals;
  }

  List<Map<String, dynamic>> _filterMealsByBudget(
      List<Map<String, dynamic>> meals, double budget) {
    try {
      meals.sort((a, b) {
        final aPrice = (a['price'] as num).toDouble();
        final bPrice = (b['price'] as num).toDouble();
        final aDiff = (aPrice - budget).abs();
        final bDiff = (bPrice - budget).abs();
        return aDiff.compareTo(bDiff);
      });
      return meals;
    } catch (e) {
      debugPrint('Error sorting meals by budget: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _groupMealsByPriceRange(
      List<Map<String, dynamic>> meals) {
    final groupedMeals = <Map<String, dynamic>>[];
    final priceRanges = [
      {'min': 0.0, 'max': 50.0, 'label': '50'},
      {'min': 51.0, 'max': 70.0, 'label': '70'},
      {'min': 71.0, 'max': 100.0, 'label': '100'},
      {'min': 101.0, 'max': double.infinity, 'label': '100+'},
    ];

    for (var range in priceRanges) {
      final rangeMeals = meals.where((meal) {
        final price = (meal['price'] as num).toDouble();
        final min = range['min'] as double;
        final max = range['max'] as double;
        return price >= min && price <= max;
      }).toList();

      if (rangeMeals.isNotEmpty) {
        groupedMeals.add({
          'budget': range['label'],
          'meals': rangeMeals,
        });
      }
    }

    return groupedMeals;
  }

  Widget _buildMealCard(BuildContext context, Map<String, dynamic> meal) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealDetailsPage(
              mealId: meal['mealID'],
              userId: widget.userId,
            ),
          ),
        ).then((_) {
          // Refresh the list when returning from details (in case customization changed)
          setState(() {
            _mealsFuture = _fetchMeals();
          });
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: meal['mealPicture'] != null
                  ? Image.asset(
                      meal['mealPicture'],
                      width: 80,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal['mealName'],
                    style: const TextStyle(
                      fontFamily: 'Poppins', // Updated to Poppins
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  Text(
                    "Php ${meal['price'].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontFamily: 'Poppins', // Updated to Poppins
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  )
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSection(BuildContext context, Map<String, dynamic> section) {
    final meals = section['meals'] as List<Map<String, dynamic>>;
    if (meals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Meals at Php ${section['budget']}",
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'Exo', // Updated to Exo
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(2, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...meals.take(3).map((meal) => _buildMealCard(context, meal)).toList(),
        const SizedBox(height: 8),
        if (meals.length > 3)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PriceSearchPage(
                      userId: widget.userId,
                      priceRange: section['budget'],
                    ),
                  ),
                );
              },
              child: const Text(
                "See more →",
                style: TextStyle(
                  fontFamily: 'Poppins', // Updated to Poppins
                  color: Colors.yellowAccent,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildGuestDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white.withOpacity(0.1),
      child: Container(
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 16),
              child: Text(
                'HealthTingi',
                style: TextStyle(
                  fontFamily: 'Exo', // Updated to Exo
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white,
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
            _drawerButton(context, Icons.info_outline, 'About Us'),
            const SizedBox(height: 8),
            _drawerButton(context, Icons.help_outline, 'FAQs'),
            const SizedBox(height: 8),
            _drawerButton(context, Icons.logout, 'Exit Guest Mode'),
          ],
        ),
      ),
    );
  }

  Widget _drawerButton(BuildContext context, IconData icon, String label) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: const Color(0xFF184E77),
        elevation: 10,
        shadowColor: Colors.greenAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: () {
        Navigator.pop(context); // Close drawer first
        switch (label) {
          case 'About Us':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutUsPage()),
            );
            break;
          case 'FAQs':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FAQSPage()),
            );
            break;
          case 'Exit Guest Mode':
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const IndexPage()),
              (Route<dynamic> route) => false,
            );
            break;
        }
      },
      icon: Icon(icon, size: 24),
      label: Text(
        label, 
        style: const TextStyle(
          fontFamily: 'Poppins', // Updated to Poppins
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF184E77),
        elevation: 0,
        title: const Text(
          'Budget Meal Planner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Exo', // Updated to Exo
            fontSize: 22,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(2, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                _showInfo = !_showInfo;
              });
            },
          ),
        ],
      ),
      drawer: widget.userId != 0 
          ? NavigationDrawerWidget(userId: widget.userId)
          : _buildGuestDrawer(context),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showInfo)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.userId == 0
                          ? 'Enter your budget to see suggested meals. Register to save your preferences.'
                          : 'Enter your budget to get suggested meals that match or come close to it.',
                      style: const TextStyle(
                        color: Color(0xFF184E77),
                        fontFamily: 'Poppins', // Updated to Poppins
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
                      const Text(
                        "Enter Budget (in numbers)",
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Exo', // Updated to Exo
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(2, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _budgetController,
                        style: const TextStyle(color: Color(0xFF184E77), fontFamily: 'Poppins'), // Updated to Poppins
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g. 57',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          prefixIcon: const Icon(Icons.currency_ruble, color: Color(0xFF184E77)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          hintStyle: const TextStyle(color: Colors.black54, fontFamily: 'Poppins'), // Updated to Poppins
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setState(() => _searchQuery = '');
                            return;
                          }
                          if (double.tryParse(value) != null) {
                            setState(() => _searchQuery = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _mealsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontFamily: 'Poppins')));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No meals available', style: TextStyle(fontFamily: 'Poppins')));
                    }

                    final allMeals = snapshot.data!;
                    final categorizedMeals = _searchQuery.isEmpty
                        ? _groupMealsByPriceRange(allMeals)
                        : [
                            {
                              'budget': 'Near ${_searchQuery}',
                              'meals': _filterMealsByBudget(
                                  allMeals, double.parse(_searchQuery)),
                            }
                          ];

                    return Column(
                      children: categorizedMeals
                          .map((section) => _buildBudgetSection(context, section))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 40),
                const Center(
                  child: Text(
                    'Plan Smart, Eat Healthy!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                      fontFamily: 'Poppins', // Updated to Poppins
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF184E77), // Darker blue for better contrast
        selectedItemColor: Color(0xFF184E77),
        unselectedItemColor: Color(0xFF184E77).withOpacity(0.7),
        currentIndex: 3,
        selectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontFamily: 'Poppins'),
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealScanPage(userId: widget.userId),
                ),
              );
              break;
            case 1:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    title: 'HealthTingi',
                    userId: widget.userId,
                  ),
                ),
                (route) => false,
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealSearchPage(userId: widget.userId),
                ),
              );
              break;
            case 3:
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Recipes'),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: 'Budget'),
        ],
      ),
    );
  }
}