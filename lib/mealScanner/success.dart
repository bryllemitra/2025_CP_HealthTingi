import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'scanned_ingredient.dart';

class ScanSuccessPage extends StatelessWidget {
  final int userId;
  final List<dynamic>? recognitions;
  final String? imagePath;

  const ScanSuccessPage({
    super.key, 
    required this.userId,
    this.recognitions,
    this.imagePath,
  });

  List<String> getDetectedIngredients() {
    if (recognitions == null) return [];
    return recognitions!
        .where((recognition) => recognition['confidence'] > 0.5)
        .map((recognition) => recognition['label'].toString())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final detectedIngredients = getDetectedIngredients();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              "You've scanned\nyour ingredient/s",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (imagePath != null)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(imagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Image.asset(
                'assets/chef.jpg',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            if (detectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "Detected:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...detectedIngredients.map((ingredient) => Text(
                    ingredient,
                    style: const TextStyle(fontSize: 14),
                  )),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 4,
                side: const BorderSide(color: Colors.black, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32, 
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScannedIngredientPage(
                      userId: userId,
                      detectedIngredients: detectedIngredients,
                    ),
                  ),
                );
              },
              child: const Text(
                'VIEW INGREDIENT/S',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 16,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'SCAN AGAIN',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 14,
                  color: Colors.black54,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}