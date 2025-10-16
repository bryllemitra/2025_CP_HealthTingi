import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart'; // Added for animations
import '../searchMeals/history.dart'; // Import HistoryPage to access completed meals list
import 'reverse_ingredient.dart'; // Add this import for navigation
import 'dart:io';

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
  bool _isCookingMode = false;
  int _currentStepIndex = 0;
  DateTime? _cookingStartTime;
  DateTime? _cookingEndTime;
  Map<int, int> _stepRemainingTimes = {};
  Map<int, int> _stepOriginalDurations = {};
  Map<int, Timer?> _stepTimers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _trackMealView();
  }

  @override
  void dispose() {
    _stepTimers.values.forEach((timer) => timer?.cancel());
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _mealDataFuture = _loadMealData();
      if (widget.userId != 0) {
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

  List<Map<String, dynamic>> parseSteps(String instructions) {
    List<Map<String, dynamic>> steps = [];
    List<String> blocks = instructions.trim().split(RegExp(r'\n{2,}'));
    
    for (var i = 0; i < blocks.length; i++) {
      var lines = blocks[i].split('\n');
      if (lines.isEmpty) continue;
      
      var firstLine = lines[0].trim();
      var match = RegExp(r'^(\d+)\.\s*(.*)').firstMatch(firstLine);
      if (match == null) continue;
      
      String title = match.group(2)!.trim();
      String content = lines.sublist(1).join('\n').trim();
      
      int duration = 0;
      var timeMatch = RegExp(r'\((\d+)(–(\d+))?\s*mins?\)').firstMatch(title);
      if (timeMatch != null) {
        int min1 = int.parse(timeMatch.group(1)!);
        int? min2 = timeMatch.group(3) != null ? int.parse(timeMatch.group(3)!) : null;
        duration = ((min2 ?? min1) * 60);
      }
      
      title = title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      
      int stepIndex = steps.length;
      steps.add({
        'number': int.parse(match.group(1)!),
        'title': title,
        'content': content,
        'duration': duration,
      });
      _stepOriginalDurations[stepIndex] = duration;
    }
    
    return steps;
  }

  void _pauseStepTimer(int index) {
    if (_stepTimers.containsKey(index)) {
      _stepTimers[index]?.cancel();
      _stepTimers[index] = null;
    }
  }

  void _resetStepTimer(int index) {
    _stepRemainingTimes[index] = _stepOriginalDurations[index] ?? 0;
  }

  void _startStepTimer(int index, List<Map<String, dynamic>> steps) {
    if (!_stepRemainingTimes.containsKey(index)) {
      _stepRemainingTimes[index] = _stepOriginalDurations[index] ?? 0;
    }

    if (_stepRemainingTimes[index]! > 0 && _stepTimers[index] == null) {
      _stepTimers[index] = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_stepRemainingTimes[index]! > 0) {
          setState(() {
            _stepRemainingTimes[index] = _stepRemainingTimes[index]! - 1;
          });
        } else {
          timer.cancel();
          _stepTimers[index] = null;
          // Auto-advance to next step if not the last
          if (_currentStepIndex < steps.length - 1) {
            _currentStepIndex++;
            _startStepTimer(_currentStepIndex, steps);
          }
        }
      });
    }
  }

  Future<void> _saveToCompletedHistory() async {
    if (widget.userId == 0) return;

    try {
      final mealData = await _mealDataFuture;
      if (mealData == null) throw Exception('Meal data not loaded');

      HistoryPage.addCompletedMeal({
        'mealID': widget.mealId,
        'mealName': mealData['mealName'],
        'mealPicture': mealData['mealPicture'] ?? 'assets/default_meal.jpg',
        'servings': mealData['servings'] ?? 1,
        'completedAt': _cookingEndTime ?? DateTime.now(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to history: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadMealData() async {
    try {
      final dbHelper = DatabaseHelper();
      final meal = await dbHelper.getMealById(widget.mealId);
      final ingredients = await dbHelper.getMealIngredients(widget.mealId);

      if (meal == null) throw Exception('Meal not found');

      final steps = parseSteps(meal['instructions'] ?? '');

      if (widget.userId == 0) {
        return {
          ...meal,
          'ingredients': ingredients,
          'hasSpecificRestriction': false,
          'userRestriction': '',
          'mealRestrictions': meal['hasDietaryRestrictions'] ?? '',
          'steps': steps,
        };
      }

      final user = await dbHelper.getUserById(widget.userId);
      if (user == null) throw Exception('User not found');

      final userRestriction = user['dietaryRestriction']?.toString().toLowerCase().trim() ?? '';
      final mealRestrictionsString = meal['hasDietaryRestrictions']?.toString().toLowerCase() ?? '';
      final mealRestrictions = mealRestrictionsString.split(',').map((r) => r.trim()).toList();
      
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
        'steps': steps,
      };
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load meal: ${e.toString()}');
      }
      rethrow;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading || widget.userId == 0) return;

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
    if (widget.userId != 0) {
      final dbHelper = DatabaseHelper();
      await dbHelper.addToRecentlyViewed(widget.userId, widget.mealId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [
                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                ]),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Cooking Quest',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 24,
                  shadows: [
                    Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                  ],
                ),
              ),
              centerTitle: true,
              actions: [
                if (widget.userId != 0)
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Icon(
                            _isFavorite ? Icons.star : Icons.star_border,
                            color: _isFavorite ? Colors.yellow : Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                            ],
                          ),
                    onPressed: _isLoading ? null : _toggleFavorite,
                  ),
              ],
            ),
            Expanded(
              child: _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Orbitron',
                              fontSize: 16,
                              shadows: [
                                Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF184E77),
                              elevation: 10,
                              shadowColor: Colors.greenAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : FutureBuilder(
                      future: _mealDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Orbitron',
                                    fontSize: 16,
                                    shadows: [
                                      Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF184E77),
                                    elevation: 10,
                                    shadowColor: Colors.greenAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (!snapshot.hasData) {
                          return const Center(
                            child: Text(
                              'No meal data found',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Orbitron',
                                fontSize: 16,
                                shadows: [
                                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                ],
                              ),
                            ),
                          );
                        }

                        final mealData = snapshot.data!;
                        final hasSpecificRestriction = mealData['hasSpecificRestriction'] ?? false;
                        final userRestriction = mealData['userRestriction'] ?? '';
                        final mealRestrictions = mealData['mealRestrictions'] ?? '';
                        final ingredients = mealData['ingredients'] as List<Map<String, dynamic>>;
                        final price = mealData['price'] ?? 0.0;
                        final categories = (mealData['category'] as String?)?.split(', ') ?? [];
                        final steps = mealData['steps'] as List<Map<String, dynamic>>;

                        return Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 300,
                              child: _buildMealImages(mealData),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 300,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                  ),
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                children: [
                                  const SizedBox(height: 250),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 25,
                                          offset: Offset(0, -10),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Text(
                                            mealData['mealName'],
                                            style: const TextStyle(
                                              fontFamily: 'Orbitron',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 28,
                                              color: Color(0xFF184E77),
                                              shadows: [
                                                Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                              ],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Center(
                                          child: Text(
                                            '(Serving Size: ${mealData['servings']})',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'Orbitron',
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Center(
                                          child: Text(
                                            'Price: Php ${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Orbitron',
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF76C893),
                                            ),
                                          ),
                                        ),
                                        if (categories.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          Center(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              alignment: WrapAlignment.center,
                                              children: categories.map((category) {
                                                return Chip(
                                                  label: Text(
                                                    category,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'Orbitron',
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  backgroundColor: const Color(0xFF184E77),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        if (hasSpecificRestriction)
                                          Card(
                                            color: Colors.red[600],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            elevation: 10,
                                            shadowColor: Colors.black54,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        style: const TextStyle(
                                                          fontFamily: 'Orbitron',
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                        ),
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
                                          ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Ingredients and Cost',
                                          style: TextStyle(
                                            fontFamily: 'Orbitron',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: Color(0xFF184E77),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Card(
                                          elevation: 10,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          shadowColor: Colors.black26,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: ingredients.isEmpty
                                                ? const Center(
                                                    child: Text(
                                                      'No ingredients listed',
                                                      style: TextStyle(
                                                        fontStyle: FontStyle.italic,
                                                        fontFamily: 'Orbitron',
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  )
                                                : Column(
                                                    children: ingredients.map((ingredient) {
                                                      final ingredientName = ingredient['ingredientName']?.toString() ?? 'Unknown';
                                                      final quantity = ingredient['quantity']?.toString() ?? '';
                                                      final price = ingredient['price']?.toString() ?? 'N/A';
                                                      
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Flexible(
                                                              flex: 3,
                                                              child: Text(
                                                                '$quantity $ingredientName',
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontFamily: 'Orbitron',
                                                                  color: Colors.black87,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            Flexible(
                                                              flex: 1,
                                                              child: Text(
                                                                'Php $price',
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w500,
                                                                  fontFamily: 'Orbitron',
                                                                  color: Color(0xFF76C893),
                                                                ),
                                                                textAlign: TextAlign.right,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Center(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.edit, size: 20),
                                            label: const Text(
                                              'Change Ingredients',
                                              style: TextStyle(
                                                fontFamily: 'Orbitron',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onPressed: () {
                                              final ingredientNames = ingredients
                                                  .map((ing) => ing['ingredientName'] as String)
                                                  .toList();
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ReverseIngredientPage(
                                                    ingredients: ingredientNames,
                                                    userId: widget.userId,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: const Color(0xFF184E77),
                                              elevation: 10,
                                              shadowColor: Colors.greenAccent,
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            ),
                                          ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                        ),
                                        const SizedBox(height: 32),
                                        const Text(
                                          'Cooking Quest Steps',
                                          style: TextStyle(
                                            fontFamily: 'Orbitron',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: Color(0xFF184E77),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (_cookingEndTime != null)
                                          Card(
                                            color: const Color(0xFF76C893),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            elevation: 10,
                                            shadowColor: Colors.black54,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    'Quest Completed in ${_cookingEndTime!.difference(_cookingStartTime!).inMinutes} minutes!',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      fontFamily: 'Orbitron',
                                                      color: Colors.white,
                                                      shadows: [
                                                        Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                                      ],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _isCookingMode = false;
                                                        _cookingStartTime = null;
                                                        _cookingEndTime = null;
                                                        _currentStepIndex = 0;
                                                        _stepRemainingTimes.clear();
                                                        _stepOriginalDurations.clear();
                                                        _stepTimers.values.forEach((t) => t?.cancel());
                                                        _stepTimers.clear();
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.white,
                                                      foregroundColor: const Color(0xFF184E77),
                                                      elevation: 10,
                                                      shadowColor: Colors.greenAccent,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                    ),
                                                    child: const Text(
                                                      'Restart Quest',
                                                      style: TextStyle(
                                                        fontFamily: 'Orbitron',
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                                ],
                                              ),
                                            ),
                                          ).animate().fadeIn(duration: 500.ms).scale(),
                                        if (!_isCookingMode) ...[
                                          Card(
                                            elevation: 10,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            shadowColor: Colors.black26,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: SelectableText(
                                                mealData['instructions'] ?? 'No instructions available',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.5,
                                                  fontFamily: 'Orbitron',
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                setState(() {
                                                  _isCookingMode = true;
                                                  _cookingStartTime = DateTime.now();
                                                  _currentStepIndex = 0;
                                                });
                                                _startStepTimer(0, steps);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: const Color(0xFF184E77),
                                                elevation: 10,
                                                shadowColor: Colors.greenAccent,
                                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              ),
                                              child: const Text(
                                                'Start Cooking Quest',
                                                style: TextStyle(
                                                  fontFamily: 'Orbitron',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                          ),
                                        ] else ...[
                                          Column(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: 120,
                                                      height: 120,
                                                      child: CircularProgressIndicator(
                                                        value: (_currentStepIndex + 1) / steps.length,
                                                        strokeWidth: 10,
                                                        backgroundColor: Colors.white.withOpacity(0.5),
                                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF76C893)),
                                                      ),
                                                    ),
                                                    Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '${((_currentStepIndex + 1) / steps.length * 100).toInt()}%',
                                                          style: const TextStyle(
                                                            fontFamily: 'Orbitron',
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 24,
                                                            color: Colors.white,
                                                            shadows: [
                                                              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                                                            ],
                                                          ),
                                                        ),
                                                        const Text(
                                                          'Progress',
                                                          style: TextStyle(
                                                            fontFamily: 'Orbitron',
                                                            fontSize: 12,
                                                            color: Colors.white70,
                                                            shadows: [
                                                              Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ListView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: steps.length,
                                                itemBuilder: (context, idx) {
                                                  var step = steps[idx];
                                                  bool isCurrent = idx == _currentStepIndex;
                                                  bool isCompleted = idx < _currentStepIndex;
                                                  return AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: isCurrent ? const Color(0xFFB5E48C).withOpacity(0.2) : Colors.white,
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: isCurrent ? const Color(0xFF76C893) : Colors.grey[300]!,
                                                        width: isCurrent ? 2 : 1,
                                                      ),
                                                      boxShadow: isCurrent
                                                          ? [
                                                              const BoxShadow(
                                                                color: Colors.black12,
                                                                blurRadius: 8,
                                                                offset: Offset(0, 4),
                                                              ),
                                                            ]
                                                          : [
                                                              const BoxShadow(
                                                                color: Colors.black12,
                                                                blurRadius: 6,
                                                                offset: Offset(0, 2),
                                                              ),
                                                            ],
                                                    ),
                                                    child: ListTile(
                                                      leading: CircleAvatar(
                                                        backgroundColor: isCompleted
                                                            ? const Color(0xFF76C893)
                                                            : (isCurrent ? const Color(0xFFB5E48C) : Colors.grey[300]),
                                                        child: isCompleted
                                                            ? const Icon(Icons.check, color: Colors.white)
                                                            : Text(
                                                                '${step['number']}',
                                                                style: TextStyle(
                                                                  color: isCurrent ? const Color(0xFF184E77) : Colors.black54,
                                                                  fontFamily: 'Orbitron',
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                      ),
                                                      title: Text(
                                                        step['title'],
                                                        style: TextStyle(
                                                          fontFamily: 'Orbitron',
                                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                          color: isCurrent ? const Color(0xFF184E77) : Colors.black87,
                                                        ),
                                                      ),
                                                      subtitle: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            step['content'],
                                                            style: const TextStyle(
                                                              fontFamily: 'Orbitron',
                                                              fontSize: 14,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                          if (step['duration'] > 0 && _stepRemainingTimes.containsKey(idx))
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 8),
                                                              child: Text(
                                                                'Time Left: ${(_stepRemainingTimes[idx]! ~/ 60)}:${(_stepRemainingTimes[idx]! % 60).toString().padLeft(2, '0')}',
                                                                style: TextStyle(
                                                                  fontFamily: 'Orbitron',
                                                                  fontWeight: FontWeight.bold,
                                                                  color: isCurrent ? Colors.red[600] : Colors.black54,
                                                                ),
                                                              ).animate().fadeIn(duration: 300.ms),
                                                            ),
                                                          if (step['duration'] > 0)
                                                            Text(
                                                              'Estimated: ${step['duration'] ~/ 60} mins',
                                                              style: const TextStyle(
                                                                fontFamily: 'Orbitron',
                                                                fontSize: 12,
                                                                color: Colors.black54,
                                                              ),
                                                            ),
                                                          if (isCurrent)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 16),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                children: [
                                                                  if (_currentStepIndex > 0)
                                                                    ElevatedButton(
                                                                      onPressed: () {
                                                                        _pauseStepTimer(_currentStepIndex);
                                                                        _resetStepTimer(_currentStepIndex);
                                                                        setState(() {
                                                                          _currentStepIndex--;
                                                                        });
                                                                        _startStepTimer(_currentStepIndex, steps);
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: const Color(0xFF184E77),
                                                                        foregroundColor: Colors.white,
                                                                        elevation: 10,
                                                                        shadowColor: Colors.black54,
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                                      ),
                                                                      child: const Text(
                                                                        'Back',
                                                                        style: TextStyle(
                                                                          fontFamily: 'Orbitron',
                                                                          fontSize: 14,
                                                                          fontWeight: FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                                                  SizedBox(
                                                                    width: MediaQuery.of(context).size.width * 0.35, // Adjusted width constraint
                                                                    child: ElevatedButton(
                                                                      onPressed: () async {
                                                                        if (_currentStepIndex < steps.length - 1) {
                                                                          _pauseStepTimer(_currentStepIndex);
                                                                          _resetStepTimer(_currentStepIndex);
                                                                          setState(() {
                                                                            _currentStepIndex++;
                                                                          });
                                                                          _startStepTimer(_currentStepIndex, steps);
                                                                        } else {
                                                                          _pauseStepTimer(_currentStepIndex);
                                                                          _resetStepTimer(_currentStepIndex);
                                                                          setState(() {
                                                                            _cookingEndTime = DateTime.now();
                                                                            _isCookingMode = false;
                                                                            _stepTimers.values.forEach((t) => t?.cancel());
                                                                            _stepTimers.clear();
                                                                            _stepRemainingTimes.clear();
                                                                            _stepOriginalDurations.clear();
                                                                          });
                                                                          await _saveToCompletedHistory();
                                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                'Quest Completed!',
                                                                                style: TextStyle(fontFamily: 'Orbitron'),
                                                                              ),
                                                                              backgroundColor: const Color(0xFF76C893),
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: Colors.white,
                                                                        foregroundColor: const Color(0xFF184E77),
                                                                        elevation: 10,
                                                                        shadowColor: Colors.greenAccent,
                                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                                      ),
                                                                      child: Text(
                                                                        _currentStepIndex == steps.length - 1 ? 'Complete Quest' : 'Next Step',
                                                                        style: const TextStyle(
                                                                          fontFamily: 'Orbitron',
                                                                          fontSize: 14,
                                                                          fontWeight: FontWeight.w600,
                                                                        ),
                                                                        textAlign: TextAlign.center,
                                                                      ),
                                                                    ),
                                                                  ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                                                ],
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      onTap: () {
                                                        _pauseStepTimer(_currentStepIndex);
                                                        _resetStepTimer(_currentStepIndex);
                                                        setState(() {
                                                          _currentStepIndex = idx;
                                                        });
                                                        _startStepTimer(_currentStepIndex, steps);
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 32),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealImages(Map<String, dynamic> mealData) {
    List<String> imagePaths = [];
    String? mealPicture = mealData['mealPicture'];
    if (mealPicture != null) {
      imagePaths.add(mealPicture);
    }
    List<Map<String, dynamic>> ingredients = mealData['ingredients'];
    for (var ing in ingredients) {
      String? ingPicture = ing['ingredientPicture'];
      if (ingPicture != null) {
        imagePaths.add(ingPicture);
      }
    }

    if (imagePaths.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.fastfood, size: 100, color: Colors.white70),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: PageView.builder(
          itemCount: imagePaths.length,
          itemBuilder: (context, index) {
            String path = imagePaths[index];
            if (path.startsWith('assets/')) {
              return Image.asset(
                path,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white.withOpacity(0.1),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 100, color: Colors.white70),
                    ),
                  );
                },
              );
            } else {
              return Image.file(
                File(path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white.withOpacity(0.1),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 100, color: Colors.white70),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}