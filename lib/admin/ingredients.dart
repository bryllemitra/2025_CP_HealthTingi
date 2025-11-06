import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

class AdminIngredientsPage extends StatefulWidget {
  final int userId;

  const AdminIngredientsPage({super.key, required this.userId});

  @override
  State<AdminIngredientsPage> createState() => _AdminIngredientsPageState();
}

class _AdminIngredientsPageState extends State<AdminIngredientsPage> {
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _filteredIngredients = [];
  bool _isLoading = true;
  late int totalIngredients = 0;
  late int availableIngredients = 0;
  late int vegetableIngredients = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshIngredients();
    _searchController.addListener(_filterIngredients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterIngredients() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredIngredients = _ingredients;
      });
    } else {
      setState(() {
        _filteredIngredients = _ingredients.where((ingredient) {
          final name = ingredient['ingredientName']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _refreshIngredients() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper();
    final ingredients = await dbHelper.getAllIngredients();

    int veg = 0;
    for (var ingredient in ingredients) {
      if ((ingredient['category'] ?? '').toString().toLowerCase().contains('vegetable')) veg++;
    }

    setState(() {
      _ingredients = ingredients;
      _filteredIngredients = ingredients;
      totalIngredients = ingredients.length;
      availableIngredients = ingredients.length; // All ingredients are available by default
      vegetableIngredients = veg;
      _isLoading = false;
    });
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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Ingredient Management',
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
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Stats Overview Cards
                Row(
                  children: [
                    Expanded(
                      child: _IngredientStatCard(
                        value: totalIngredients.toString(),
                        label: 'Total Ingredients',
                        icon: Icons.kitchen,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _IngredientStatCard(
                        value: availableIngredients.toString(),
                        label: 'Available',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _IngredientStatCard(
                        value: vegetableIngredients.toString(),
                        label: 'Vegetables',
                        icon: Icons.eco,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search ingredients...',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'Orbitron',
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: const Color(0xFF184E77),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: const Color(0xFF184E77),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _filterIngredients();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      color: Color(0xFF184E77),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'All Ingredients ($totalIngredients)'
                        : 'Search Results (${_filteredIngredients.length})',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 18,
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
                
                // Ingredients List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _filteredIngredients.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchController.text.isEmpty
                                        ? Icons.kitchen
                                        : Icons.search_off,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'No ingredients found'
                                        : 'No ingredients found for "${_searchController.text}"',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 18,
                                      fontFamily: 'Orbitron',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'Tap the + button to add your first ingredient'
                                        : 'Try a different search term',
                                    style: TextStyle(
                                      color: Colors.green.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredIngredients.length,
                              itemBuilder: (context, index) {
                                final ingredient = _filteredIngredients[index];
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
            _showAddIngredientDialog(context);
          },
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF76C893),
          elevation: 10,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  void _showAddIngredientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final caloriesController = TextEditingController();
    final nutritionalController = TextEditingController();
    String? _selectedImagePath;
    List<String> _additionalImages = [];

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
                      'Add New Ingredient',
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
                    label: 'Ingredient Name',
                    icon: Icons.kitchen,
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
                    controller: nutritionalController,
                    label: 'Nutritional Value',
                    icon: Icons.health_and_safety,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Default Ingredient Image',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final directory = await getApplicationDocumentsDirectory();
                          final imagesDir = Directory('${directory.path}/ingredient_images');
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
                      label: const Text('Add Default Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF76C893),
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
                  const Text(
                    'Additional Images (up to 5)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_additionalImages.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _additionalImages.length,
                      itemBuilder: (context, index) {
                        final path = _additionalImages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.basename(path),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setDialogState(() {
                                      _additionalImages.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (_additionalImages.length < 5)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            final directory = await getApplicationDocumentsDirectory();
                            final imagesDir = Directory('${directory.path}/ingredient_images');
                            await imagesDir.create(recursive: true);
                            final fileName = p.basename(image.path);
                            final savedPath = '${imagesDir.path}/$fileName';
                            await File(image.path).copy(savedPath);
                            setDialogState(() {
                              _additionalImages.add(savedPath);
                            });
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Additional Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF76C893),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            foregroundColor: const Color(0xFF76C893),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(color: Color(0xFF76C893)),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final ingredient = {
                              'ingredientName': nameController.text,
                              'category': categoryController.text,
                              'price': double.tryParse(priceController.text) ?? 0.0,
                              'calories': int.tryParse(caloriesController.text) ?? 0,
                              'nutritionalValue': nutritionalController.text,
                              'ingredientPicture': _selectedImagePath,
                              'additionalPictures': _additionalImages.join(','),
                            };
                            final dbHelper = DatabaseHelper();
                            await dbHelper.insertIngredient(ingredient);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Ingredient added successfully'),
                                backgroundColor: const Color(0xFF76C893),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            _refreshIngredients();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF76C893),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Add Ingredient',
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
          prefixIcon: Icon(icon, color: const Color(0xFF76C893)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF76C893)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF76C893), width: 2),
          ),
        ),
      ),
    );
  }
}

class _IngredientStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _IngredientStatCard({
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

class _IngredientCard extends StatelessWidget {
  final Map<String, dynamic> ingredient;
  final VoidCallback onRefresh;

  const _IngredientCard({
    required this.ingredient,
    required this.onRefresh,
  });

  Widget _getIngredientImage(String? path) {
    if (path == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.kitchen, color: const Color(0xFF184E77).withOpacity(0.7)),
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

  String _formatPrice(dynamic price) {
    if (price is num) {
      return price.toStringAsFixed(2);
    } else if (price != null) {
      return price.toString();  // Display strings as-is (e.g., "400/kg, 20-25/pack")
    } else {
      return '0.00';
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
                _getIngredientImage(ingredient['ingredientPicture']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient['ingredientName'] ?? 'Unknown',
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
                        ingredient['category'] ?? '',
                        style: TextStyle(
                          color: const Color(0xFF184E77).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _IngredientInfoItem(
                            icon: Icons.attach_money,
                            text: '₱${_formatPrice(ingredient['price'])}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _IngredientInfoItem(
                            icon: Icons.local_fire_department,
                            text: '${ingredient['calories'] ?? 0} cal',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: const Color(0xFF76C893)),
                  onSelected: (value) {
                    if (value == 'view') {
                      _showIngredientDetails(context);
                    } else if (value == 'edit') {
                      _showEditIngredientDialog(context);
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
                      _showIngredientDetails(context);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF76C893),
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
                      _showEditIngredientDialog(context);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF76C893),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF76C893)),
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
                'Are you sure you want to delete "${ingredient['ingredientName']}"?',
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
                        await dbHelper.deleteIngredient(ingredient['ingredientID']);
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

  Future<void> _showIngredientDetails(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getMealsWithIngredient(ingredient['ingredientID']);
    final additionalPictures = (ingredient['additionalPictures'] as String? ?? '').split(',').where((p) => p.isNotEmpty).toList();
    final allImages = [ingredient['ingredientPicture'] as String?, ...additionalPictures].where((p) => p != null && p.isNotEmpty).cast<String>().toList();

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
                    'Ingredient Details',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF184E77),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (allImages.isNotEmpty)
                  SizedBox(
                    height: 150,
                    child: PageView.builder(
                      itemCount: allImages.length,
                      itemBuilder: (context, index) {
                        final path = allImages[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: PhotoView(
                                    imageProvider: path.startsWith('assets/') ? AssetImage(path) : FileImage(File(path)),
                                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                                    minScale: PhotoViewComputedScale.contained,
                                    maxScale: PhotoViewComputedScale.covered * 4.0,
                                    heroAttributes: PhotoViewHeroAttributes(tag: path),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: SizedBox(
                                width: 200,
                                child: path.startsWith('assets/') 
                                  ? Image.asset(path, fit: BoxFit.cover)
                                  : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.broken_image, size: 100);
                                    }),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Center(child: Text('No images available')),
                const SizedBox(height: 20),
                _buildDetailItem('Name', ingredient['ingredientName'] ?? 'Unknown'),
                _buildDetailItem('Category', ingredient['category'] ?? ''),
                _buildDetailItem('Price', '₱${ingredient['price']?.toStringAsFixed(2)}'),
                _buildDetailItem('Calories', '${ingredient['calories']} cal'),
                _buildDetailItem('Nutritional Value', ingredient['nutritionalValue'] ?? 'None'),
                
                const SizedBox(height: 16),
                Text(
                  'Used in ${meals.length} meal${meals.length == 1 ? '' : 's'}:',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77)),
                ),
                ...meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4),
                  child: Text('• ${meal['mealName']}'),
                )).toList(),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF76C893),
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

  void _showEditIngredientDialog(BuildContext context) {
    final nameController = TextEditingController(text: ingredient['ingredientName']);
    final categoryController = TextEditingController(text: ingredient['category']);
    final priceController = TextEditingController(text: ingredient['price']?.toString());
    final caloriesController = TextEditingController(text: ingredient['calories']?.toString());
    final nutritionalController = TextEditingController(text: ingredient['nutritionalValue']);
    String? _selectedImagePath = ingredient['ingredientPicture'];
    List<String> _additionalImages = (ingredient['additionalPictures'] as String? ?? '').split(',').where((p) => p.isNotEmpty).toList();

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
                      'Edit Ingredient',
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
                    label: 'Ingredient Name',
                    icon: Icons.kitchen,
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
                    controller: nutritionalController,
                    label: 'Nutritional Value',
                    icon: Icons.health_and_safety,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Default Ingredient Image',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final directory = await getApplicationDocumentsDirectory();
                          final imagesDir = Directory('${directory.path}/ingredient_images');
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
                      label: Text(_selectedImagePath == null ? 'Add Default Image' : 'Change Default Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF76C893),
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
                          ],
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No default image', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Additional Images (up to 5)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_additionalImages.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _additionalImages.length,
                      itemBuilder: (context, index) {
                        final path = _additionalImages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.basename(path),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setDialogState(() {
                                      _additionalImages.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (_additionalImages.length < 5)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            final directory = await getApplicationDocumentsDirectory();
                            final imagesDir = Directory('${directory.path}/ingredient_images');
                            await imagesDir.create(recursive: true);
                            final fileName = p.basename(image.path);
                            final savedPath = '${imagesDir.path}/$fileName';
                            await File(image.path).copy(savedPath);
                            setDialogState(() {
                              _additionalImages.add(savedPath);
                            });
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Additional Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF76C893),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            foregroundColor: const Color(0xFF76C893),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(color: Color(0xFF76C893)),
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
                            await dbHelper.updateIngredient(
                              ingredient['ingredientID'], 
                              {
                                'ingredientName': nameController.text,
                                'category': categoryController.text,
                                'price': double.tryParse(priceController.text) ?? 0.0,
                                'calories': int.tryParse(caloriesController.text) ?? 0,
                                'nutritionalValue': nutritionalController.text,
                                'ingredientPicture': _selectedImagePath,
                                'additionalPictures': _additionalImages.join(','),
                              }
                            );
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Ingredient updated successfully'),
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
                            backgroundColor: const Color(0xFF76C893),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Update Ingredient',
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
          prefixIcon: Icon(icon, color: const Color(0xFF76C893)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF76C893)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF76C893), width: 2),
          ),
        ),
      ),
    );
  }
}

class _IngredientInfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _IngredientInfoItem({
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
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}