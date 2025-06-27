import 'package:flutter/material.dart';
import 'pages/budgetPlan.dart';
import 'pages/mealScan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Grandstander', // 👈 Apply Grandstander globally
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Search Meals'),
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
  final List<String> merienda = ['Halo-Halo', 'Saging Prito', 'Binignit'];
  final List<String> lunch = ['Adobong Manok', 'Sinigang Hipon', 'Chopsuey'];

  int _selectedIndex = 0;

  Widget mealItem(String name) {
    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Already here
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MealScanPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BudgetPlanPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF88A096),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDDE2C6),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2C6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  border: InputBorder.none,
                  hintText: 'Search Meals, Ingredients',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Merienda Section
            const Text(
              'Merienda time!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2C6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: merienda.map((meal) => mealItem(meal)).toList(),
              ),
            ),

            // Lunch Section
            const Text(
              'Not Late for Lunch!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 80),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2C6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: lunch.map((meal) => mealItem(meal)).toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFDDE2C6),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: ''),
        ],
      ),
    );
  }
}
