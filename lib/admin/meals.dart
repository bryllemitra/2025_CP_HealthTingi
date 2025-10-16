import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
      // Organic calm gradient background matching index.dart
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFB5E48C), // soft lime green
              Color(0xFF76C893), // muted forest green
              Color(0xFF184E77), // deep slate blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Meal Management',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Stats Overview Cards
                Row(
                  children: [
                    Expanded(
                      child: _MealStatCard(
                        value: totalMeals.toString(),
                        label: 'Total Meals',
                        icon: Icons.restaurant,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MealStatCard(
                        value: availableMeals.toString(),
                        label: 'Available',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MealStatCard(
                        value: vegetarianMeals.toString(),
                        label: 'Vegetarian',
                        icon: Icons.eco,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Section Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'All Meals',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Meals List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _meals.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.restaurant_menu,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No meals found',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'Orbitron',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to add your first meal',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
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
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            _showAddMealDialog(context);
          },
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF184E77),
          elevation: 10,
          child: const Icon(Icons.add, size: 28),
        ),
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
    String? _selectedImagePath;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Add New Meal',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF184E77),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: nameController,
                    label: 'Meal Name',
                    icon: Icons.restaurant,
                  ),
                  _buildTextField(
                    controller: categoryController,
                    label: 'Category',
                    icon: Icons.category,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: priceController,
                          label: 'Price',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: caloriesController,
                          label: 'Calories',
                          icon: Icons.local_fire_department,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: restrictionsController,
                    label: 'Dietary Restrictions',
                    icon: Icons.health_and_safety,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: fromController,
                          label: 'Available From (HH:MM)',
                          icon: Icons.access_time,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: toController,
                          label: 'Available To (HH:MM)',
                          icon: Icons.access_time,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final directory = await getApplicationDocumentsDirectory();
                          final imagesDir = Directory('${directory.path}/meal_images');
                          await imagesDir.create(recursive: true);
                          final fileName = p.basename(image.path);
                          final savedPath = '${imagesDir.path}/$fileName';
                          await File(image.path).copy(savedPath);
                          setDialogState(() {
                            _selectedImagePath = savedPath;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Add Meal Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF184E77),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_selectedImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB5E48C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected: ${p.basename(_selectedImagePath!)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  _selectedImagePath = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF184E77),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(color: Color(0xFF184E77)),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
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
                              'mealPicture': _selectedImagePath,
                            };
                            final dbHelper = DatabaseHelper();
                            await dbHelper.insertMeal(meal);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Meal added successfully'),
                                backgroundColor: const Color(0xFF76C893),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            _refreshMeals();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF184E77),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Add Meal',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF184E77)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF184E77)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF184E77), width: 2),
          ),
        ),
      ),
    );
  }
}

