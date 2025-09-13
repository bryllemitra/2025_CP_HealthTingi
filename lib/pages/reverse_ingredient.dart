import 'package:flutter/material.dart';

class ReverseIngredientPage extends StatefulWidget {
  const ReverseIngredientPage({super.key});

  @override
  State<ReverseIngredientPage> createState() => _ReverseIngredientPageState();
}

class _ReverseIngredientPageState extends State<ReverseIngredientPage> {
  List<String> allIngredients = [
    'Sayote',
    'Bagoong',
    'Small Onion',
    'Garlic',
    'Tomato',
    'Oil',
    'Soy Sauce',
  ];

  Set<String> crossedOutIngredients = {};
  List<String> recentlyRemovedIngredients = [];
  Map<String, bool> alternativeIngredients = {};
  bool showAlternatives = false;

  // Define main/important ingredients and their alternatives
  final Map<String, List<String>> ingredientAlternatives = {
    'Sayote': ['Zucchini', 'Cucumber', 'Chayote squash'],
    'Bagoong': ['Oyster Sauce', 'Patis (Fish Sauce)', 'Shrimp Paste'],
    'Small Onion': ['Red Onion', 'Shallots', 'Leeks'],
    'Garlic': ['Garlic Powder', 'Shallots', 'Onion Powder'],
    'Tomato': ['Tomato Sauce', 'Tomato Paste', 'Red Bell Pepper'],
    'Oil': ['Butter', 'Ghee', 'Coconut Oil'],
    'Soy Sauce': ['Tamari', 'Coconut Aminos', 'Worcestershire Sauce'],
  };

  final List<Map<String, String>> similarMeals = const [
    {'name': 'Ginisang Upo', 'image': 'assets/ginisang_upo.jpg'},
    {'name': 'Ginisang Kalabasa', 'image': 'assets/ginisang_kalabasa.jpg'},
    {'name': 'Tortang Sayote', 'image': 'assets/tortang_sayote.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize alternative ingredients as not selected
    alternativeIngredients = {
      for (var altList in ingredientAlternatives.values)
        for (var alt in altList) alt: false
    };
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.add(ingredient);
      recentlyRemovedIngredients.add(ingredient);
      
      // Show alternatives if a main ingredient is removed
      if (ingredientAlternatives.containsKey(ingredient)) {
        showAlternatives = true;
      }
    });

    // Auto-hide the undo snackbar after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && recentlyRemovedIngredients.contains(ingredient)) {
        setState(() {
          recentlyRemovedIngredients.remove(ingredient);
        });
      }
    });
  }

  void _undoRemoveIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.remove(ingredient);
      recentlyRemovedIngredients.remove(ingredient);
      
      // Check if we should hide alternatives
      if (!crossedOutIngredients.any((ing) => ingredientAlternatives.containsKey(ing))) {
        showAlternatives = false;
      }
    });
  }

  void _toggleAlternativeIngredient(String alternative, bool isSelected) {
    setState(() {
      alternativeIngredients[alternative] = isSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F2DF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reverse Ingredients',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Ingredients',
                style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: Colors.white,
              ),
              child: Column(
                children: allIngredients.map((ingredient) {
                  final isCrossed = crossedOutIngredients.contains(ingredient);
                  return ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.red),
                      onPressed: () => _removeIngredient(ingredient),
                    ),
                    title: Text(
                      ingredient,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        decoration: isCrossed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: isCrossed ? Colors.grey : Colors.black,
                      ),
                    ),
                    trailing: isCrossed
                        ? IconButton(
                            icon: const Icon(Icons.undo, size: 20, color: Colors.blue),
                            onPressed: () => _undoRemoveIngredient(ingredient),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
            
            // Show undo snackbar for recently removed ingredients
            if (recentlyRemovedIngredients.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Removed: ${recentlyRemovedIngredients.join(', ')}',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final lastRemoved = recentlyRemovedIngredients.last;
                        _undoRemoveIngredient(lastRemoved);
                      },
                      child: const Text(
                        'UNDO',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Alternative Ingredients Section (only shown when main ingredients are removed)
            if (showAlternatives) ...[
              const Text('Alternative Ingredients',
                  style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Text('Prices and taste may vary',
                  style: TextStyle(fontSize: 12, fontFamily: 'Orbitron')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  color: Colors.white,
                ),
                child: Column(
                  children: crossedOutIngredients
                      .where((ingredient) => ingredientAlternatives.containsKey(ingredient))
                      .expand((ingredient) => ingredientAlternatives[ingredient]!)
                      .map((alternative) {
                    return CheckboxListTile(
                      title: Text(alternative, style: const TextStyle(fontFamily: 'Orbitron')),
                      value: alternativeIngredients[alternative] ?? false,
                      onChanged: (val) {
                        _toggleAlternativeIngredient(alternative, val ?? false);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const Text('Meals with Similar Ingredients',
                style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: similarMeals.length,
                itemBuilder: (context, index) {
                  final meal = similarMeals[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          meal['image']!,
                          width: 60,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 60,
                            height: 50,
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood, size: 24),
                          ),
                        ),
                      ),
                      title: Text(
                        meal['name']!,
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {}, // Optional: Add navigation here
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}