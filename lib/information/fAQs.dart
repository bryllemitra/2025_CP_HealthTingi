// Modified information/fAQs.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class FAQSPage extends StatefulWidget {
  final bool isAdmin;

  const FAQSPage({super.key, this.isAdmin = false});

  @override
  State<FAQSPage> createState() => _FAQSPageState();
}

class _FAQSPageState extends State<FAQSPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _faqs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    setState(() => _isLoading = true);
    _faqs = await _dbHelper.getFaqs();
    setState(() => _isLoading = false);
  }

  void _showEditDialog({Map<String, dynamic>? faq}) {
    final questionController = TextEditingController(text: faq?['question']);
    final answerController = TextEditingController(text: faq?['answer']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(faq == null ? 'Add FAQ' : 'Edit FAQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(labelText: 'Answer'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (faq == null) {
                await _dbHelper.insertFaq({
                  'question': questionController.text,
                  'answer': answerController.text,
                });
              } else {
                await _dbHelper.updateFaq(faq['id'], {
                  'question': questionController.text,
                  'answer': answerController.text,
                });
              }
              Navigator.pop(context);
              _loadFaqs();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteFaq(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete FAQ'),
        content: const Text('Are you sure you want to delete this FAQ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbHelper.deleteFaq(id);
              Navigator.pop(context);
              _loadFaqs();
            },
            child: const Text('Delete'),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Frequently Asked',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
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
                            Text(
                              'Questions',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
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
                          ],
                        ),
                      ),
                    ),
                    if (widget.isAdmin)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => _showEditDialog(),
                      )
                    else
                      const SizedBox(width: 48), // Balance the layout with back button
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
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
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _faqs.length,
                                  itemBuilder: (context, index) {
                                    final faq = _faqs[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  faq['question'],
                                                  style: const TextStyle(
                                                    fontFamily: 'Orbitron',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF184E77),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  faq['answer'],
                                                  style: const TextStyle(
                                                    fontFamily: 'Exo',
                                                    fontSize: 14,
                                                    color: Color(0xFF184E77),
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (widget.isAdmin)
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, size: 20),
                                                  onPressed: () => _showEditDialog(faq: faq),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, size: 20),
                                                  onPressed: () => _deleteFaq(faq['id']),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                  },
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
}