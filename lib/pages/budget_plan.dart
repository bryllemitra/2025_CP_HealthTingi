import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import 'home.dart';
import 'meal_scan.dart';
import '../searchIngredient/meal_search.dart';
import 'navigation.dart';
import 'meal_details.dart';
import '../searchIngredient/price_search.dart';

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

  Future<List<Map<String, dynamic>>> _fetchMeals() async {
    final meals = await _dbHelper.getAllMeals();
    return meals.map((meal) {
      if (meal['price'] is int) {
        meal['price'] = (meal['price'] as int).toDouble();
      }
      return meal;
    }).toList();
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
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: Offset(1, 2),
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Php ${meal['price'].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
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
                style: TextStyle(fontFamily: 'Orbitron'),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf3f2df),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F2DF),
        title: const Text(
          'Budget Meal Planner',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
      IconButton(
        icon: const Icon(Icons.info_outline, color: Colors.black),
        onPressed: () {
          setState(() {
            _showInfo = !_showInfo;
          });
        },
      ),
    ],

        elevation: 0,
      ),
      drawer: NavigationDrawerWidget(userId: widget.userId,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showInfo)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Enter your budget to get suggested meals that match or come close to it.',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellowAccent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter Budget (in numbers)",
                    style: TextStyle(fontFamily: 'Orbitron'),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _budgetController,
                    style: const TextStyle(fontFamily: 'Orbitron'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'e.g. 57',
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
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _mealsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No meals available'));
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
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: const Color(0xEBE7D2),
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealScanPage(userId: widget.userId)),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.currency_ruble), label: 'Budget'),
        ],
      ),
    );
  }
}