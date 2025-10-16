import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

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
                        child: Text(
                          'Terms and Conditions',
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
                              _buildTermItem(
                                title: '1. Acceptance of Terms',
                                content: 'By using this application, you agree to these Terms and Conditions. If you do not agree, please do not use the app.',
                              ),
                              _buildTermItem(
                                title: '2. Purpose',
                                content: 'This app is designed for educational and informational use only. It helps users plan meals based on budget, scan ingredients, and suggest alternatives.',
                              ),
                              _buildTermItem(
                                title: '3. User Responsibility',
                                content: 'You are responsible for how you use the information provided by the app. While we try to suggest healthy and affordable meals, the app does not guarantee nutritional accuracy or safety (especially for those with allergies or dietary conditions).',
                              ),
                              _buildTermItem(
                                title: '4. Dietary & Health Disclaimers',
                                content: 'This app is not a substitute for professional medical advice. Always consult a nutritionist or healthcare provider for serious dietary concerns.',
                              ),
                              _buildTermItem(
                                title: '5. Data Collection',
                                content: 'The app may store non-personal data such as dietary preferences and recent scans to improve your experience. We do not collect or share personal or sensitive information.',
                              ),
                              _buildTermItem(
                                title: '6. Limitations',
                                content: 'This app is part of a student project and not intended for commercial use. There may be bugs, inaccuracies, or incomplete features.',
                              ),
                              _buildTermItem(
                                title: '7. Changes to Terms',
                                content: 'We may update these terms as the app improves. Any changes will be reflected in this section.',
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

  Widget _buildTermItem({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF184E77),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
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