class _MealStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MealStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF184E77),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

  Widget _getMealImage(String? path) {
    if (path == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.restaurant, color: const Color(0xFF184E77).withOpacity(0.7)),
      );
    }
    if (path.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(path, width: 60, height: 60, fit: BoxFit.cover),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(path), width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.broken_image, color: const Color(0xFF184E77).withOpacity(0.7)),
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getMealImage(meal['mealPicture']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['mealName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF184E77),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal['category'] ?? '',
                        style: TextStyle(
                          color: const Color(0xFF184E77).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MealInfoItem(
                            icon: Icons.attach_money,
                            text: '₱${meal['price']?.toStringAsFixed(2) ?? '0.00'}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _MealInfoItem(
                            icon: Icons.local_fire_department,
                            text: '${meal['calories'] ?? 0} cal',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: const Color(0xFF184E77)),
                  onSelected: (value) {
                    if (value == 'view') {
                      _showMealDetails(context);
                    } else if (value == 'edit') {
                      _showEditMealDialog(context);
                    } else if (value == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 18),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showMealDetails(context);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF184E77),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF184E77),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF184E77)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning, size: 50, color: Colors.orange.shade700),
              const SizedBox(height: 16),
              const Text(
                'Confirm Delete',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF184E77),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${meal['mealName']}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF184E77),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF184E77)),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final dbHelper = DatabaseHelper();
                        await dbHelper.deleteMeal(meal['mealID']);
                        Navigator.pop(context);
                        onRefresh();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMealDetails(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final ingredients = await dbHelper.getMealIngredients(meal['mealID']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Meal Details',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF184E77),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (meal['mealPicture'] != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        width: 200,
                        height: 150,
                        child: _getMealImage(meal['mealPicture']),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _buildDetailItem('Name', meal['mealName'] ?? 'Unknown'),
                _buildDetailItem('Category', meal['category'] ?? ''),
                _buildDetailItem('Price', '₱${meal['price']?.toStringAsFixed(2)}'),
                _buildDetailItem('Calories', '${meal['calories']} cal'),
                _buildDetailItem('Servings', '${meal['servings']}'),
                _buildDetailItem('Cooking Time', meal['cookingTime'] ?? ''),
                _buildDetailItem('Available From', meal['availableFrom'] ?? ''),
                _buildDetailItem('Available To', meal['availableTo'] ?? ''),
                _buildDetailItem('Dietary Restrictions', meal['hasDietaryRestrictions'] ?? 'None'),
                
                if (meal['content']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Content:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77)),
                  ),
                  Text(meal['content'] ?? ''),
                ],
                
                if (meal['instructions']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77)),
                  ),
                  Text(meal['instructions'] ?? ''),
                ],
                
                const SizedBox(height: 16),
                const Text(
                  'Ingredients:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77)),
                ),
                ...ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4),
                  child: Text('• ${ing['ingredientName']} (${ing['quantity'] ?? ''})'),
                )).toList(),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF184E77),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77)),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'None' : value),
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
    String? _selectedImagePath = meal['mealPicture'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Edit Meal',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF184E77),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: nameController,
                    label: 'Meal Name',
                    icon: Icons.restaurant,
                  ),
                  _buildTextField(
                    controller: categoryController,
                    label: 'Category',
                    icon: Icons.category,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: priceController,
                          label: 'Price',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: caloriesController,
                          label: 'Calories',
                          icon: Icons.local_fire_department,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: restrictionsController,
                    label: 'Dietary Restrictions',
                    icon: Icons.health_and_safety,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: fromController,
                          label: 'Available From (HH:MM)',
                          icon: Icons.access_time,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: toController,
                          label: 'Available To (HH:MM)',
                          icon: Icons.access_time,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final directory = await getApplicationDocumentsDirectory();
                          final imagesDir = Directory('${directory.path}/meal_images');
                          await imagesDir.create(recursive: true);
                          final fileName = p.basename(image.path);
                          final savedPath = '${imagesDir.path}/$fileName';
                          await File(image.path).copy(savedPath);
                          setDialogState(() {
                            _selectedImagePath = savedPath;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: Text(_selectedImagePath == null ? 'Add Meal Image' : 'Change Meal Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF184E77),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_selectedImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB5E48C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current: ${p.basename(_selectedImagePath!)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  _selectedImagePath = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No image selected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF184E77),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(color: Color(0xFF184E77)),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final updates = {
                              'mealName': nameController.text,
                              'category': categoryController.text,
                              'price': double.tryParse(priceController.text) ?? 0.0,
                              'calories': int.tryParse(caloriesController.text) ?? 0,
                              'hasDietaryRestrictions': restrictionsController.text,
                              'availableFrom': fromController.text,
                              'availableTo': toController.text,
                              'mealPicture': _selectedImagePath,
                            };
                            final dbHelper = DatabaseHelper();
                            await dbHelper.updateMeal(meal['mealID'], updates);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Meal updated successfully'),
                                backgroundColor: const Color(0xFF76C893),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            onRefresh();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF184E77),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF184E77)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF184E77)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF184E77), width: 2),
          ),
        ),
      ),
    );
  }
}

class _MealInfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MealInfoItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}