import 'package:flutter/material.dart';
import '../pages/home.dart';
import '../pages/budget_plan.dart';
import '../pages/meal_scan.dart';

class MealSearchPage extends StatelessWidget {
  const MealSearchPage({super.key});

  final List<Map<String, dynamic>> merienda = const [
    {
      'title': 'Halo-Halo',
      'time': '10-15 Minutes',
      'image': 'assets/halo_halo.jpg',
    },
    {
      'title': 'Saging Prito',
      'time': '5-7 Minutes',
      'image': 'assets/saging prito.jpg',
    },
    {
      'title': 'Binignit',
      'time': '30-40 Minutes',
      'image': 'assets/binignit.jpg',
    },
    {
      'title': 'Biko',
      'time': '40-50 Minutes',
      'image': 'assets/biko.jpg',
    },
  ];

  final List<Map<String, dynamic>> lunch = const [
    {
      'title': 'Adobong Manok',
      'time': '35-45 Minutes',
      'image': 'assets/adobong_manok.jpg',
    },
    {
      'title': 'Sinigang na Isda',
      'time': '30-40 Minutes',
      'image': 'assets/sinigang.jpg',
    },
    {
      'title': 'Chopsuey',
      'time': '25-35 Minutes',
      'image': 'assets/chopsuey.jpg',
    },
    {
      'title': 'Ginisang Sayote',
      'time': '15-20 Minutes',
      'image': 'assets/ginisang_sayote.jpg',
    },
  ];

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MealScanPage()),
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => const HomePage(title: 'HealthTingi')),
          (route) => false,
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BudgetPlanPage()),
        );
        break;
    }
  }

  Widget _buildMealCard(Map<String, dynamic> item) {
    return Container(
      width: 155,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  item['image'],
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.star_border, color: Colors.white),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12),
                    const SizedBox(width: 4),
                    Text("Est. ${item['time']}",
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellowAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size.fromHeight(30),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: () {},
                  child: const Text("VIEW INSTRUCTIONS"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> meals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 0.4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const Text("Browse All",
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: meals.map(_buildMealCard).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                  ],
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search or Scan your ingredients...',
                    suffixIcon: Icon(Icons.tune),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildSection("Merienda time!", merienda),
                  _buildSection("Not Late for Lunch!", lunch),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: const Color(0xEBE7D2),
        onTap: (index) => _onItemTapped(context, index),
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
