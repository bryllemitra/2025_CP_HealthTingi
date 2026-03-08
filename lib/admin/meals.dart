import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminMealsPage extends StatefulWidget {
  final int userId;

  const AdminMealsPage({super.key, required this.userId});

  @override
  State<AdminMealsPage> createState() => _AdminMealsPageState();
}

class _AdminMealsPageState extends State<AdminMealsPage> {
  List<Map<String, dynamic>> _meals = [];
  List<Map<String, dynamic>> _filteredMeals = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  late int totalMeals = 0;
  late int availableMeals = 0;
  late int vegetarianMeals = 0;

  @override
  void initState() {
    super.initState();
    _refreshMeals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshMeals() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper();
    final meals = await dbHelper.getAllMeals();

    int veg = 0;
    for (var meal in meals) {
      String cat = (meal['category'] ?? '').toString().toLowerCase();
      if (cat.contains('vegetable') || cat.contains('vegan') || cat.contains('vegetarian')) {
        veg++;
      }
    }

    setState(() {
      _meals = meals;
      _filteredMeals = meals; 
      totalMeals = meals.length;
      availableMeals = meals.length; 
      vegetarianMeals = veg;
      _isLoading = false;
    });
  }

  void _filterMeals(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMeals = _meals;
      } else {
        _filteredMeals = _meals.where((meal) {
          final name = meal['mealName']?.toString().toLowerCase() ?? '';
          final category = meal['category']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || 
                 category.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  double _parseQuantity(String quantityStr) {
    if (quantityStr.trim().isEmpty) return 0.0;
    String cleanStr = quantityStr.trim();

    if (double.tryParse(cleanStr) != null) return double.parse(cleanStr);
    final fractionMap = {
      '⅛': 0.125, '¼': 0.25, '⅓': 0.333, '⅜': 0.375,
      '½': 0.5, '⅝': 0.625, '⅔': 0.666, '¾': 0.75, '⅞': 0.875
    };
    if (fractionMap.containsKey(cleanStr)) return fractionMap[cleanStr]!;
    if (cleanStr.contains('/')) {
      List<String> parts = cleanStr.split('/');
      if (parts.length == 2) {
        double n = double.tryParse(parts[0].trim()) ?? 1.0;
        double d = double.tryParse(parts[1].trim()) ?? 1.0;
        if (d != 0) return n / d;
      }
    }
    
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(cleanStr);
    if (match != null) return double.tryParse(match.group(0)!) ?? 0.0;
    
    return 0.0;
  }

  Future<void> _generateAndPrintPdf() async {
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final dbHelper = DatabaseHelper();

    List<List<dynamic>> tableData = [];

    for (var meal in _filteredMeals) {
      List<Map<String, dynamic>> ingredients = [];
      try {
        ingredients = await dbHelper.getMealIngredients(meal['mealID'] ?? meal['id']);
      } catch (e) {
        print("Error fetching ingredients: $e");
      }

      String ingredientBreakdown = "";
      double calculatedTotalCost = 0.0;

      if (ingredients.isEmpty) {
        ingredientBreakdown = "No ingredients listed";
      } else {
        for (var ing in ingredients) {
          String name = ing['ingredientName'] ?? 'Unknown';
          String qtyStr = ing['quantity']?.toString() ?? '0';
          String unit = ing['unit']?.toString() ?? 'piece';

          double qty = _parseQuantity(qtyStr);
          double basePrice = (ing['price'] as num?)?.toDouble() ?? 0.0;
          String baseUnit = ing['base_unit']?.toString() ?? unit;
          double recipeGrams = dbHelper.convertToGrams(qty, unit, ing);
          double baseGrams = dbHelper.convertToGrams(1.0, baseUnit, ing);

          double itemCost = 0.0;
          if (baseGrams > 0) {
            itemCost = (recipeGrams * basePrice) / baseGrams;
          }
          
          calculatedTotalCost += itemCost;
          ingredientBreakdown += "• $qtyStr $unit $name - Php ${itemCost.toStringAsFixed(2)}\n";
        }
      }

      double displayPrice = (calculatedTotalCost > 0) 
          ? calculatedTotalCost 
          : (meal['price'] as num?)?.toDouble() ?? 0.0;

      tableData.add([
        meal['mealName']?.toString() ?? 'N/A',
        ingredientBreakdown, 
        'Php ${displayPrice.toStringAsFixed(2)}',
        '${meal['calories']?.toString() ?? '0'} cal',
        meal['servings']?.toString() ?? '1',
        meal['cookingTime']?.toString() ?? 'N/A',
      ]);
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        maxPages: 1000, 
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Meal Cost Breakdown Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Meal Name', 'Ingredients & Computed Cost', 'Total Cost', 'Cals', 'Serv', 'Time'],
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5), 
                1: const pw.FlexColumnWidth(3),   
                2: const pw.FlexColumnWidth(1),   
                3: const pw.FlexColumnWidth(0.8), 
                4: const pw.FlexColumnWidth(0.6), 
                5: const pw.FlexColumnWidth(0.8), 
              },
              data: tableData,
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellStyle: const pw.TextStyle(fontSize: 9), 
              cellAlignment: pw.Alignment.topLeft,
              cellAlignments: {
                0: pw.Alignment.topLeft,
                1: pw.Alignment.topLeft,
                2: pw.Alignment.topRight,
                3: pw.Alignment.topRight,
                4: pw.Alignment.topCenter,
                5: pw.Alignment.topLeft,
              },
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Meal_Breakdown_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFB5E48C),
              Color(0xFF76C893), 
              Color(0xFF184E77), 
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
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      tooltip: 'Download Breakdown PDF',
                      onPressed: _generateAndPrintPdf,
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MealStatCard(
                        value: totalMeals.toString(),
                        label: 'Total Meals',
                        icon: Icons.restaurant_menu,
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
                        label: 'Veg/Vegan',
                        icon: Icons.eco,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
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
                    onChanged: _filterMeals,
                    decoration: InputDecoration(
                      hintText: 'Search meals...',
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
                                _filterMeals('');
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'All Meals ($totalMeals)'
                        : 'Search Results (${_filteredMeals.length})',
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
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _filteredMeals.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isEmpty
                                        ? Icons.restaurant
                                        : Icons.search_off,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No meals found'
                                        : 'No meals found for "$_searchQuery"',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 18,
                                      fontFamily: 'Orbitron',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'Tap the + button to add your first meal'
                                        : 'Try a different search term',
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
                              itemCount: _filteredMeals.length,
                              itemBuilder: (context, index) {
                                final meal = _filteredMeals[index];
                                return _MealCard(
                                  meal: meal,
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
          foregroundColor: const Color(0xFF76C893),
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
    final descriptionController = TextEditingController();
    final instructionsController = TextEditingController();
    final servingsController = TextEditingController();
    final timeController = TextEditingController();
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final restrictionsController = TextEditingController();
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: servingsController,
                          label: 'Servings',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: timeController,
                          label: 'Cooking Time',
                          icon: Icons.timer,
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
                  _buildTextField(
                    controller: descriptionController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 3,
                  ),
                  _buildTextField(
                    controller: instructionsController,
                    label: 'Instructions',
                    icon: Icons.list,
                    maxLines: 5,
                  ),
                  
                  const SizedBox(height: 20),
                  const Text(
                    'Default Meal Image',
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
                            final imagesDir = Directory('${directory.path}/meal_images');
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
                            final meal = {
                              'mealName': nameController.text,
                              'category': categoryController.text,
                              'price': double.tryParse(priceController.text) ?? 0.0,
                              'calories': int.tryParse(caloriesController.text) ?? 0,
                              'servings': int.tryParse(servingsController.text) ?? 1,
                              'cookingTime': timeController.text,
                              'content': descriptionController.text,
                              'instructions': instructionsController.text,
                              'availableFrom': fromController.text,
                              'availableTo': toController.text,
                              'hasDietaryRestrictions': restrictionsController.text,
                              'mealPicture': _selectedImagePath,
                              'additionalPictures': _additionalImages.join(','),
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
                            backgroundColor: const Color(0xFF76C893),
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
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF76C893)),
          alignLabelWithHint: maxLines > 1,
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
  final VoidCallback onRefresh;

  const _MealCard({
    required this.meal,
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
    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(path, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
          return Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.broken_image, color: const Color(0xFF184E77).withOpacity(0.7)));
        }),
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
      return price.toString();
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
                            text: '₱${_formatPrice(meal['price'])}',
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
                  icon: Icon(Icons.more_vert, color: const Color(0xFF76C893)),
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
                      _showEditMealDialog(context);
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
    final additionalPictures = (meal['additionalPictures'] as String? ?? '').split(',').where((p) => p.isNotEmpty).toList();
    final allImages = [meal['mealPicture'] as String?, ...additionalPictures].where((p) => p != null && p.isNotEmpty).cast<String>().toList();

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
                                    imageProvider: path.startsWith('http')
                                        ? NetworkImage(path) as ImageProvider
                                        : path.startsWith('assets/') 
                                            ? AssetImage(path) 
                                            : FileImage(File(path)),
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
                                child: path.startsWith('http')
                                  ? Image.network(path, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 100))
                                  : path.startsWith('assets/') 
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
                _buildDetailItem('Name', meal['mealName'] ?? 'Unknown'),
                _buildDetailItem('Category', meal['category'] ?? ''),
                _buildDetailItem('Price', '₱${_formatPrice(meal['price'])}'),
                _buildDetailItem('Calories', '${meal['calories']} cal'),
                _buildDetailItem('Servings', '${meal['servings']}'),
                _buildDetailItem('Cooking Time', meal['cookingTime'] ?? 'N/A'),
                
                const SizedBox(height: 16),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77))),
                Text(meal['content'] ?? 'No description provided'),
                const SizedBox(height: 16),
                const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77))),
                Text(meal['instructions'] ?? 'No instructions provided'),
                
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

  void _showEditMealDialog(BuildContext context) {
    final nameController = TextEditingController(text: meal['mealName']);
    final categoryController = TextEditingController(text: meal['category']);
    final priceController = TextEditingController(text: meal['price']?.toString());
    final caloriesController = TextEditingController(text: meal['calories']?.toString());
    final descriptionController = TextEditingController(text: meal['content']);
    final instructionsController = TextEditingController(text: meal['instructions']);
    final servingsController = TextEditingController(text: meal['servings']?.toString());
    final timeController = TextEditingController(text: meal['cookingTime']);
    String? _selectedImagePath = meal['mealPicture'];
    List<String> _additionalImages = (meal['additionalPictures'] as String? ?? '').split(',').where((p) => p.isNotEmpty).toList();

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
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: servingsController,
                          label: 'Servings',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: timeController,
                          label: 'Cooking Time',
                          icon: Icons.timer,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: descriptionController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 3,
                  ),
                  _buildTextField(
                    controller: instructionsController,
                    label: 'Instructions',
                    icon: Icons.list,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Default Meal Image',
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
                            final imagesDir = Directory('${directory.path}/meal_images');
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
                            await dbHelper.updateMeal(
                              meal['mealID'], 
                              {
                                'mealName': nameController.text,
                                'category': categoryController.text,
                                'price': double.tryParse(priceController.text) ?? 0.0,
                                'calories': int.tryParse(caloriesController.text) ?? 0,
                                'servings': int.tryParse(servingsController.text) ?? 1,
                                'cookingTime': timeController.text,
                                'content': descriptionController.text,
                                'instructions': instructionsController.text,
                                'mealPicture': _selectedImagePath,
                                'additionalPictures': _additionalImages.join(','),
                              }
                            );
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
                            backgroundColor: const Color(0xFF76C893),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Update Meal',
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
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF76C893)),
          alignLabelWithHint: maxLines > 1,
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