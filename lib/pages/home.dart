import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'budget_plan.dart';
import 'meal_scan.dart';
import 'meal_details.dart';
import '../searchIngredient/meal_search.dart';
import '../searchIngredient/favorites.dart';
import 'navigation.dart';
import '../database/db_helper.dart';

class HomePage extends StatefulWidget {
  final String title;
  final int userId;

  const HomePage({super.key, required this.title, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1; // Home is selected by default
  List<Map<String, dynamic>> popularRecipes = [];
  List<Map<String, dynamic>> allMeals = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> recentlyViewedMeals = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  Set<int> _favoriteMealIds = {};
  int _currentPage = 0;
  late PageController _pageController;
  Timer? _carouselTimer;
  bool _showAllCategories = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadPopularRecipes();
    _loadAllMeals();
    _loadUserFavorites();
    _loadRecentlyViewedMeals();
    _searchController.addListener(_onSearchChanged);
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _removeOverlay();
    super.dispose();
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

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && recentlyViewedMeals.isNotEmpty) {
        if (_currentPage < recentlyViewedMeals.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _toggleFavorite(int mealId) async {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
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
                final isFavorite = _favoriteMealIds.contains(meal['mealID']);
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
                  title: Text(meal['mealName']),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.yellow : Colors.grey,
                    ),
                    onPressed: () => _toggleFavorite(meal['mealID']),
                  ),
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

  Widget _buildPopularRecipeCard(Map<String, dynamic> recipe) {
    final isFavorite = _favoriteMealIds.contains(recipe['id']);
    
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: _buildMealImage(recipe['image']),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(recipe['id']),
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
              padding: const EdgeInsets.all(8),
              child: Text(
                recipe['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14
                ),
              ),
            ),
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
        // Already on home page
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
    return FutureBuilder<List<String>>(
      future: DatabaseHelper().getAllMealCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No categories found');
        }
        
        final categories = snapshot.data!;
        final displayedCategories = _showAllCategories ? categories : categories.take(6).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recipe Categories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (!_showAllCategories && categories.length > 6)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllCategories = true;
                      });
                    },
                    child: const Text(
                      'Explore All',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: displayedCategories.map((category) => SizedBox(
                width: 110,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
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
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )).toList(),
            ),
          ],
        );
      },
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

  Widget _buildSpecialsCard() {
    if (recentlyViewedMeals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 16, bottom: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFF66),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Specials",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text("Discover new recipes based on your scans"),
            SizedBox(height: 8),
            Text(
              "See more recipes →",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFF66),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recently Viewed",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150, // Reduced height for the new layout
            child: PageView.builder(
              controller: _pageController,
              itemCount: recentlyViewedMeals.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
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
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Row( // Changed from Column to Row for horizontal layout
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Square image on the left
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                          child: Image.asset(
                            meal['mealPicture'] ?? 'assets/default_meal.jpg',
                            height: 150, // Square height
                            width: 150,  // Square width
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                width: 150,
                                color: Colors.grey[200],
                                child: const Icon(Icons.fastfood,
                                    size: 40, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        // Text content on the right
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16, // Slightly larger font
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Php ${meal['price']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  meal['content']?.toString().split('.').first ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ),
                                  maxLines: 3, // Allow more lines for content
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
          ),
          const SizedBox(height: 8),
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
                      ? Colors.black
                      : Colors.black.withOpacity(0.3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      drawer: NavigationDrawerWidget(userId: widget.userId),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
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
            icon: const Icon(Icons.star, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesPage(userId: widget.userId),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Icon(Icons.settings, color: Colors.black),
          const SizedBox(width: 16),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _performSearch,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search or Scan your ingredients',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) => _performSearch(),
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          _showOverlay();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
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
            
            // Recipe Categories
            _buildCategoryButtons(),
            
            // Specials Card
            _buildSpecialsCard(),
            
            // Popular Recipes
            const Text(
              'Popular Recipes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPopularRecipes(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: const Color(0xEBE7D2),
        onTap: _onItemTapped,
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