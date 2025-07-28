import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/home.dart';
import '../pages/budget_plan.dart';
import '../pages/meal_scan.dart';
import '../pages/meal_details.dart';

class MealSearchPage extends StatefulWidget {
  const MealSearchPage({super.key});

  @override
  State<MealSearchPage> createState() => _MealSearchPageState();
}

class _MealSearchPageState extends State<MealSearchPage> {
  late Future<List<Map<String, dynamic>>> _mealsFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mealsFuture = _fetchMeals();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchMeals() async {
    final meals = await _dbHelper.getAllMeals();
    return meals;
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  // Get current Philippine time (UTC+8)
  DateTime _getPhilippineTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 8));
  }

  String _getCurrentMealTime() {
    final phTime = _getPhilippineTime();
    final hour = phTime.hour;

    if (hour >= 5 && hour < 10) return "Breakfast";
    if (hour >= 10 && hour < 14) return "Lunch";
    if (hour >= 14 && hour < 17) return "Merienda";
    if (hour >= 17 && hour < 21) return "Dinner";
    return "Late Night";
  }

  String _getMealTimeGreeting(String time) {
    switch (time) {
      case "Breakfast": return "Here's your Breakfast!";
      case "Lunch": return "Get Ready For Lunch!";
      case "Merienda": return "Merienda Time!";
      case "Dinner": return "Dinner is Served!";
      case "Late Night": return "Late Night Snacks!";
      default: return "Meal Suggestions";
    }
  }

  List<Map<String, dynamic>> _filterMealsByTime(
      List<Map<String, dynamic>> meals, String time) {
    final phTime = _getPhilippineTime();
    final currentHour = phTime.hour;

    return meals.where((meal) {
      try {
        final fromHour = int.parse(meal['availableFrom']?.split(':')[0] ?? '0');
        final toHour = int.parse(meal['availableTo']?.split(':')[0] ?? '24');
        
        if (time == "Current") {
          return currentHour >= fromHour && currentHour < toHour;
        } else {
          return (fromHour >= _getStartHour(time) && toHour <= _getEndHour(time));
        }
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _filterMealsByName(List<Map<String, dynamic>> meals, String query) {
    if (query.isEmpty) return meals;
    return meals.where((meal) {
      return meal['mealName'].toString().toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _sortMeals(List<Map<String, dynamic>> meals) {
    meals.sort((a, b) => a['mealName'].compareTo(b['mealName']));
    return meals;
  }

  int _getStartHour(String time) {
    switch (time) {
      case "Breakfast": return 5;
      case "Lunch": return 10;
      case "Merienda": return 14;
      case "Dinner": return 17;
      case "Late Night": return 21;
      default: return 0;
    }
  }

  int _getEndHour(String time) {
    switch (time) {
      case "Breakfast": return 10;
      case "Lunch": return 14;
      case "Merienda": return 17;
      case "Dinner": return 21;
      case "Late Night": return 24;
      default: return 24;
    }
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Container(
      width: 155,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: meal['mealPicture'] != null
                    ? Image.asset(
                        meal['mealPicture'],
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.fastfood),
                            ),
                      )
                    : Container(
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.fastfood),
                      ),
              ),
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.star_border, color: Colors.white),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal['mealName'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12),
                    const SizedBox(width: 4),
                    Text("Est. ${meal['cookingTime']}",
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellowAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size.fromHeight(30),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MealDetailsPage(
                          mealId: meal['mealID'],
                        ),
                      ),
                    );
                  },
                  child: const Text("VIEW INSTRUCTIONS"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> meals) {
    if (meals.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 0.4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const Text("Browse All",
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: meals.map(_buildMealCard).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search meals...',
                    suffixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
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
                  final currentTime = _getCurrentMealTime();
                  
                  // Filter by search query first
                  var filteredMeals = _filterMealsByName(allMeals, _searchQuery);
                  
                  // Then filter by time
                  final currentMeals = _filterMealsByTime(filteredMeals, "Current");
                  final otherMeals = filteredMeals
                      .where((meal) => !currentMeals.contains(meal))
                      .toList();

                  // Sort alphabetically
                  final sortedCurrentMeals = _sortMeals(currentMeals);
                  final sortedOtherMeals = _sortMeals(otherMeals);

                  return ListView(
                    children: [
                      if (sortedCurrentMeals.isNotEmpty)
                        _buildSection(_getMealTimeGreeting(currentTime), sortedCurrentMeals),
                      if (sortedOtherMeals.isNotEmpty)
                        _buildSection("Other Meal Options", sortedOtherMeals),
                      if (filteredMeals.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("No meals found matching your search"),
                          ),
                        ),
                    ],
                  );
                }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: const Color(0xEBE7D2),
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MealScanPage()),
              );
              break;
            case 1:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const HomePage(title: 'HealthTingi')),
                (route) => false,
              );
              break;
            case 2:
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetPlanPage()),
              );
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