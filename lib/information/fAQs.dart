import 'package:flutter/material.dart';

class FAQSPage extends StatelessWidget {
  const FAQSPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDDD),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Frequently Asked',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'Questions',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black87),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(4, 4),
                  blurRadius: 4,
                )
              ],
            ),
            child: const Text(
              "1. What is HealthTingi?\nHealthTingi is an Android app that helps you scan ingredients using your phone’s camera and suggests budget-friendly recipes you can cook with them—even without an internet connection.\n\n"
              "2. Who is the app for?\nIt’s specially designed for low-income Filipino households, but anyone looking for affordable and nutritious meals can use it.\n\n"
              "3. Do I need Wi-Fi or mobile data to use it?\nNo. HealthTingi works offline, so you can use all main features like scanning, viewing recipes, and searching ingredients anytime.\n\n"
              "4. How does the scanner work?\nJust take a photo of your ingredients, and the app will identify multiple items at once using image recognition powered by a trained AI model.\n\n"
              "5. Can I still get recipe suggestions if I don’t have a complete ingredient list?\nYes! HealthTingi shows substitution options and recommends recipes based on what you do have.\n\n"
              "6. What if prices in my area are different?\nYou can manually input or update prices, and the app averages community-submitted prices to stay accurate for your location.\n\n"
              "7. Is it free to use?\nYes, HealthTingi is completely free.\n\n"
              "8. Where does the recipe and nutrition data come from?\nThe app uses locally sourced data and Filipino recipes tailored to ingredients commonly found in local markets.\n\n"
              "9. How does it know what recipes are affordable for me?\nYou can enter your budget (like ₱70), and the app filters out recipes that exceed it, using current ingredient prices.\n\n"
              "10. Can I suggest a recipe or report a problem?\nYes, you can suggest recipes or feedback through the app's “Contact Us” feature (if included), or by email.",
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Exo',
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}