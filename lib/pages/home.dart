// Modified pages/home.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:currency_code_to_currency_symbol/currency_code_to_currency_symbol.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:async';
import 'budget_plan.dart';
import 'meal_scan.dart';
import 'meal_details.dart';
import '../searchMeals/meal_search.dart';
import '../searchMeals/user_custom.dart';
import '../searchMeals/history.dart'; // Added import for history page
import 'navigation.dart';
import 'index.dart';
import '../information/about_us.dart';
import '../information/fAQs.dart';
import '../database/db_helper.dart';
import '../ingredientScanner/ingredient_details.dart';

class HomePage extends StatefulWidget {
  final String title;
  final int userId;

  const HomePage({super.key, required this.title, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  List<Map<String, dynamic>> popularRecipes = [];
  List<Map<String, dynamic>> allMeals = [];
  List<Map<String, dynamic>> allIngredients = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> recentlyViewedMeals = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  Set<int> _favoriteMealIds = {};
  int _currentPage = 0;
  bool _showAllCategories = false;
  List<String>? _cachedCategories;

  @override
  void initState() {
    super.initState();
    _loadPopularRecipes();
    _loadAllMeals();
    _loadAllIngredients();
    if (widget.userId != 0) {
      _loadUserFavorites();
      _loadRecentlyViewedMeals();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadAllIngredients() async {
    final dbHelper = DatabaseHelper();
    final ingredients = await dbHelper.getAllIngredients();
    setState(() {
      allIngredients = ingredients;
    });
  }

  Future<void> _loadUserFavorites() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserById(widget.userId);
    if (user != null && user['favorites'] != null) {
      final favorites = user['favorites'].toString();
      setState(() {
        _favoriteMealIds = favorites.split(',').where((id) => id.isNotEmpty).map(int.parse).toSet();
      });
    }
  }

  Future<void> _loadPopularRecipes() async {
    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getAllMeals();
    
    setState(() {
      popularRecipes = meals.map((meal) => {
        'id': meal['mealID'],
        'name': meal['mealName'],
        'image': meal['mealPicture'] ?? 'assets/default_meal.jpg',
      }).toList();
    });
  }

  Future<void> _loadAllMeals() async {
    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getAllMeals();
    setState(() {
      allMeals = meals;
    });
  }

  Future<void> _loadRecentlyViewedMeals() async {
    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getRecentlyViewedMeals(widget.userId);
    setState(() {
      recentlyViewedMeals = meals;
    });
  }

  Future<void> _toggleFavorite(int mealId) async {
    if (widget.userId == 0) return;
    
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      if (user == null) return;

      final isFavorite = _favoriteMealIds.contains(mealId);
      final newFavorites = Set<int>.from(_favoriteMealIds);

      if (isFavorite) {
        newFavorites.remove(mealId);
      } else {
        newFavorites.add(mealId);
      }

      await dbHelper.updateUser(widget.userId, {
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _removeOverlay();
      return;
    }

    setState(() {
      searchResults = allMeals.where((meal) {
        return meal['mealName'].toString().toLowerCase().contains(query);
      }).toList();
    });

    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 16,
        top: offset.dy + 120,
        width: size.width - 32,
        child: Material(
          elevation: 4,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final meal = searchResults[index];
                final isFavorite = widget.userId != 0 && _favoriteMealIds.contains(meal['mealID']);
                return ListTile(
                  leading: Image.asset(
                    meal['mealPicture'] ?? 'assets/default_meal.jpg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.fastfood);
                    },
                  ),
                  title: Text(meal['mealName'], style: const TextStyle(fontFamily: 'Poppins')),
                  trailing: widget.userId != 0 
                      ? IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? Colors.yellow : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(meal['mealID']),
                        )
                      : null,
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
                    _searchController.clear();
                    _removeOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _performSearch() {
    _removeOverlay();
    if (_searchController.text.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSearchPage(userId: widget.userId),
      ),
    );
  }

  void _navigateToSearchPage() {
    _removeOverlay();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSearchPage(userId: widget.userId),
      ),
    );
  }

  Widget _buildMealImage(String imagePath) {
    return Image.asset(
      imagePath,
      height: 100,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 100,
          color: Colors.grey[200],
          child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
        );
      },
    );
  }

