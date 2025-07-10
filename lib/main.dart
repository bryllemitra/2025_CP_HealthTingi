import 'package:flutter/material.dart';
import 'pages/budgetPlan.dart';
import 'pages/mealScan.dart';
import 'searchIngredient/mealSrch.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthTingi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Orbitron',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellowAccent),
      ),
      home: const MyHomePage(title: 'HealthTingi'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<String> categories = [
    'APPETIZERS',
    'MAIN DISHES',
    'DESSERTS',
    'SALADS',
    'SOUPS',
    'MORE . . .',
  ];

  final List<Map<String, String>> popularRecipes = [
    {'name': 'Tinolang Manok', 'image': 'assets/tinola.jpg'},
    {'name': 'Escabeche', 'image': 'assets/escabeche.jpg'},
  ];

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);

    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MealSearchPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MealScanPage()),
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
          return Container(
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
                  child: Image.asset(
                    recipe['image']!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    recipe['name']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: const Icon(Icons.menu, color: Colors.black),
        actions: const [
          Icon(Icons.star_border, color: Colors.black),
          SizedBox(width: 8),
          Icon(Icons.settings, color: Colors.black),
          SizedBox(width: 16),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  suffixIcon: Icon(Icons.camera_alt),
                  hintText: 'Search or Scan your ingredients',
                  border: InputBorder.none,
                ),
              ),
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
                _navItem(Icons.home, "Home", 0),
                _navItem(Icons.book, "Recipes", 1),
                _navItem(Icons.camera_alt, "Scan", 2),
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
}
