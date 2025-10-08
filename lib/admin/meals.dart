import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AdminMealsPage extends StatefulWidget {
  final int userId;

  const AdminMealsPage({super.key, required this.userId});

  @override
  State<AdminMealsPage> createState() => _AdminMealsPageState();
}

class _AdminMealsPageState extends State<AdminMealsPage> {
  List<Map<String, dynamic>> _meals = [];
  bool _isLoading = true;
  late int totalMeals = 0;
  late int availableMeals = 0;
  late int vegetarianMeals = 0;

  @override
  void initState() {
    super.initState();
    _refreshMeals();
  }

  Future<void> _refreshMeals() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getAllMeals();

    int avail = 0;
    int veg = 0;
    for (var meal in meals) {
      if (_isMealAvailable(meal)) avail++;
      if ((meal['hasDietaryRestrictions'] ?? '').toString().toLowerCase().contains('vegetarian')) veg++;
    }

    setState(() {
      _meals = meals;
      totalMeals = meals.length;
      availableMeals = avail;
      vegetarianMeals = veg;
      _isLoading = false;
    });
  }

  bool _isMealAvailable(Map<String, dynamic> meal) {
    final fromStr = meal['availableFrom'] as String?;
    final toStr = meal['availableTo'] as String?;
    if (fromStr == null || toStr == null) return false;

    try {
      final fromParts = fromStr.split(':').map(int.parse).toList();
      final toParts = toStr.split(':').map(int.parse).toList();
      final fromTime = TimeOfDay(hour: fromParts[0], minute: fromParts[1]);
      final toTime = TimeOfDay(hour: toParts[0], minute: toParts[1]);
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final fromMinutes = fromTime.hour * 60 + fromTime.minute;
      final toMinutes = toTime.hour * 60 + toTime.minute;
      return nowMinutes >= fromMinutes && nowMinutes <= toMinutes;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        title: const Text(
          'Meal Management',
          style: TextStyle(
            fontFamily: 'PixelifySans',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFF66),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Overview
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MealStatItem(
                        value: totalMeals.toString(),
                        label: 'Total Meals',
                      ),
                      _MealStatItem(
                        value: availableMeals.toString(),
                        label: 'Available',
                      ),
                      _MealStatItem(
                        value: vegetarianMeals.toString(),
                        label: 'Vegetarian',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Meals List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _meals.length,
                        itemBuilder: (context, index) {
                          final meal = _meals[index];
                          final isAvailable = _isMealAvailable(meal);
                          return _MealCard(
                            meal: meal,
                            isAvailable: isAvailable,
                            onRefresh: _refreshMeals,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddMealDialog(context);
        },
        backgroundColor: const Color(0xFFFFFF66),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddMealDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final caloriesController = TextEditingController();
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final restrictionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Meal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Meal Name'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: restrictionsController,
                decoration: const InputDecoration(labelText: 'Dietary Restrictions'),
              ),
              TextField(
                controller: fromController,
                decoration: const InputDecoration(labelText: 'Available From (HH:MM)'),
              ),
              TextField(
                controller: toController,
                decoration: const InputDecoration(labelText: 'Available To (HH:MM)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final meal = {
                'mealName': nameController.text,
                'category': categoryController.text,
                'price': double.tryParse(priceController.text) ?? 0.0,
                'calories': int.tryParse(caloriesController.text) ?? 0,
                'hasDietaryRestrictions': restrictionsController.text,
                'availableFrom': fromController.text,
                'availableTo': toController.text,
                'servings': 2,
                'cookingTime': '30 minutes',
                'content': '',
                'instructions': '',
                'mealPicture': null,
              };
              final dbHelper = DatabaseHelper();
              await dbHelper.insertMeal(meal);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meal added successfully')),
              );
              _refreshMeals();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFF66),
            ),
            child: const Text('Add Meal', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

class _MealStatItem extends StatelessWidget {
  final String value;
  final String label;

  const _MealStatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final bool isAvailable;
  final VoidCallback onRefresh;

  const _MealCard({
    required this.meal,
    required this.isAvailable,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['mealName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        meal['category'] ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAvailable ? 'Available' : 'Unavailable',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MealInfoItem(icon: Icons.attach_money, text: '₱${meal['price']?.toStringAsFixed(2) ?? '0.00'}'),
                const SizedBox(width: 16),
                _MealInfoItem(icon: Icons.local_fire_department, text: '${meal['calories'] ?? 0} cal'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showMealDetails(context);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showEditMealDialog(context);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFF66),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${meal['mealName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              await dbHelper.deleteMeal(meal['mealID']);
              Navigator.pop(context);
              onRefresh();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showMealDetails(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final ingredients = await dbHelper.getMealIngredients(meal['mealID']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Meal Details: ${meal['mealName']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${meal['mealName']}'),
              Text('Category: ${meal['category']}'),
              Text('Price: ₱${meal['price']?.toStringAsFixed(2)}'),
              Text('Calories: ${meal['calories']}'),
              Text('Servings: ${meal['servings']}'),
              Text('Cooking Time: ${meal['cookingTime']}'),
              Text('Available From: ${meal['availableFrom']}'),
              Text('Available To: ${meal['availableTo']}'),
              const SizedBox(height: 16),
              const Text('Content:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(meal['content'] ?? ''),
              const SizedBox(height: 16),
              const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(meal['instructions'] ?? ''),
              const SizedBox(height: 16),
              const Text('Dietary Restrictions:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(meal['hasDietaryRestrictions'] ?? ''),
              const SizedBox(height: 16),
              const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...ingredients.map((ing) => Text('• ${ing['ingredientName']} (${ing['quantity'] ?? ''})')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditMealDialog(BuildContext context) {
    final nameController = TextEditingController(text: meal['mealName']);
    final categoryController = TextEditingController(text: meal['category']);
    final priceController = TextEditingController(text: meal['price']?.toString());
    final caloriesController = TextEditingController(text: meal['calories']?.toString());
    final fromController = TextEditingController(text: meal['availableFrom']);
    final toController = TextEditingController(text: meal['availableTo']);
    final restrictionsController = TextEditingController(text: meal['hasDietaryRestrictions']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Meal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Meal Name'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: restrictionsController,
                decoration: const InputDecoration(labelText: 'Dietary Restrictions'),
              ),
              TextField(
                controller: fromController,
                decoration: const InputDecoration(labelText: 'Available From (HH:MM)'),
              ),
              TextField(
                controller: toController,
                decoration: const InputDecoration(labelText: 'Available To (HH:MM)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updates = {
                'mealName': nameController.text,
                'category': categoryController.text,
                'price': double.tryParse(priceController.text) ?? 0.0,
                'calories': int.tryParse(caloriesController.text) ?? 0,
                'hasDietaryRestrictions': restrictionsController.text,
                'availableFrom': fromController.text,
                'availableTo': toController.text,
              };
              final dbHelper = DatabaseHelper();
              await dbHelper.updateMeal(meal['mealID'], updates);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meal updated successfully')),
              );
              onRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFF66),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

class _MealInfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MealInfoItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}