import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

class MealSearch2Page extends StatefulWidget {
  final int userId;
  final String timeFilter;

  const MealSearch2Page({
    super.key,
    required this.userId,
    required this.timeFilter,
  });

  @override
  State<MealSearch2Page> createState() => _MealSearch2PageState();
}

class _MealSearch2PageState extends State<MealSearch2Page> {
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
    if (widget.userId != 0) {
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
    if (widget.userId == 0) return;

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

  List<Map<String, dynamic>> _filterMealsByTime(
      List<Map<String, dynamic>> meals, String time) {
    return meals.where((meal) {
      try {
        final fromHour = int.parse(meal['availableFrom']?.split(':')[0] ?? '0');
        final toHour = int.parse(meal['availableTo']?.split(':')[0] ?? '24');

        if (time == "Current") {
          return _isCurrentTime(fromHour, toHour);
        } else if (time == "Breakfast") {
          return (fromHour >= 5 && toHour <= 10);
        } else if (time == "Lunch") {
          return (fromHour >= 10 && toHour <= 14);
        } else if (time == "Merienda") {
          return (fromHour >= 14 && toHour <= 17);
        } else if (time == "Dinner") {
          return (fromHour >= 17 && toHour <= 21);
        } else if (time == "Late Night") {
          return (fromHour >= 21 || toHour <= 5);
        }
        return true;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  bool _isCurrentTime(int fromHour, int toHour) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final currentHour = now.hour;
    return currentHour >= fromHour && currentHour < toHour;
  }

  List<Map<String, dynamic>> _filterMealsByName(List<Map<String, dynamic>> meals, String query) {
    if (query.isEmpty) return meals;
    return meals.where((meal) {
      return meal['mealName'].toString().toLowerCase().contains(query);
    }).toList();
  }

  String _getTitle() {
    switch (widget.timeFilter) {
      case "Current":
        return "Current Time Meals";
      case "Breakfast":
        return "Breakfast Meals";
      case "Lunch":
        return "Lunch Meals";
      case "Merienda":
        return "Merienda Meals";
      case "Dinner":
        return "Dinner Meals";
      case "Late Night":
        return "Late Night Meals";
      default:
        return "All Meals";
    }
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final isFavorite = widget.userId != 0 && _favoriteMealIds.contains(meal['mealID']);
    final price = meal['price'] is double
        ? (meal['price'] as double).toStringAsFixed(2)
        : meal['price']?.toString() ?? '0.00';

    return Container(
      width: 160,
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: Image.asset(
                    meal['mealPicture'] ?? 'assets/default_meal.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // NEW HEART — EXACTLY LIKE POPULAR RECIPES
              if (widget.userId != 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(meal['mealID']),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      meal['mealName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF184E77),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: Color(0xFF184E77)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Est. ${meal['cookingTime']}",
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Php $price",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB5E48C),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size.fromHeight(30),
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
                    child: const Text(
                      "VIEW INSTRUCTIONS",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search ${_getTitle().toLowerCase()}',
                            hintStyle: const TextStyle(fontSize: 14, color: Colors.black54),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Color(0xFF184E77)),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : const Icon(Icons.search, color: Color(0xFF184E77)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _mealsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No meals available', style: TextStyle(color: Colors.white)));
                    }

                    var filteredMeals = _filterMealsByTime(snapshot.data!, widget.timeFilter);
                    filteredMeals = _filterMealsByName(filteredMeals, _searchQuery);

                    if (filteredMeals.isEmpty) {
                      return const Center(
                        child: Text('No meals found matching your criteria', style: TextStyle(color: Colors.white)),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12.0),
                      itemCount: filteredMeals.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        return _buildMealCard(filteredMeals[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}