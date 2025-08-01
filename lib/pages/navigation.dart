import 'package:flutter/material.dart';
import '../information/profile.dart';
import '../information/about_us.dart';
import '../information/fAQs.dart';
import 'index.dart'; // ✅ Import IndexPage here

class NavigationDrawerWidget extends StatelessWidget {
  final int userId;
  const NavigationDrawerWidget({super.key, required this.userId});

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

  Widget _drawerButton(BuildContext context, IconData icon, String label) {
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
        Navigator.pop(context); // Close drawer first
        switch (label) {
          case 'Profile':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(userId: userId,)),
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
            // ✅ Redirect to IndexPage and remove previous stack
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const IndexPage()),
              (Route<dynamic> route) => false,
            );
            break;
        }
      },
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontFamily: 'Orbitron')),
    );
  }
}
