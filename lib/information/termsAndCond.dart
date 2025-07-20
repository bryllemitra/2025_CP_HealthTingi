import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Text(
              '''1. Acceptance of Terms
By using this application, you agree to these Terms and Conditions. If you do not agree, please do not use the app.

2. Purpose
This app is designed for educational and informational use only. It helps users plan meals based on budget, scan ingredients, and suggest alternatives.

3. User Responsibility
You are responsible for how you use the information provided by the app. While we try to suggest healthy and affordable meals, the app does not guarantee nutritional accuracy or safety (especially for those with allergies or dietary conditions).

4. Dietary & Health Disclaimers
This app is not a substitute for professional medical advice. Always consult a nutritionist or healthcare provider for serious dietary concerns.

5. Data Collection
The app may store non-personal data such as dietary preferences and recent scans to improve your experience. We do not collect or share personal or sensitive information.

6. Limitations
This app is part of a student project and not intended for commercial use. There may be bugs, inaccuracies, or incomplete features.

7. Changes to Terms
We may update these terms as the app improves. Any changes will be reflected in this section.
''',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
