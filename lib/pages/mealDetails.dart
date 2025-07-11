import 'package:flutter/material.dart';
import '../main.dart';

class MealDetailsPage extends StatelessWidget {
  const MealDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECD9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // Goes back to the previous page
          },
        ),
        title: const Text(
          'Meal Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'Orbitron',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Image Card
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFF66),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Image.asset('assets/ginisang_sayote.jpg', height: 100),
                  const SizedBox(height: 8),
                  const Text(
                    'Ginisang Sayote',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    '(Serving Size: 1–2 serving)',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Orbitron',
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ingredients and Cost
            const Text(
              'Ingredients and Cost',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1 Small Sayote.........Php 10'),
                  Text('1 Small Onion..........Php 5'),
                  Text('4 Cloves Garlic........Php 5'),
                  Text('1 Small Tomato........Php 5'),
                  Text('1/8 cup Oil.................Php 10'),
                  Text('1/4 cup Soy Sauce...Php 10'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/reverse-ingredient');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFF66),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text(
                  'Change Ingredients',
                  style: TextStyle(fontFamily: 'Orbitron'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            const Text(
              'Instructions for Cooking',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '''
1. Prep Time (5 mins)
  • Peel and slice the sayote into thin strips or matchsticks.
  • Dice the onion, tomato, and mince the garlic.

2. Heat the Pan (1 min)
  • In a pan over medium heat, add the oil and let it heat up.

3. Sauté Aromatics (2–3 mins)
  • Add garlic and stir until fragrant and golden.
  • Add the onion and tomato. Sauté until softened.

4. Add Bagoong (1 min)
  • Add the bagoong and sauté for about a minute to release flavor.

5. Cook the Sayote (5–7 mins)
  • Add the sliced sayote and sauté for a couple of minutes.
  • Pour in the soy sauce.
  • Stir occasionally, cover the pan, and let it cook until the sayote is tender but not mushy.

6. Taste and Adjust (Optional)
  • You may add a bit of water if it’s too salty or dry.
  • Optional: Add chili flakes or ground pepper for heat.

7. Serve
  • Serve hot with steamed rice. Great with fried fish or just on its own!
''',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'Orbitron',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
