import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/home.dart';
import '../pages/budget_plan.dart';
import '../pages/meal_scan.dart';
import '../pages/meal_details.dart';
import 'meal_search2.dart';

class MealSearchPage extends StatefulWidget {
  final int userId;

  const MealSearchPage({super.key, required this.userId});

  @override
  State<MealSearchPage> createState() => _MealSearchPageState();
}

class _MealSearchPageState extends State<MealSearchPage> {
  late Future<List<Map<String, dynamic>>> _mealsFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<int> _favoriteMealIds = {};

  @override
  void initState() {
    super.initState();
    _mealsFuture = _fetchMeals();
    _searchController.addListener(_onSearchChanged);
    if (widget.userId != 0) { // Only load favorites for registered users
      _loadUserFavorites();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserFavorites() async {
    final user = await _dbHelper.getUserById(widget.userId);
    if (user != null && user['favorites'] != null) {
      final favorites = user['favorites'].toString();
      setState(() {
        _favoriteMealIds = favorites.split(',').where((id) => id.isNotEmpty).map(int.parse).toSet();
      });
    }
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

  Future<void> _toggleFavorite(int mealId) async {
    if (widget.userId == 0) return; // Skip for guests
    
    try {
      final user = await _dbHelper.getUserById(widget.userId);
      if (user == null) return;

      final isFavorite = _favoriteMealIds.contains(mealId);
      final newFavorites = Set<int>.from(_favoriteMealIds);

      if (isFavorite) {
        newFavorites.remove(mealId);
      } else {
        newFavorites.add(mealId);
      }

      await _dbHelper.updateUser(widget.userId, {
        'favorites': newFavorites.join(','),
      });

      setState(() {
        _favoriteMealIds = newFavorites;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: ${e.toString()}')),
      );
    }
  }

  DateTime _getPhilippineTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 8));
  }

  String _getCurrentMealTime() {
    final phTime = _getPhilippineTime();
    final hour = phTime.hour;

    // Dinner extends until 23:59, then switches to Breakfast at 00:00
    if (hour >= 0 && hour < 5) return "Breakfast"; // Removed Late Night case
    if (hour >= 5 && hour < 10) return "Breakfast";
    if (hour >= 10 && hour < 14) return "Lunch";
    if (hour >= 14 && hour < 17) return "Merienda";
    if (hour >= 17) return "Dinner"; // Dinner from 17:00 to 23:59
    return "Breakfast"; // Default to Breakfast
  }

  String _getMealTimeGreeting(String time) {
    switch (time) {
      case "Breakfast": return "Here's your Breakfast!";
      case "Lunch": return "Get Ready For Lunch!";
      case "Merienda": return "Merienda Time!";
      case "Dinner": return "Dinner is Served!";
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
          // Special handling for dinner (17:00 to 23:59)
          if (currentHour >= 17) {
            return currentHour >= fromHour && (toHour > 23 || fromHour >= 17);
          }
          // Removed Late Night special handling
          return currentHour >= fromHour && currentHour < toHour;
        } else {
          // For specific time filters
          if (time == "Dinner") {
            // Dinner meals should be available from 17:00 onward
            return fromHour >= 17;
          } else {
            return (fromHour >= _getStartHour(time) && toHour <= _getEndHour(time));
          }
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
      default: return 0;
    }
  }

  int _getEndHour(String time) {
    switch (time) {
      case "Breakfast": return 10;
      case "Lunch": return 14;
      case "Merienda": return 17;
      case "Dinner": return 24; // Dinner extends until 23:59
      default: return 24;
    }
  }

  List<Map<String, String>> _getTimeBasedSections(String currentTime) {
    switch (currentTime) {
      case "Breakfast":
        return [
          {'title': 'Lunch', 'time': 'Lunch'},
          {'title': 'Merienda', 'time': 'Merienda'},
          {'title': 'Dinner', 'time': 'Dinner'},
        ];
      case "Lunch":
        return [
          {'title': 'Merienda', 'time': 'Merienda'},
          {'title': 'Dinner', 'time': 'Dinner'},
          {'title': 'Breakfast', 'time': 'Breakfast'},
        ];
      case "Merienda":
        return [
          {'title': 'Dinner', 'time': 'Dinner'},
          {'title': 'Breakfast', 'time': 'Breakfast'},
          {'title': 'Lunch', 'time': 'Lunch'},
        ];
      case "Dinner":
        return [
          {'title': 'Breakfast', 'time': 'Breakfast'},
          {'title': 'Lunch', 'time': 'Lunch'},
          {'title': 'Merienda', 'time': 'Merienda'},
        ];
      default:
        return [];
    }
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final isFavorite = widget.userId != 0 && _favoriteMealIds.contains(meal['mealID']);
    
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
              if (widget.userId != 0) // Only show favorite button for registered users
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(meal['mealID']),
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.yellow : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal['mealName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "Est. ${meal['cookingTime']}",
                      style: const TextStyle(fontSize: 10),
                    ),
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
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
                  child: const Text("VIEW INSTRUCTIONS"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> meals, String timeFilter) {
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MealSearch2Page(
                        userId: widget.userId,
                        timeFilter: timeFilter,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Browse All",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
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
                      color: Colors.black26, 
                      blurRadius: 4, 
                      offset: Offset(2, 2)
                    ),
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
                  final timeBasedSections = _getTimeBasedSections(currentTime);
                  
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

                  // Build time-based sections
                  final timeSections = timeBasedSections.map((section) {
                    final timeMeals = _filterMealsByTime(filteredMeals, section['time']!);
                    return _buildSection(
                      section['title']!,
                      _sortMeals(timeMeals),
                      section['time']!
                    );
                  }).toList();

                  return ListView(
                    children: [
                      if (sortedCurrentMeals.isNotEmpty)
                        _buildSection(
                          _getMealTimeGreeting(currentTime), 
                          sortedCurrentMeals,
                          "Current"
                        ),
                      ...timeSections,
                      if (sortedOtherMeals.isNotEmpty)
                        _buildSection("Other Meal Options", sortedOtherMeals, "All"),
                      if (filteredMeals.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("No meals found matching your search"),
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
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetPlanPage(userId: widget.userId),
                ),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Recipes'),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: 'Recipes'),
        ],
      ),
    );
  }
}