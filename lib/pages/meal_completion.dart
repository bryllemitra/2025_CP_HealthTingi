// New file: pages/meal_completion.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:photo_view/photo_view.dart';

class MealCompletionPage extends StatefulWidget {
  final String mealName;
  final String mealPicture;
  final int timeTaken;
  final int estimatedTime;
  final int calories;
  final int servings;

  const MealCompletionPage({
    super.key,
    required this.mealName,
    required this.mealPicture,
    required this.timeTaken,
    required this.estimatedTime,
    required this.calories,
    required this.servings,
  });

  @override
  State<MealCompletionPage> createState() => _MealCompletionPageState();
}

class _MealCompletionPageState extends State<MealCompletionPage> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quest Completed!',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 25,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: PhotoView(
                            imageProvider: widget.mealPicture.startsWith('assets/')
                                ? AssetImage(widget.mealPicture)
                                : FileImage(File(widget.mealPicture)),
                            backgroundDecoration: const BoxDecoration(color: Colors.black),
                            minScale: PhotoViewComputedScale.contained,
                            maxScale: PhotoViewComputedScale.covered * 4.0,
                            heroAttributes: PhotoViewHeroAttributes(tag: widget.mealPicture),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: widget.mealPicture.startsWith('assets/')
                          ? Image.asset(
                              widget.mealPicture,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(widget.mealPicture),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You’ve just finished cooking ${widget.mealName}! Great job, Chef!',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Time Taken: ${widget.timeTaken} minutes (estimated: ${widget.estimatedTime} minutes)',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calories: ${widget.calories} | Servings: ${widget.servings}',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Rate Your Experience',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        icon: Icon(
                          i < _rating ? Icons.star : Icons.star_border,
                          color: Colors.yellow[700],
                          size: 40,
                        ),
                        onPressed: () => setState(() => _rating = i + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF184E77),
                      elevation: 10,
                      shadowColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Back to Meal Details',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}