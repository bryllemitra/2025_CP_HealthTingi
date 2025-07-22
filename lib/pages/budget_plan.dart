import 'package:flutter/material.dart';
import 'home.dart';
import 'meal_scan.dart';
import '../searchIngredient/meal_search.dart';
import 'navigation.dart'; // ✅ Import the reusable drawer

class BudgetPlanPage extends StatelessWidget {
  const BudgetPlanPage({super.key});

  final List<Map<String, dynamic>> budgetMeals = const [
    {
      'budget': 50,
      'meals': [
        {
          'name': 'Ginataang Gulay',
          'price': 45.00,
          'image': 'assets/ginataang_gulay.jpg'
        },
        {
          'name': 'Ginisang Upo',
          'price': 40.00,
          'image': 'assets/ginisang_upo.jpg'
        },
      ],
    },
    {
      'budget': 70,
      'meals': [
        {
          'name': 'Ginisang Sayote',
          'price': 51.00,
          'image': 'assets/ginisang_sayote.jpg'
        },
        {'name': 'Laing', 'price': 65.00, 'image': 'assets/laing.jpg'},
        {
          'name': 'Ginisang Kalabasa',
          'price': 60.00,
          'image': 'assets/ginisang_kalabasa.jpg'
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf3f2df),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F2DF),
        title: const Text(
          'Budget Meal Planner',
          style: TextStyle(
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
        actions: const [
          Icon(Icons.info_outline, color: Colors.black),
        ],
        elevation: 0,
      ),
      drawer: const NavigationDrawerWidget(), // ✅ Reusable sidebar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellowAccent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter Budget (in numbers)",
                    style: TextStyle(fontFamily: 'Orbitron'),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    style: const TextStyle(fontFamily: 'Orbitron'),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...budgetMeals
                .map((section) => _buildBudgetSection(context, section))
                .toList(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: const Color(0xEBE7D2),
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const HomePage(title: 'HealthTingi')),
                (route) => false,
              );
              break;
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
              break; // Already on Budget
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Recipes'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: 'Budget'),
        ],
      ),
    );
  }

  Widget _buildBudgetSection(
      BuildContext context, Map<String, dynamic> section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Meals at Php ${section['budget']}",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 12),
        ...section['meals']
            .map<Widget>((meal) => _buildMealCard(context, meal))
            .toList(),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerRight,
          child: Text("See more →", style: TextStyle(fontFamily: 'Orbitron')),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, Map<String, dynamic> meal) {
    return GestureDetector(
      onTap: () {
        if (meal['name'] == 'Ginisang Sayote') {
          Navigator.pushNamed(context, '/meal-details');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                meal['image'],
                width: 80,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal['name'],
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Estimated at Php ${meal['price'].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  )
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
