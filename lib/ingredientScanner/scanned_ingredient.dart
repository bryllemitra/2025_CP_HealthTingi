import 'package:flutter/material.dart';
import 'ingredient_details.dart';
import '../pages/meal_scan.dart';
import '../database/db_helper.dart';

class ScannedIngredientPage extends StatefulWidget {
  final int userId;
  final List<String>? detectedIngredients;

  const ScannedIngredientPage({
    super.key, 
    required this.userId,
    this.detectedIngredients,
  });

  @override
  State<ScannedIngredientPage> createState() => _ScannedIngredientPageState();
}

class _ScannedIngredientPageState extends State<ScannedIngredientPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late List<String> ingredients;
  Map<String, Map<String, dynamic>> _ingredientDetails = {};

  @override
  void initState() {
    super.initState();
    ingredients = widget.detectedIngredients ?? ['Chicken', 'Sayote', 'Petchay'];
    _loadIngredientDetails();
  }

  Future<void> _loadIngredientDetails() async {
    for (var ingredientName in ingredients) {
      try {
        final detail = await _dbHelper.getIngredientByName(ingredientName);
        if (detail != null) {
          setState(() {
            _ingredientDetails[ingredientName] = detail;
          });
        }
      } catch (e) {
        print('Error loading details for $ingredientName: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEBD1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEBD1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MealScanPage(userId: widget.userId),
              ),
            );
          },
        ),
        title: const Text(
          "Scanned Ingredients",
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Can't find an ingredient? Search here:",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Search ingredients...",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Detected Ingredients",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(thickness: 1),
            Expanded(
              child: ListView.builder(
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];
                  final detail = _ingredientDetails[ingredient];
                  
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: detail?['ingredientPicture'] != null
                              ? Image.asset(
                                  detail!['ingredientPicture'],
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.fastfood, size: 20),
                                )
                              : const Icon(Icons.fastfood, size: 20),
                        ),
                        title: Text(
                          ingredient,
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: detail != null
                            ? Text(
                                '${detail['calories'] ?? 'N/A'} kcal',
                                style: const TextStyle(fontSize: 12),
                              )
                            : const Text(
                                'Loading details...',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IngredientDetailsPage(
                                userId: widget.userId,
                                ingredientName: ingredient,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(thickness: 1, height: 1),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Recipe Suggestions",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            // Recipe suggestion card remains the same
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "~45 mins",
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Tinolang Manok",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "A classic Filipino comfort dish with chicken, sayote, and malunggay.",
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF864),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 2),
                          ),
                          onPressed: () {
                            // TODO: Navigate to recipe detail
                          },
                          child: const Text(
                            'View Recipe →',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/tinolang_manok.jpg',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.restaurant, size: 40),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}