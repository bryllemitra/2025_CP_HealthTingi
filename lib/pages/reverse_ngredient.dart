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

  final Map<String, bool> alternativeIngredients = {
    'Oyster Sauce': false,
    'Patis (Fish Sauce)': false,
  };

  final List<Map<String, String>> similarMeals = const [
    {'name': 'Ginisang Upo', 'image': 'assets/ginisang_upo.jpg'},
    {'name': 'Ginisang Kalabasa', 'image': 'assets/ginisang_kalabasa.jpg'},
    {'name': 'Tortang Sayote', 'image': 'assets/tortang_sayote.jpg'},
  ];

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
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isCrossed) {
                          crossedOutIngredients.remove(ingredient);
                        } else {
                          crossedOutIngredients.add(ingredient);
                        }
                      });
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.close, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          ingredient,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            decoration: isCrossed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
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
                children: alternativeIngredients.keys.map((alt) {
                  return CheckboxListTile(
                    title: Text(alt, style: const TextStyle(fontFamily: 'Orbitron')),
                    value: alternativeIngredients[alt],
                    onChanged: (val) {
                      setState(() {
                        alternativeIngredients[alt] = val ?? false;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
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
