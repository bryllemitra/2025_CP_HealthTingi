// Modified navigation.dart with UI consistency to login.dart theme
import 'package:flutter/material.dart';
import '../information/profile.dart';
import '../information/about_us.dart';
import '../information/fAQs.dart';
import 'index.dart';

class NavigationDrawerWidget extends StatelessWidget {
  final int userId;
  const NavigationDrawerWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white.withOpacity(0.1), // Semi-transparent like register card
      child: Container(
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 16),
              child: Text(
                'HealthTingi',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(2, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            if (userId != 0) // Only show Profile for registered users
              Column(
                children: [
                  _drawerButton(context, Icons.person, 'Profile'),
                  const SizedBox(height: 8),
                ],
              ),
            _drawerButton(context, Icons.info_outline, 'About Us'),
            const SizedBox(height: 8),
            _drawerButton(context, Icons.help_outline, 'FAQs'),
            const SizedBox(height: 8),
            _drawerButton(
              context, 
              Icons.logout, 
              userId == 0 ? 'Exit Guest Mode' : 'Logout'
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerButton(BuildContext context, IconData icon, String label) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: const Color(0xFF184E77),
        elevation: 10,
        shadowColor: Colors.greenAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: () {
        Navigator.pop(context); // Close drawer first
        switch (label) {
          case 'Profile':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
            );
            break;
          case 'About Us':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutUsPage()),
            );
            break;
          case 'FAQs':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FAQSPage()),
            );
            break;
          case 'Logout':
          case 'Exit Guest Mode':
            // Redirect to IndexPage and remove previous stack
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const IndexPage()),
              (Route<dynamic> route) => false,
            );
            break;
        }
      },
      icon: Icon(icon, size: 24),
      label: Text(
        label, 
        style: const TextStyle(
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}