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
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10)),
                child: Image.asset(
                  meal['mealPicture'] ?? 'assets/default_meal.jpg',
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood,
                          size: 40, color: Colors.grey),
                    );
                  },
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal['mealName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Est. ${meal['cookingTime']}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1FF57),
                foregroundColor: Colors.black,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                'VIEW INSTRUCTIONS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search ${_getTitle().toLowerCase()}',
            hintStyle: const TextStyle(fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFECECEC),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No meals available'));
          }

          // First filter by time
          var filteredMeals = _filterMealsByTime(snapshot.data!, widget.timeFilter);
          
          // Then filter by search query
          filteredMeals = _filterMealsByName(filteredMeals, _searchQuery);

          if (filteredMeals.isEmpty) {
            return const Center(
              child: Text('No meals found matching your criteria'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              itemCount: filteredMeals.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 240,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                return _buildMealCard(filteredMeals[index]);
              },
            ),
          );
        },
      ),
    );
  }
}