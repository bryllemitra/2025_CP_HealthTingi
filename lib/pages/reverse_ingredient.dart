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
  List<Map<String, dynamic>> recentChanges = [];
  Map<String, String?> selectedAlternatives = {};
  Map<String, String> ingredientDisplay = {};
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
    selectedAlternatives = {};
    ingredientDisplay = {};
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.add(ingredient);
      recentChanges.add({'type': 'remove', 'ingredient': ingredient});

      // Show alternatives if a main ingredient is removed
      if (ingredientAlternatives.containsKey(ingredient)) {
        showAlternatives = true;
      }
    });

    // Auto-hide the undo snackbar after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          recentChanges.removeWhere((change) =>
              change['type'] == 'remove' && change['ingredient'] == ingredient);
        });
      }
    });
  }

  void _undoRemoveIngredient(String ingredient) {
    setState(() {
      crossedOutIngredients.remove(ingredient);

      // Check if we should hide alternatives
      if (!crossedOutIngredients.any((ing) => ingredientAlternatives.containsKey(ing))) {
        showAlternatives = false;
      }
    });
  }

  void _setReplacement(String original, String alt) {
    setState(() {
      selectedAlternatives[original] = alt;
      ingredientDisplay[original] = alt;
      crossedOutIngredients.remove(original);
      recentChanges.add({'type': 'replace', 'original': original, 'alt': alt});
    });

    // Auto-hide the undo snackbar after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          recentChanges.removeWhere((change) =>
              change['type'] == 'replace' && change['original'] == original);
        });
      }
    });
  }

  void _undoReplace(String original) {
    setState(() {
      selectedAlternatives.remove(original);
      ingredientDisplay.remove(original);
      crossedOutIngredients.remove(original); // Bring back without cross

      // Check if we should hide alternatives
      if (!crossedOutIngredients.any((ing) => ingredientAlternatives.containsKey(ing))) {
        showAlternatives = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reverse Ingredients',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Color(0xFFECECD9)],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80), // Space for app bar
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Ingredients',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...allIngredients.map((ingredient) {
                            final isCrossed = crossedOutIngredients.contains(ingredient);
                            final isReplaced = ingredientDisplay.containsKey(ingredient);
                            final displayText = ingredientDisplay[ingredient] ?? ingredient;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                                onPressed: isCrossed ? null : () => _removeIngredient(ingredient),
                              ),
                              title: Text(
                                displayText,
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  decoration: isCrossed
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: isCrossed ? Colors.grey : Colors.black,
                                ),
                              ),
                              trailing: (isCrossed || isReplaced)
                                  ? IconButton(
                                      icon: const Icon(Icons.undo, size: 20, color: Colors.blue),
                                      onPressed: isCrossed
                                          ? () => _undoRemoveIngredient(ingredient)
                                          : () => _undoReplace(ingredient),
                                    )
                                  : null,
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  if (recentChanges.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  recentChanges.map((change) => change['type'] == 'remove'
                                      ? 'Removed ${change['ingredient']}'
                                      : 'Replaced ${change['original']} with ${change['alt']}').join(', '),
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  final lastChange = recentChanges.last;
                                  if (lastChange['type'] == 'remove') {
                                    _undoRemoveIngredient(lastChange['ingredient']);
                                  } else {
                                    _undoReplace(lastChange['original']);
                                  }
                                  setState(() {
                                    recentChanges.removeLast();
                                  });
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
                      ),
                    ),
                  if (showAlternatives)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alternative Ingredients',
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const Text(
                                'Prices and taste may vary',
                                style: TextStyle(fontSize: 12, fontFamily: 'Orbitron'),
                              ),
                              const SizedBox(height: 12),
                              ...crossedOutIngredients
                                  .where((ingredient) => ingredientAlternatives.containsKey(ingredient))
                                  .map((original) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      'Alternatives for $original',
                                      style: const TextStyle(
                                        fontFamily: 'Orbitron',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ...ingredientAlternatives[original]!.map((alternative) {
                                      return RadioListTile<String>(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(alternative, style: const TextStyle(fontFamily: 'Orbitron')),
                                        value: alternative,
                                        groupValue: selectedAlternatives[original],
                                        onChanged: (val) {
                                          if (val != null) {
                                            _setReplacement(original, val);
                                          }
                                        },
                                      );
                                    }),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Meals with Similar Ingredients',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...similarMeals.map((meal) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
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
                                onTap: () {},
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}