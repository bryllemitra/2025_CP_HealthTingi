import 'package:flutter/material.dart';
import 'meal_scan.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFE0), // Light yellowish background
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/logo.png',
                width: 160,
                height: 160,
              ),

              const SizedBox(height: 40),

              // App name
              const Text(
                'HealthTingi',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),

              // Register Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shadowColor: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: const Color(0xFFFFFF66), // Light yellow
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shadowColor: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Guest Option
              GestureDetector(
                onTap: () {
                  // Navigate directly to MealScanPage with userId = 0 (guest)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MealScanPage(userId: 0),
                    ),
                  );
                },
                child: const Text(
                  'Use as a Guest',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
