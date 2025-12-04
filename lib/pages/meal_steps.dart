import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../searchMeals/history.dart';
import '../database/db_helper.dart';
import 'meal_completion.dart';

class MealStepsPage extends StatefulWidget {
  final int mealId;
  final int userId;
  final Map<String, dynamic> mealData;

  const MealStepsPage({
    super.key,
    required this.mealId,
    required this.userId,
    required this.mealData,
  });

  @override
  State<MealStepsPage> createState() => _MealStepsPageState();
}

class _MealStepsPageState extends State<MealStepsPage> {
  late List<Map<String, dynamic>> steps;
  int _currentStepIndex = 0;
  DateTime? _cookingStartTime;
  DateTime? _cookingEndTime;
  Map<int, int> _stepRemainingTimes = {};
  Map<int, int> _stepOriginalDurations = {};
  Map<int, Timer?> _stepTimers = {};

  @override
  void initState() {
    super.initState();
    steps = widget.mealData['steps'] as List<Map<String, dynamic>>;
    for (int i = 0; i < steps.length; i++) {
      _stepOriginalDurations[i] = steps[i]['duration'] as int;
    }
    _cookingStartTime = DateTime.now();
    _currentStepIndex = 0;
    _startStepTimer(0, steps);
  }

  @override
  void dispose() {
    _stepTimers.values.forEach((timer) => timer?.cancel());
    super.dispose();
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
      HistoryPage.addCompletedMeal({
        'mealID': widget.mealId,
        'mealName': widget.mealData['mealName'],
        'mealPicture': widget.mealData['mealPicture'] ?? 'assets/default_meal.jpg',
        'servings': widget.mealData['servings'] ?? 1,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [
            Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
          ]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cooking Quest: ${widget.mealData['mealName']}',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Exo', // Updated to Exo
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
            ],
          ),
        ),
      ),
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
        child: Column(
          children: [
            SizedBox(height: AppBar().preferredSize.height + MediaQuery.of(context).padding.top),
            LinearProgressIndicator(
              value: (_currentStepIndex + 1) / steps.length,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF76C893)),
              minHeight: 6,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
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
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: steps.length,
                        itemBuilder: (context, idx) {
                          var step = steps[idx];
                          bool isCurrent = idx == _currentStepIndex;
                          bool isCompleted = idx < _currentStepIndex;
                          bool isFuture = idx > _currentStepIndex;
                          return AnimatedOpacity(
                            opacity: isFuture ? 0.6 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isCurrent 
                                    ? const Color(0xFFB5E48C).withOpacity(0.2) 
                                    : (isCompleted ? Colors.grey[100] : Colors.white),
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
                                            fontFamily: 'Exo', // Updated to Exo
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  step['title'],
                                  style: TextStyle(
                                    fontFamily: 'Exo', // Updated to Exo
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? const Color(0xFF184E77) : (isCompleted ? Colors.grey[600] : Colors.black87),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step['content'],
                                      style: TextStyle(
                                        fontFamily: 'Poppins', // Updated to Poppins
                                        fontSize: 14,
                                        color: isCurrent ? Colors.black87 : (isCompleted ? Colors.grey[600] : Colors.black54),
                                      ),
                                    ),
                                    if (step['duration'] > 0 && _stepRemainingTimes.containsKey(idx))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Time Left: ${(_stepRemainingTimes[idx]! ~/ 60)}:${(_stepRemainingTimes[idx]! % 60).toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontFamily: 'Poppins', // Updated to Poppins
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent ? Colors.red[600] : Colors.grey[600],
                                          ),
                                        ).animate().fadeIn(duration: 300.ms),
                                      ),
                                    if (step['duration'] > 0)
                                      Text(
                                        'Estimated: ${step['duration'] ~/ 60} mins',
                                        style: TextStyle(
                                          fontFamily: 'Poppins', // Updated to Poppins
                                          fontSize: 12,
                                          color: isCurrent ? Colors.black54 : Colors.grey[600],
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
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                ),
                                                child: const Text(
                                                  'Back',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins', // Updated to Poppins
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
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
                                                      _cookingEndTime = DateTime.now();
                                                      _stepTimers.values.forEach((t) => t?.cancel());
                                                      _stepTimers.clear();
                                                      _stepRemainingTimes.clear();
                                                      _stepOriginalDurations.clear();
                                                      await _saveToCompletedHistory();

                                                      // Parse estimated time
                                                      int estimated = 0;
                                                      final cookingTime = widget.mealData['cookingTime'] as String? ?? '';
                                                      final timeMatch = RegExp(r'(\d+)(?:-(\d+))?').firstMatch(cookingTime);
                                                      if (timeMatch != null) {
                                                        int min1 = int.parse(timeMatch.group(1)!);
                                                        int min2 = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : min1;
                                                        estimated = (min1 + min2) ~/ 2;
                                                      }

                                                      // Navigate to completion screen
                                                      Navigator.pushReplacement(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => MealCompletionPage(
                                                            mealName: widget.mealData['mealName'],
                                                            mealPicture: widget.mealData['mealPicture'] ?? 'assets/default_meal.jpg',
                                                            timeTaken: _cookingEndTime!.difference(_cookingStartTime!).inMinutes,
                                                            estimatedTime: estimated,
                                                            calories: widget.mealData['calories'] ?? 0,
                                                            servings: widget.mealData['servings'] ?? 1,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.white,
                                                    foregroundColor: const Color(0xFF184E77),
                                                    elevation: 10,
                                                    shadowColor: Colors.greenAccent,
                                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                  ),
                                                  child: Text(
                                                    _currentStepIndex == steps.length - 1 ? 'Complete Quest' : 'Next Step',
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins', // Updated to Poppins
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ).animate().scale(duration: 200.ms, curve: Curves.easeInOut),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: isFuture ? null : () {
                                  _pauseStepTimer(_currentStepIndex);
                                  _resetStepTimer(_currentStepIndex);
                                  setState(() {
                                    _currentStepIndex = idx;
                                  });
                                  _startStepTimer(_currentStepIndex, steps);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}