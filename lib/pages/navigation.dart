import 'package:flutter/material.dart';
import '../information/profile.dart';
import '../information/aboutUs.dart';
import '../information/fAQs.dart';


class NavigationDrawerWidget extends StatelessWidget {
  const NavigationDrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
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
              ),
            ),
          ),
          _drawerButton(context, Icons.person, 'Profile'),
          const SizedBox(height: 8),
          _drawerButton(context, Icons.info_outline, 'About Us'),
          const SizedBox(height: 8),
          _drawerButton(context, Icons.help_outline, 'FAQs'),
          const SizedBox(height: 8),
          _drawerButton(context, Icons.logout, 'Logout'),
        ],
      ),
    );
  }

  Widget _drawerButton(
      BuildContext context, IconData icon, String label) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFFF66),
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onPressed: () {
        Navigator.pop(context); // Close drawer before navigating
        switch (label) {
          case 'Profile':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
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
            // TODO: Add logout logic
            break;
        }
      },
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontFamily: 'Orbitron')),
    );
  }
}
