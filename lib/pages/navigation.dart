// Modified navigation.dart with UI consistency to login.dart theme
import 'package:flutter/material.dart';
import '../information/profile.dart';
import '../information/about_us.dart';
import '../information/fAQs.dart';
import 'index.dart';
import '../admin/dashboard.dart'; 

class NavigationDrawerWidget extends StatelessWidget {
  final int userId;
  const NavigationDrawerWidget({super.key, required this.userId});

  bool get _isAdmin => userId == 1; // Assuming Admin is always ID 1

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white.withOpacity(0.1),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFB5E48C),
              Color(0xFF76C893),
              Color(0xFF184E77),
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
                  fontFamily: 'Exo', 
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
                  ],
                ),
              ),
            ),
            
            // 👇 NEW: Admin Dashboard Link (Only visible to Admin)
            if (_isAdmin) ...[
              _drawerButton(context, Icons.dashboard, 'Admin Dashboard'),
              const SizedBox(height: 8),
            ],

            if (userId != 0)
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
              userId == 0 ? 'Exit Guest Mode' : 'Logout',
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
          // 👇 NEW CASE: Navigate to Dashboard
          case 'Admin Dashboard':
            Navigator.pushReplacement( // Use replacement to avoid back-stack loop
              context,
              MaterialPageRoute(builder: (context) => AdminDashboardPage(userId: userId)),
            );
            break;
            
          case 'Profile':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
            );
            break;
          case 'About Us':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AboutUsPage(isAdmin: _isAdmin), 
              ),
            );
            break;
          case 'FAQs':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FAQSPage(isAdmin: _isAdmin), 
              ),
            );
            break;
          case 'Logout':
          case 'Exit Guest Mode':
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
          fontFamily: 'Poppins', 
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
