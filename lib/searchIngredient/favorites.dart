import 'package:flutter/material.dart';
import '../pages/home.dart'; // For navigating back to home

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  final List<Map<String, String>> favoriteRecipes = const [
    {
      'name': 'Adobong Manok',
      'image': 'assets/adobong_manok.jpg',
      'time': '35-45 Minutes',
    },
    {
      'name': 'Sinigang na Isda',
      'image': 'assets/sinigang.jpg',
      'time': '15-20 Minutes',
    },
    {
      'name': 'Chopsuey',
      'image': 'assets/chopsuey.jpg',
      'time': '10-15 Minutes',
    },
    {
      'name': 'Ginisang Sayote',
      'image': 'assets/ginisang_sayote.jpg',
      'time': '10-15 Minutes',
    },
    {
      'name': 'Tinolang Manok',
      'image': 'assets/tinola.jpg',
      'time': '35-40 Minutes',
    },
    {
      'name': 'Escabeche',
      'image': 'assets/escabeche.jpg',
      'time': '10-15 Minutes',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage(title: 'HealthTingi')),
              (route) => false,
            );
          },
        ),
        title: const TextField(
          decoration: InputDecoration(
            hintText: 'Search for recipe',
            hintStyle: TextStyle(fontSize: 14),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Color(0xFFECECEC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          itemCount: favoriteRecipes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 240,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final recipe = favoriteRecipes[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        child: Image.asset(
                          recipe['image']!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.star, color: Colors.yellow, size: 22),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estimated cooking time: ${recipe['time']}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1FF57),
                        foregroundColor: Colors.black,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        // TODO: Navigate to full instructions
                      },
                      child: const Text(
                        'VIEW INSTRUCTIONS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
