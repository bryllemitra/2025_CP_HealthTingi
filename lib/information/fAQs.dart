import 'package:flutter/material.dart';

class FAQSPage extends StatelessWidget {
  const FAQSPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Frequently Asked',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Questions',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the layout with back button
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with soft highlight glow
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 120,
                            height: 120,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFAQItem(
                                question: '1. What is HealthTingi?',
                                answer: 'HealthTingi is an Android app that helps you scan ingredients using your phone’s camera and suggests budget-friendly recipes you can cook with them—even without an internet connection.',
                              ),
                              _buildFAQItem(
                                question: '2. Who is the app for?',
                                answer: 'It’s specially designed for low-income Filipino households, but anyone looking for affordable and nutritious meals can use it.',
                              ),
                              _buildFAQItem(
                                question: '3. Do I need Wi-Fi or mobile data to use it?',
                                answer: 'No. HealthTingi works offline, so you can use all main features like scanning, viewing recipes, and searching ingredients anytime.',
                              ),
                              _buildFAQItem(
                                question: '4. How does the scanner work?',
                                answer: 'Just take a photo of your ingredients, and the app will identify multiple items at once using image recognition powered by a trained AI model.',
                              ),
                              _buildFAQItem(
                                question: '5. Can I still get recipe suggestions if I don’t have a complete ingredient list?',
                                answer: 'Yes! HealthTingi shows substitution options and recommends recipes based on what you do have.',
                              ),
                              _buildFAQItem(
                                question: '6. What if prices in my area are different?',
                                answer: 'You can manually input or update prices, and the app averages community-submitted prices to stay accurate for your location.',
                              ),
                              _buildFAQItem(
                                question: '7. Is it free to use?',
                                answer: 'Yes, HealthTingi is completely free.',
                              ),
                              _buildFAQItem(
                                question: '8. Where does the recipe and nutrition data come from?',
                                answer: 'The app uses locally sourced data and Filipino recipes tailored to ingredients commonly found in local markets.',
                              ),
                              _buildFAQItem(
                                question: '9. How does it know what recipes are affordable for me?',
                                answer: 'You can enter your budget (like ₱70), and the app filters out recipes that exceed it, using current ingredient prices.',
                              ),
                              _buildFAQItem(
                                question: '10. Can I suggest a recipe or report a problem?',
                                answer: 'Yes, you can suggest recipes or feedback through the app’s “Contact Us” feature (if included), or by email.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Eat Smart. Live Better.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF184E77),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              fontFamily: 'Exo',
              fontSize: 14,
              color: Color(0xFF184E77),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}