  Widget _buildIngredientImage(String imagePath) {
    return Image.asset(
      imagePath,
      height: 80,
      width: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 80,
          width: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.fastfood, size: 30, color: Colors.grey),
        );
      },
    );
  }

 Widget _buildPopularRecipeCard(Map<String, dynamic> recipe) {
  final isFavorite = widget.userId != 0 && _favoriteMealIds.contains(recipe['id']);

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MealDetailsPage(
            mealId: recipe['id'],
            userId: widget.userId,
          ),
        ),
      );
    },
    child: Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
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
                child: _buildMealImage(recipe['image']),
              ),
              if (widget.userId != 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(recipe['id']),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white70,
                      size: 20, // Smaller & consistent
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              recipe['name'],
              style: const TextStyle(
                fontFamily: 'Poppins', // Updated to Poppins
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF184E77),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildIngredientCard(Map<String, dynamic> ingredient) {
    final ingredientName = ingredient['ingredientName']?.toString() ?? 'Unknown Ingredient';
    
    final String imagePath;
    if (ingredient['ingredientPicture'] != null) {
      final originalPath = ingredient['ingredientPicture'].toString();
      if (originalPath.contains('ingredients/')) {
        imagePath = originalPath;
      } else {
        final fileName = originalPath.replaceFirst('assets/', '');
        imagePath = 'assets/ingredients/$fileName';
      }
    } else {
      imagePath = 'assets/ingredients/default_ingredient.jpg';
    }
    
    final price = ingredient['price_text'] ?? 
        (ingredient['price'] is double 
            ? (ingredient['price'] as double).toStringAsFixed(2)
            : ingredient['price']?.toString() ?? '0.00');
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IngredientDetailsPage(
              userId: widget.userId,
              ingredientName: ingredientName,
            ),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildIngredientImage(imagePath),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ingredientName,
                style: const TextStyle(
                  fontFamily: 'Poppins', // Updated to Poppins
                  fontWeight: FontWeight.bold, 
                  fontSize: 12,
                  color: Color(0xFF184E77),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Php $price',
                style: TextStyle(
                  fontFamily: 'Poppins', // Updated to Poppins
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);

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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BudgetPlanPage(userId: widget.userId),
          ),
        );
        break;
    }
  }

  Widget _buildCategoryButtons() {
    if (_cachedCategories != null) {
      return _buildCategoryGrid(_cachedCategories!);
    }

    return FutureBuilder<List<String>>(
      future: DatabaseHelper().getAllMealCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No categories found', style: TextStyle(fontFamily: 'Poppins'));
        }
        
        _cachedCategories = snapshot.data!;
        return _buildCategoryGrid(_cachedCategories!);
      },
    );
  }

  Widget _buildCategoryGrid(List<String> categories) {
    final displayedCategories = _showAllCategories ? categories : categories.take(6).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recipe Categories',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Exo', // Updated to EXO
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
            if (categories.length > 6)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllCategories = !_showAllCategories;
                  });
                },
                child: Text(
                  _showAllCategories ? 'See Less' : 'Explore All',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontFamily: 'Poppins', // Updated to Poppins
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: displayedCategories.length,
          itemBuilder: (context, index) {
            final category = displayedCategories[index];
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: const Color(0xFF184E77),
                elevation: 10,
                shadowColor: Colors.greenAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/searchIngredient/categories',
                  arguments: {
                    'category': category,
                    'userId': widget.userId,
                  },
                );
              },
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins', // Updated to Poppins
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPopularRecipes() {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularRecipes.length,
        itemBuilder: (context, index) {
          return _buildPopularRecipeCard(popularRecipes[index]);
        },
      ),
    );
  }

  Widget _buildIngredientsSection() {
    if (allIngredients.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final displayedIngredients = allIngredients.take(10).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Check Your Ingredients',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Exo', // Updated to EXO
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
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayedIngredients.length,
            itemBuilder: (context, index) {
              return _buildIngredientCard(displayedIngredients[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularRecipesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Recipes',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Exo', // Updated to EXO
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
        const SizedBox(height: 16),
        _buildPopularRecipes(),
      ],
    );
  }

  Widget _buildSpecialsCard() {
    if (widget.userId == 0) {
      return const SizedBox.shrink();
    }

    if (recentlyViewedMeals.isEmpty || widget.userId == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 24, bottom: 24),
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
            Text(
              widget.userId == 0 ? "Featured Recipes" : "Today's Specials",
              style: const TextStyle(
                fontSize: 20,
                fontFamily: 'Exo', // Updated to EXO
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
            const SizedBox(height: 8),
            Text(
              widget.userId == 0 
                  ? "Discover delicious recipes to try" 
                  : "Discover new recipes based on your scans",
              style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'), // Updated to Poppins
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MealSearchPage(userId: widget.userId),
                  ),
                );
              },
              child: const Text(
                "See more recipes →",
                style: TextStyle(
                  fontFamily: 'Poppins', // Updated to Poppins
                  fontWeight: FontWeight.bold,
                  color: Colors.yellowAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 24, bottom: 24),
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
            "Recently Viewed",
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Exo', // Updated to EXO
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
          const SizedBox(height: 16),
          CarouselSlider.builder(
            itemCount: recentlyViewedMeals.length,
            options: CarouselOptions(
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              enlargeCenterPage: true,
              viewportFraction: 0.9,
              aspectRatio: 2.0,
              initialPage: 0,
              enableInfiniteScroll: true,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentPage = index;
                });
              },
            ),
            itemBuilder: (context, index, realIndex) {
              final meal = recentlyViewedMeals[index];
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
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                        child: SizedBox(
                          width: 150,
                          height: double.infinity,
                          child: Image.asset(
                            meal['mealPicture'] ?? 'assets/default_meal.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                meal['mealName'],
                                style: const TextStyle(
                                  fontFamily: 'Poppins', // Updated to Poppins
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF184E77),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Php ${meal['price']?.toStringAsFixed(2) ?? '0.00'}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins', // Updated to Poppins
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(recentlyViewedMeals.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestDrawer() {
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
                  fontFamily: 'Exo', // Updated to EXO
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Exo', // Updated to EXO
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
        actions: [
          if (widget.userId != 0)
            IconButton(
              icon: const Icon(Icons.star, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserCustomPage(userId: widget.userId),
                  ),
                );
              },
              tooltip: 'My Customized Meals',
            ),
          if (widget.userId != 0)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryPage(userId: widget.userId),
                  ),
                );
              },
              tooltip: 'History',
            ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: widget.userId != 0 
          ? NavigationDrawerWidget(userId: widget.userId)
          : _buildGuestDrawer(),
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search, color: Color(0xFF184E77)),
                        onPressed: _performSearch,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Search or Scan your ingredients',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.black54, fontFamily: 'Poppins'), // Updated to Poppins
                          ),
                          style: const TextStyle(color: Colors.black87, fontFamily: 'Poppins'), // Updated to Poppins
                          onSubmitted: (value) => _performSearch(),
                          onTap: _navigateToSearchPage,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Color(0xFF184E77)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MealScanPage(userId: widget.userId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildCategoryButtons(),
                _buildSpecialsCard(),
                _buildPopularRecipesSection(),
                _buildIngredientsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF184E77), // Darker blue for better contrast
        selectedItemColor: Color(0xFF184E77),
        unselectedItemColor: Color(0xFF184E77).withOpacity(0.7),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold), // Updated
        unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins'), // Updated
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