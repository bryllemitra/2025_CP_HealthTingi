import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  double _parseQuantity(String quantityStr) {
    if (quantityStr.contains('.') && double.tryParse(quantityStr) != null) {
      return double.parse(quantityStr);
    }

    final fractionMap = {
      '⅛': 0.125, '¼': 0.25, '⅓': 0.333, '⅜': 0.375,
      '½': 0.5, '⅝': 0.625, '⅔': 0.666, '¾': 0.75, '⅞': 0.875
    };

    if (fractionMap.containsKey(quantityStr.trim())) {
      return fractionMap[quantityStr.trim()]!;
    }

    if (quantityStr.contains('/')) {
      List<String> parts = quantityStr.split('/');
      if (parts.length == 2) {
        double numerator = double.tryParse(parts[0].trim()) ?? 1.0;
        double denominator = double.tryParse(parts[1].trim()) ?? 1.0;
        return numerator / denominator;
      }
    }
    return double.tryParse(quantityStr) ?? 1.0;
  }

  Future<double> _calculateRealMealCost(int mealId) async {
    double total = 0.0;
    final originalIngredients = await _dbHelper.getMealIngredients(mealId);
    Map<String, dynamic> subs = {};
    if (widget.userId != 0) {
      final customizedMeal = await _dbHelper.getActiveCustomizedMeal(mealId, widget.userId);
      if (customizedMeal != null) {
        subs = customizedMeal['substituted_ingredients'] ?? {};
      }
    }

    for (var ing in originalIngredients) {
      String name = ing['ingredientName']?.toString() ?? '';
      if (subs.containsKey(name)) {
        final subData = subs[name];
        String type = subData['type'];

        if (type == 'removed') {
          continue;
        } 
        else if (type == 'substituted') {
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
          continue;
        }
      }

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

    for (var meal in meals) {
      var mealMap = Map<String, dynamic>.from(meal);
      double calculatedPrice = await _calculateRealMealCost(meal['mealID']);
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
      // Separate into two lists: Affordable (<= budget) and Over Budget (> budget)
      List<Map<String, dynamic>> affordable = [];
      List<Map<String, dynamic>> overBudget = [];

      for (var meal in meals) {
        double price = (meal['price'] as num).toDouble();
        if (price <= budget) {
          affordable.add(meal);
        } else {
          overBudget.add(meal);
        }
      }

      // Sort Affordable Meals: Price DESCENDING (Closest to budget at top)
      affordable.sort((a, b) {
        double priceA = (a['price'] as num).toDouble();
        double priceB = (b['price'] as num).toDouble();
        return priceB.compareTo(priceA); 
      });

      // Sort Over Budget Meals: Price ASCENDING (Closest to budget at top)
      overBudget.sort((a, b) {
        double priceA = (a['price'] as num).toDouble();
        double priceB = (b['price'] as num).toDouble();
        return priceA.compareTo(priceB);
      });

      // Combine: Affordable first, then Over Budget
      return [...affordable, ...overBudget];

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
                  ? (meal['mealPicture'].toString().startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: meal['mealPicture'],
                          width: 80,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(width: 80, height: 60, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0))),
                          errorWidget: (context, url, error) => Container(width: 80, height: 60, color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey)),
                        )
                      : Image.asset(
                          meal['mealPicture'],
                          width: 80,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 80, height: 60, color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey)),
                        ))
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
                      fontFamily: 'Poppins', 
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  Text(
                    "Php ${meal['price'].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontFamily: 'Poppins', 
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
            fontFamily: 'Exo', 
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
        ...meals.take(6).map((meal) => _buildMealCard(context, meal)).toList(),
        const SizedBox(height: 8),
        if (meals.length > 6)
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
                  fontFamily: 'Poppins', 
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
              Color(0xFFB5E48C), 
              Color(0xFF76C893), 
              Color(0xFF184E77), 
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
                  fontFamily: 'Exo', 
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
        Navigator.pop(context);
        switch (label) {
          case 'About Us':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutUsPage(isAdmin: false)),
            );
            break;
          case 'FAQs':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FAQSPage(isAdmin: false)),
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
          fontFamily: 'Poppins', 
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
            fontFamily: 'Exo', 
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
              Color(0xFFB5E48C), 
              Color(0xFF76C893), 
              Color(0xFF184E77), 
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
                        fontFamily: 'Poppins', 
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
                          fontFamily: 'Exo', 
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
                        style: const TextStyle(color: Color(0xFF184E77), fontFamily: 'Poppins'), 
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
                          hintStyle: const TextStyle(color: Colors.black54, fontFamily: 'Poppins'), 
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
                      fontFamily: 'Poppins', 
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF184E77), 
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