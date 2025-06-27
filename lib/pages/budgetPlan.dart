import 'package:flutter/material.dart';
import '../main.dart'; // ✅ Import the main.dart to access MyHomePage

class BudgetPlanPage extends StatelessWidget {
  const BudgetPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF88A096),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDDE2C6),
        title: const Text(
          'Budget Meal Planner',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'Grandstander',
          ),
        ),
        centerTitle: true,
        leading: const Icon(Icons.menu, color: Colors.black),
        actions: const [Icon(Icons.info_outline, color: Colors.black)],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget Input
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2C6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                style: const TextStyle(fontFamily: 'Grandstander'),
                decoration: InputDecoration(
                  hintText: 'Enter Budget',
                  hintStyle: const TextStyle(fontFamily: 'Grandstander'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Meals at Php 50
            const Text(
              'Meals at Php 50',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Grandstander',
              ),
            ),
            const SizedBox(height: 8),
            _mealList([
              'Ginataang Gulay',
              'Laing',
              'Ginisang Sayote',
            ]),
            const SizedBox(height: 20),

            // Meals at Php 70
            const Text(
              'Meals at Php 70',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Grandstander',
              ),
            ),
            const SizedBox(height: 8),
            _mealList([
              'Laing',
              'Ginisang Sayote',
            ]),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFDDE2C6),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: 2, // Peso icon is selected
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MyHomePage(title: 'Search Meals'),
                ),
              );
              break;
            case 1:
              // Optional: Add camera or scan feature here
              break;
            case 2:
              // Stay on current page
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: ''),
        ],
      ),
    );
  }

  Widget _mealList(List<String> meals) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE2C6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: meals
            .map(
              (meal) => ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  meal,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Grandstander',
                  ),
                ),
                subtitle: const Text(
                  'Estimated at Php 0.00',
                  style: TextStyle(fontFamily: 'Grandstander'),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
