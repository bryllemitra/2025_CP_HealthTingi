import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../pages/meal_details.dart';

class HistoryPage extends StatefulWidget {
  final int userId;

  const HistoryPage({super.key, required this.userId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> historyRecipes = [];
  List<Map<String, dynamic>> filteredRecipes = [];
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    searchController.addListener(_filterHistory);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final dbHelper = DatabaseHelper();
      final historyMeals = await dbHelper.getRecentlyViewedMeals(widget.userId);
      
      setState(() {
        historyRecipes = historyMeals;
        filteredRecipes = List.from(historyRecipes);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load history: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _filterHistory() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredRecipes = List.from(historyRecipes);
      } else {
        filteredRecipes = historyRecipes.where((recipe) {
          final name = recipe['mealName'].toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search your viewed recipes',
            hintStyle: const TextStyle(fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFECECEC),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                    },
                  )
                : null,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : historyRecipes.isEmpty
                  ? const Center(child: Text('No viewed recipes yet'))
                  : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          if (searchController.text.isNotEmpty && filteredRecipes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Meal not found in history',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          Expanded(
                            child: GridView.builder(
                              itemCount: filteredRecipes.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 260,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 12,
                              ),
                              itemBuilder: (context, index) {
                                final recipe = filteredRecipes[index];
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
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(10)),
                                        child: Image.asset(
                                          recipe['mealPicture'] ?? 'assets/default_meal.jpg',
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 120,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.fastfood,
                                                  size: 40, color: Colors.grey),
                                            );
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recipe['mealName'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Servings: ${recipe['servings']}',
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
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MealDetailsPage(
                                                  mealId: recipe['mealID'],
                                                  userId: widget.userId,
                                                ),
                                              ),
                                            );
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
                        ],
                      ),
                    ),
    );
  }
}