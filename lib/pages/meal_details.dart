import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class MealDetailsPage extends StatefulWidget {
  final int mealId;
  final int userId;

  const MealDetailsPage({
    super.key, 
    required this.mealId,
    required this.userId,
  });

  @override
  State<MealDetailsPage> createState() => _MealDetailsPageState();
}

class _MealDetailsPageState extends State<MealDetailsPage> {
  Future<Map<String, dynamic>>? _mealDataFuture;
  bool _isFavorite = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _trackMealView();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _mealDataFuture = _loadMealData();
      if (widget.userId != 0) { // Only check favorites for registered users
        await _checkIfFavorite();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      final favorites = user['favorites']?.toString() ?? '';
      setState(() {
        _isFavorite = favorites.split(',').contains(widget.mealId.toString());
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to check favorites: ${e.toString()}';
        });
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _loadMealData() async {
    try {
      final dbHelper = DatabaseHelper();
      final meal = await dbHelper.getMealById(widget.mealId);
      final ingredients = await dbHelper.getMealIngredients(widget.mealId);

      if (meal == null) throw Exception('Meal not found');

      // For guest users (userId = 0), skip user data and dietary restrictions
      if (widget.userId == 0) {
        return {
          ...meal,
          'ingredients': ingredients,
          'hasSpecificRestriction': false,
          'userRestriction': '',
          'mealRestrictions': meal['hasDietaryRestrictions'] ?? '',
        };
      }

      // For registered users, load user data and check specific restrictions
      final user = await dbHelper.getUserById(widget.userId);
      if (user == null) throw Exception('User not found');

      final userRestriction = user['dietaryRestriction']?.toString().toLowerCase().trim() ?? '';
      final mealRestrictionsString = meal['hasDietaryRestrictions']?.toString().toLowerCase() ?? '';
      final mealRestrictions = mealRestrictionsString.split(',').map((r) => r.trim()).toList();
      
      // Check if user has a restriction AND if the meal has restrictions that match
      final userHasRestriction = (user['hasDietaryRestriction'] ?? 0) == 1;
      final hasSpecificRestriction = userHasRestriction && 
          userRestriction.isNotEmpty &&
          mealRestrictions.any((mealRestriction) => 
              mealRestriction.contains(userRestriction) || 
              userRestriction.contains(mealRestriction));

      return {
        ...meal,
        'ingredients': ingredients,
        'hasSpecificRestriction': hasSpecificRestriction,
        'userRestriction': userRestriction,
        'mealRestrictions': mealRestrictionsString,
      };
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load meal: ${e.toString()}');
      }
      rethrow;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading || widget.userId == 0) return; // Skip for guests

    setState(() => _isLoading = true);

    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserById(widget.userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      String favorites = user['favorites']?.toString() ?? '';
      final mealIdStr = widget.mealId.toString();
      final favoritesList = favorites.split(',').where((id) => id.isNotEmpty).toList();

      setState(() {
        _isFavorite = !_isFavorite;
        if (_isFavorite) {
          if (!favoritesList.contains(mealIdStr)) {
            favoritesList.add(mealIdStr);
          }
        } else {
          favoritesList.remove(mealIdStr);
        }
        favorites = favoritesList.join(',');
      });

      await dbHelper.updateUser(widget.userId, {'favorites': favorites});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites!' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isFavorite = !_isFavorite);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _trackMealView() async {
    if (widget.userId != 0) { // Only track views for registered users
      final dbHelper = DatabaseHelper();
      await dbHelper.addToRecentlyViewed(widget.userId, widget.mealId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECD9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
        actions: [
          if (widget.userId != 0) // Only show favorite button for registered users
            IconButton(
              icon: _isLoading 
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isFavorite ? Icons.star : Icons.star_border,
                      color: _isFavorite ? Colors.yellow : Colors.black,
                    ),
              onPressed: _isLoading ? null : _toggleFavorite,
            ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFF66),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : FutureBuilder(
              future: _mealDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFF66),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Center(
                    child: Text('No meal data found'),
                  );
                }

                final mealData = snapshot.data!;
                final hasSpecificRestriction = mealData['hasSpecificRestriction'] ?? false;
                final userRestriction = mealData['userRestriction'] ?? '';
                final mealRestrictions = mealData['mealRestrictions'] ?? '';
                final ingredients = mealData['ingredients'] as List<Map<String, dynamic>>;
                final price = mealData['price'] ?? 0.0;
                final categories = (mealData['category'] as String?)?.split(', ') ?? [];
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show restriction warning only if there's a specific match
                      if (hasSpecificRestriction)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 12,
                                      color: Colors.white),
                                    children: [
                                      const TextSpan(text: '⚠️ Dietary Alert: '),
                                      TextSpan(
                                        text: 'This meal contains ingredients that conflict with your ',
                                      ),
                                      TextSpan(
                                        text: userRestriction.isNotEmpty ? userRestriction : 'dietary restriction',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: '. Meal restrictions: $mealRestrictions. Consider choosing an alternative option.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFF66),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildMealImage(mealData['mealPicture']),
                            const SizedBox(height: 8),
                            Text(
                              mealData['mealName'],
                              style: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '(Serving Size: ${mealData['servings']})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Orbitron',
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Price: Php ${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (categories.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: categories.map((category) {
                                    return Chip(
                                      label: Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Orbitron',
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  }).toList(),
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
  child: ingredients.isEmpty
      ? const Center(
          child: Text(
            'No ingredients listed',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ingredients.map((ingredient) {
            final ingredientName = ingredient['ingredientName']?.toString() ?? 'Unknown';
            final quantity = ingredient['quantity']?.toString() ?? '';
            final price = ingredient['price']?.toString() ?? 'N/A';
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '$quantity $ingredientName.........Php $price',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
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
                        child: Text(
                          mealData['instructions'] ?? 'No instructions available',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMealImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        height: 180,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
        ),
      );
    }

    return Image.asset(
      imagePath,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 180,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
          ),
        );
      },
    );
  }
}