// Modified information/about_us.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AboutUsPage extends StatefulWidget {
  final bool isAdmin;

  const AboutUsPage({super.key, this.isAdmin = false});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _content = '';          // <-- now non-nullable (will be set in _loadContent)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    final String? fetched = await _dbHelper.getAboutUsContent();
    setState(() {
      _content = fetched ??
          'By combining real-time ingredient recognition, a local price-aware recipe engine, and offline access, HealthTingi empowers families to make the most of what’s available—whether in urban or rural communities. Our mission is to use simple technology to address food insecurity, improve nutrition, and support smarter meal planning across the Philippines.\n\nEat Smart. Live Better.';
      _isLoading = false;
    });
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: _content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit About Us'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Content'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbHelper.updateAboutUsContent(controller.text);
              Navigator.pop(context);
              _loadContent();               // <-- refresh UI after save
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

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
                          'About Us',
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
                    // ------------------- EDIT BUTTON (ADMIN ONLY) -------------------
                    if (widget.isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: _showEditDialog,
                        tooltip: 'Edit About Us',
                      )
                    else
                      const SizedBox(width: 48), // Balance the layout with back button
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                  child: Text(
                                    _content,               // <-- now guaranteed non-null
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Exo',
                                      color: Color(0xFF184E77),
                                      height: 1.6,
                                    ),
                                    textAlign: TextAlign.center,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}