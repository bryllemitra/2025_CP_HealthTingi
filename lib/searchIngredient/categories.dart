import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../pages/meal_details.dart';

class CategoryPage extends StatefulWidget {
  final String category;
  final int userId;

  const CategoryPage({
    super.key,
    required this.category,
    required this.userId,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Map<String, dynamic>> meals = [];
  bool isLoading = true;
  String? errorMessage;
  Set<int> favoriteMealIds = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryMeals();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserById(widget.userId);
    if (user != null && user['favorites'] != null) {
      final favorites = user['favorites'].toString();
      setState(() {
        favoriteMealIds = favorites.split(',').where((id) => id.isNotEmpty).map(int.parse).toSet();
      });
    }
  }

  Future<void> _loadCategoryMeals() async {
    try {
      final dbHelper = DatabaseHelper();
      final allMeals = await dbHelper.getAllMeals();
      
      setState(() {
        meals = allMeals.where((meal) {
          final categories = (meal['category'] as String?)?.split(', ') ?? [];
          return categories.contains(widget.category);
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load meals: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(int mealId) async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      if (user == null) return;

      final isFavorite = favoriteMealIds.contains(mealId);
      final newFavorites = Set<int>.from(favoriteMealIds);

      if (isFavorite) {
        newFavorites.remove(mealId);
      } else {
        newFavorites.add(mealId);
      }

      await dbHelper.updateUser(widget.userId, {
        'favorites': newFavorites.join(','),
      });

      setState(() {
        favoriteMealIds = newFavorites;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: ${e.toString()}')),
      );
    }
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
        title: Text(
          widget.category,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : meals.isEmpty
                  ? const Center(child: Text('No meals found in this category'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 240,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        final meal = meals[index];
                        final isFavorite = favoriteMealIds.contains(meal['mealID']);
                        
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
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
                                        'Php ${meal['price']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
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
                                      'VIEW RECIPE',
                                      style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}