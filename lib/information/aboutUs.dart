import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

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
        title: const Text(
          'About Us',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
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
            'HealthTingi is a mobile application designed to promote affordable and nutritious eating for low-income Filipino households. Built with accessibility in mind, the app helps users identify ingredients using a simple photo and suggests budget-friendly recipes based on what they have and how much they can spend.\n\n'
            'By combining real-time ingredient recognition, a local price-aware recipe engine, and offline access, HealthTingi empowers families to make the most of what’s available—whether in urban or rural communities. Our mission is to use simple technology to address food insecurity, improve nutrition, and support smarter meal planning across the Philippines.',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Exo',
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
