import 'package:flutter/material.dart';
import 'ingredient_details.dart';
import '../pages/meal_scan.dart';

class ScannedIngredientPage extends StatelessWidget {
  final int userId;
  final List<String>? detectedIngredients;

  const ScannedIngredientPage({
    super.key, 
    required this.userId,
    this.detectedIngredients,
  });

  @override
  Widget build(BuildContext context) {
    final ingredients = detectedIngredients ?? ['Chicken', 'Sayote', 'Petchay'];

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
                builder: (context) => MealScanPage(userId: userId),
              ),
            );
          },
        ),
        title: const Text(
          "Ingredient/s",
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
              "Can't scan it? Search your ingredient here.",
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
                        "Add ingredients",
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
              "Detected",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Divider(thickness: 1),
            ...ingredients.map((ingredient) => Column(
                  children: [
                    InkWell(
                      onTap: () {
                        if (ingredient == "Sayote" || ingredient.toLowerCase().contains("sayote")) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IngredientDetailsPage(
                                userId: userId,
                                ingredientName: ingredient,
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.close, size: 18),
                          Text(
                            ingredient,
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 14,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                    ),
                    const Divider(thickness: 1),
                  ],
                )),
            const Text(
              "Recipe Suggestion",
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
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
                          "A classic Filipino comfort dish — a light, gingery chicken soup that's both nourishing and flavorful.",
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
                            // TODO: Navigate to recipe detail with userId
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