// onboarding_screen.dart
import 'package:flutter/material.dart';
import 'meal_scan.dart'; // Import your scanner page

class OnboardingScreen extends StatefulWidget {
  final int userId;
  const OnboardingScreen({super.key, required this.userId});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // List of onboarding pages
  final List<Widget> _onboardingPages = [
    const OnboardingPage(
      image: Icons.camera_alt_rounded, // Or use an actual image asset
      title: 'Scan Your Ingredients',
      description: 'Point your camera at any ingredient to identify it instantly. Perfect for figuring out what\'s in your fridge!',
    ),
    const OnboardingPage(
      image: Icons.health_and_safety,
      title: 'Get Nutrition Facts & Recipes',
      description: 'Discover detailed nutrition information and get personalized recipe suggestions based on what you scan.',
    ),
    const OnboardingPage(
      image: Icons.perm_camera_mic, // Or a shield icon
      title: 'We Need Camera Access',
      description: 'To scan your ingredients, we need permission to use your camera. We only use it for scanning and never store your photos.',
    ),
  ];

  void _onNext() {
    if (_currentPage < _onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      // On the last page, navigate to the MealScanPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MealScanPage(userId: widget.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Match your app's theme
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingPages.length,
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                itemBuilder: (context, index) => _onboardingPages[index],
              ),
            ),
            // Progress Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _onboardingPages.length,
                (index) => Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.green // Your accent color
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Next Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Your accent color
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentPage == _onboardingPages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget for each individual onboarding page
class OnboardingPage extends StatelessWidget {
  final IconData image;
  final String title;
  final String description;

  const OnboardingPage({
    super.key,
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(image, size: 100, color: Colors.green),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}