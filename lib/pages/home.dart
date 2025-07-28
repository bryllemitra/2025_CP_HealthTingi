import 'package:flutter/material.dart';
import 'budget_plan.dart';
import 'meal_scan.dart';
import 'meal_details.dart';
import '../searchIngredient/meal_search.dart';
import '../searchIngredient/favorites.dart';
import 'navigation.dart';
import '../database/db_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> popularRecipes = [];
  List<Map<String, dynamic>> allMeals = [];
  List<Map<String, dynamic>> searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _loadPopularRecipes();
    _loadAllMeals();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPopularRecipes() async {
    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getAllMeals();
    
    setState(() {
      popularRecipes = meals.map((meal) => {
        'id': meal['mealID'],
        'name': meal['mealName'],
        'image': meal['mealPicture'] ?? 'assets/${meal['mealName'].toLowerCase().replaceAll(' ', '_')}.jpg',
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        showSearchResults = false;
      });
      return;
    }

    setState(() {
      searchResults = allMeals.where((meal) {
        return meal['mealName'].toString().toLowerCase().contains(query);
      }).toList();
      showSearchResults = true;
    });
  }

  void _performSearch() {
    if (_searchController.text.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSearchPage(),
      ),
    );
  }

  // Add this method to handle missing images
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

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MealScanPage()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MealSearchPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BudgetPlanPage()),
        );
        break;
    }
  }

  Widget _buildCategoryButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map(
            (cat) => SizedBox(
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
                onPressed: () {},
                child: Text(cat, style: const TextStyle(fontSize: 12)),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSpecialsCard() {
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
          Text("See more recipes →",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPopularRecipes() {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularRecipes.length,
        itemBuilder: (context, index) {
          final recipe = popularRecipes[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealDetailsPage(mealId: recipe['id']),
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
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: _buildMealImage(recipe['image']),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      recipe['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!showSearchResults || searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final meal = searchResults[index];
          return ListTile(
            leading: meal['mealPicture'] != null
                ? Image.asset(
                    meal['mealPicture'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.fastfood);
                    },
                  )
                : const Icon(Icons.fastfood),
            title: Text(meal['mealName']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealDetailsPage(mealId: meal['mealID']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      drawer: const NavigationDrawerWidget(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
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
                MaterialPageRoute(builder: (context) => const FavoritesPage()),
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
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2))
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
                          onSubmitted: (value) {
                            _performSearch();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MealScanPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _buildSearchResults(),
              ],
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recipe Categories',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Explore All',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            ),
            const SizedBox(height: 12),
            _buildCategoryButtons(),
            _buildSpecialsCard(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Popular Recipes',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Browse All',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            ),
            const SizedBox(height: 12),
            _buildPopularRecipes(),
          ],
        ),
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.camera_alt, "Scan", 0),
                _navItem(Icons.home, "Home", 1),
                _navItem(Icons.book, "Recipes", 2),
                _navItem(Icons.currency_ruble_rounded, "Budget", 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              )),
        ],
      ),
    );
  }

  final List<String> categories = [
    'APPETIZERS',
    'MAIN DISHES',
    'DESSERTS',
    'SALADS',
    'SOUPS',
    'MORE . . .',
  ];
}