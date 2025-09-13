import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

class FavoritesPage extends StatefulWidget {
  final int userId;

  const FavoritesPage({super.key, required this.userId});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> favoriteRecipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    searchController.addListener(_filterFavorites);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      final favorites = user['favorites']?.toString() ?? '';
      if (favorites.isEmpty) {
        setState(() {
          isLoading = false;
          favoriteRecipes = [];
          filteredRecipes = [];
        });
        return;
      }

      final favoriteIds = favorites.split(',').map((id) => int.parse(id)).toList();
      final allMeals = await dbHelper.getAllMeals();
      
      setState(() {
        favoriteRecipes = allMeals.where((meal) {
          return favoriteIds.contains(meal['mealID']);
        }).toList();
        filteredRecipes = List.from(favoriteRecipes);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load favorites: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(int mealId, bool isCurrentlyFavorite) async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      
      if (user == null) return;

      String favorites = user['favorites']?.toString() ?? '';
      List<String> favoriteList = favorites.split(',').where((id) => id.isNotEmpty).toList();

      if (isCurrentlyFavorite) {
        // Remove from favorites
        favoriteList.remove(mealId.toString());
      } else {
        // Add to favorites
        favoriteList.add(mealId.toString());
      }

      // Update user's favorites
      await dbHelper.updateUser(widget.userId, {
        'favorites': favoriteList.join(','),
      });

      // Reload favorites
      await _loadFavorites();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: ${e.toString()}')),
      );
    }
  }

  void _filterFavorites() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredRecipes = List.from(favoriteRecipes);
      } else {
        filteredRecipes = favoriteRecipes.where((recipe) {
          final name = recipe['mealName'].toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
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
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search your favorite recipes',
            hintStyle: const TextStyle(fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFECECEC),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                    },
                  )
                : null,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : favoriteRecipes.isEmpty
                  ? const Center(child: Text('No favorites yet'))
                  : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          if (searchController.text.isNotEmpty && filteredRecipes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Meal not found in favorites',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          Expanded(
                            child: GridView.builder(
                              itemCount: filteredRecipes.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 260,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 12,
                              ),
                              itemBuilder: (context, index) {
                                final recipe = filteredRecipes[index];
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
                                              recipe['mealPicture'] ?? 'assets/default_meal.jpg',
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
                                              onTap: () async {
                                                await _toggleFavorite(
                                                  recipe['mealID'],
                                                  true, // This is always true since we're in favorites page
                                                );
                                              },
                                              child: const Icon(
                                                Icons.star,
                                                color: Colors.yellow,
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
                                              recipe['mealName'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Servings: ${recipe['servings']}',
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
                                                  mealId: recipe['mealID'],
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
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}