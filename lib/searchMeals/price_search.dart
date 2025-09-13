import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

class PriceSearchPage extends StatefulWidget {
  final int userId;
  final String priceRange;

  const PriceSearchPage({
    super.key,
    required this.userId,
    required this.priceRange,
  });

  @override
  State<PriceSearchPage> createState() => _PriceSearchPageState();
}

class _PriceSearchPageState extends State<PriceSearchPage> {
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
    return meals.map((meal) {
      if (meal['price'] is int) {
        meal['price'] = (meal['price'] as int).toDouble();
      }
      return meal;
    }).toList();
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

  List<Map<String, dynamic>> _filterMealsByPriceRange(
      List<Map<String, dynamic>> meals) {
    switch (widget.priceRange) {
      case '50':
        return meals.where((meal) {
          final price = (meal['price'] as num).toDouble();
          return price >= 0 && price <= 50;
        }).toList();
      case '70':
        return meals.where((meal) {
          final price = (meal['price'] as num).toDouble();
          return price >= 51 && price <= 70;
        }).toList();
      case '100':
        return meals.where((meal) {
          final price = (meal['price'] as num).toDouble();
          return price >= 71 && price <= 100;
        }).toList();
      case '100+':
        return meals.where((meal) {
          final price = (meal['price'] as num).toDouble();
          return price > 100;
        }).toList();
      default:
        // For "Near X" case
        if (widget.priceRange.startsWith('Near')) {
          final budget = double.tryParse(
              widget.priceRange.replaceAll('Near', '').trim()) ?? 0;
          meals.sort((a, b) {
            final aPrice = (a['price'] as num).toDouble();
            final bPrice = (b['price'] as num).toDouble();
            final aDiff = (aPrice - budget).abs();
            final bDiff = (bPrice - budget).abs();
            return aDiff.compareTo(bDiff);
          });
          return meals;
        }
        return meals;
    }
  }

  List<Map<String, dynamic>> _filterMealsByName(List<Map<String, dynamic>> meals, String query) {
    if (query.isEmpty) return meals;
    return meals.where((meal) {
      return meal['mealName'].toString().toLowerCase().contains(query);
    }).toList();
  }

  String _getTitle() {
    if (widget.priceRange.startsWith('Near')) {
      return 'Meals near ${widget.priceRange.replaceAll('Near', '')}';
    }
    switch (widget.priceRange) {
      case '50':
        return 'Meals under ₱50';
      case '70':
        return 'Meals ₱51-₱70';
      case '100':
        return 'Meals ₱71-₱100';
      case '100+':
        return 'Meals over ₱100';
      default:
        return 'Budget Meals';
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
                  'Php ${(meal['price'] as num).toStringAsFixed(2)}',
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

          // First filter by price range
          var filteredMeals = _filterMealsByPriceRange(snapshot.data!);
          
          // Then filter by search query
          filteredMeals = _filterMealsByName(filteredMeals, _searchQuery);

          if (filteredMeals.isEmpty) {
            return const Center(
              child: Text('No meals found matching your criteria'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                if (_searchController.text.isNotEmpty && filteredMeals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Meal not found in this price range',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Expanded(
                  child: GridView.builder(
                    itemCount: filteredMeals.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 260,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      return _buildMealCard(filteredMeals[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}