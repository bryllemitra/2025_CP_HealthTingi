import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AdminIngredientsPage extends StatefulWidget {
  final int userId;

  const AdminIngredientsPage({super.key, required this.userId});

  @override
  State<AdminIngredientsPage> createState() => _AdminIngredientsPageState();
}

class _AdminIngredientsPageState extends State<AdminIngredientsPage> {
  List<Map<String, dynamic>> _ingredients = [];
  bool _isLoading = true;
  late int totalIngredients = 0;

  @override
  void initState() {
    super.initState();
    _refreshIngredients();
  }

  Future<void> _refreshIngredients() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper();
    final ingredients = await dbHelper.getAllIngredients();

    setState(() {
      _ingredients = ingredients;
      totalIngredients = ingredients.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        title: const Text(
          'Ingredient Management',
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
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04), // Responsive padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              Card(
                child: Padding(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionButton(
                        icon: Icons.add,
                        label: 'Add',
                        onTap: () {
                          _showAddIngredientDialog(context);
                        },
                      ),
                      _ActionButton(
                        icon: Icons.cloud_upload,
                        label: 'Import',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Import functionality not implemented')),
                          );
                        },
                      ),
                      _ActionButton(
                        icon: Icons.analytics,
                        label: 'Stats',
                        onTap: () {
                          _showIngredientStats(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Ingredients List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _ingredients.length,
                        itemBuilder: (context, index) {
                          final ingredient = _ingredients[index];
                          return _IngredientCard(
                            ingredient: ingredient,
                            onRefresh: _refreshIngredients,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddIngredientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final caloriesController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Ingredient'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height to 60% of screen
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Ingredient Name'),
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
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ingredient = {
                'ingredientName': nameController.text,
                'price': double.tryParse(priceController.text) ?? 0.0,
                'calories': int.tryParse(caloriesController.text) ?? 0,
                'category': categoryController.text,
              };
              final dbHelper = DatabaseHelper();
              await dbHelper.insertIngredient(ingredient);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingredient added successfully')),
              );
              _refreshIngredients();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFF66),
            ),
            child: const Text('Add Ingredient', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showIngredientStats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingredient Statistics'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height to 60% of screen
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatRow(label: 'Total Ingredients', value: totalIngredients.toString()),
                const SizedBox(height: 20),
                Container(
                  height: MediaQuery.of(context).size.height * 0.15, // Responsive height
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '📊 Ingredient Overview',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFFFF66),
            minimumSize: Size(MediaQuery.of(context).size.width * 0.1, MediaQuery.of(context).size.width * 0.1), // Responsive size
          ),
        ),
        Text(label, style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.03)), // Responsive font size
      ],
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final Map<String, dynamic> ingredient;
  final VoidCallback onRefresh;

  const _IngredientCard({
    required this.ingredient,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.01), // Responsive margin
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04), // Responsive padding
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
                        ingredient['ingredientName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width * 0.05, // Responsive font size
                        ),
                      ),
                      Text(
                        ingredient['category'] ?? '',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: MediaQuery.of(context).size.width * 0.035, // Responsive font size
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(context),
                  iconSize: MediaQuery.of(context).size.width * 0.06, // Responsive icon size
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01), // Responsive spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IngredientInfoItem(icon: Icons.attach_money, text: '₱${_formatPrice(ingredient['price'])}'),
                _IngredientInfoItem(icon: Icons.local_fire_department, text: '${ingredient['calories'] ?? 0} cal'),
                _IngredientInfoItem(icon: Icons.category, text: ingredient['category'] ?? ''),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01), // Responsive spacing
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showIngredientDetails(context);
                    },
                    icon: Icon(Icons.info, size: MediaQuery.of(context).size.width * 0.04), // Responsive icon size
                    label: Text(
                      'Details',
                      style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.04), // Responsive font size
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

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is num) return price.toStringAsFixed(2);
    final parsedPrice = double.tryParse(price.toString());
    return parsedPrice?.toStringAsFixed(2) ?? '0.00';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${ingredient['ingredientName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              await dbHelper.deleteIngredient(ingredient['ingredientID']);
              Navigator.pop(context);
              onRefresh();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showIngredientDetails(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getMealsWithIngredient(ingredient['ingredientID']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ingredient: ${ingredient['ingredientName']}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height to 60% of screen
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${ingredient['ingredientName']}'),
                Text('Price: ₱${_formatPrice(ingredient['price'])}'),
                Text('Calories: ${ingredient['calories']} per 100g'),
                Text('Category: ${ingredient['category']}'),
                const SizedBox(height: 16),
                const Text('Nutritional Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(ingredient['nutritionalValue'] ?? 'Not specified'),
                const SizedBox(height: 16),
                const Text('Used in Meals:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...meals.map((meal) => Text('• ${meal['mealName']}')),
              ],
            ),
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
}

class _IngredientInfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IngredientInfoItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: MediaQuery.of(context).size.width * 0.04, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.035),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.01),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.04)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: MediaQuery.of(context).size.width * 0.04),
          ),
        ],
      ),
    );
  }
}