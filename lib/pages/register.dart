import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';
import '../database/db_helper.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool hasDietaryRestrictions = false;
  List<String> selectedDietaryRestrictions = [];
  bool agreeToTerms = false;
  bool hasReadTerms = false;
  bool _isLoading = false;
  final TextEditingController _otherRestrictionController = TextEditingController();
  DateTime? _selectedBirthday;
  bool _isUnderage = false;
  bool _showPasswordNote = true;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  late PageController _pageController;
  int _currentPage = 0;
  late List<GlobalKey<FormState>> _pageFormKeys;
  final ScrollController _termsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageFormKeys = List.generate(4, (index) => GlobalKey<FormState>());
    passwordController.addListener(() {
      setState(() {
        _showPasswordNote = passwordController.text.length < 6;
      });
    });
    _termsScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _otherRestrictionController.dispose();
    _pageController.dispose();
    _termsScrollController.removeListener(_scrollListener);
    _termsScrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_termsScrollController.position.extentAfter <= 20 && !hasReadTerms) {
      setState(() {
        hasReadTerms = true;
      });
    }
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _validatePasswordLength(String password) {
    return RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[!@#$%^&*(),.?":{}|<>_]).{6,30}$').hasMatch(password);
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _showAgeRestrictionDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Age Restriction', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You must be at least 18 years old to register.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF184E77))),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF184E77),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final age = _calculateAge(picked);
      final isUnderage = age < 18;
      
      setState(() {
        _selectedBirthday = picked;
        _isUnderage = isUnderage;
      });
      
      if (isUnderage) {
        await _showAgeRestrictionDialog();
      }
    }
  }

  Future<void> _addCustomRestriction() async {
    if (_otherRestrictionController.text.trim().isEmpty) return;

    setState(() {
      selectedDietaryRestrictions.add(_otherRestrictionController.text.trim());
      _otherRestrictionController.clear();
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _showCustomRestrictionDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Custom Restriction', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _otherRestrictionController,
            decoration: InputDecoration(
              hintText: 'Enter your dietary restriction',
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF184E77))),
            ),
            TextButton(
              onPressed: () {
                _addCustomRestriction();
                Navigator.pop(context);
              },
              child: const Text('Add', style: TextStyle(color: Color(0xFF184E77))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goNext() async {
    switch (_currentPage) {
      case 0:
        if (!_pageFormKeys[0].currentState!.validate()) {
          return;
        }
        if (_selectedBirthday == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select your birthday.')),
          );
          return;
        }
        if (_isUnderage) {
          await _showAgeRestrictionDialog();
          return;
        }
        break;
      case 1:
        if (!_pageFormKeys[1].currentState!.validate()) {
          return;
        }
        break;
      case 2:
        if (hasDietaryRestrictions && selectedDietaryRestrictions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one dietary restriction.')),
          );
          return;
        }
        break;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage++;
    });
  }

  Future<void> _submitForm() async {
    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday.')),
      );
      return;
    }

    final age = _calculateAge(_selectedBirthday!);
    if (age < 18) {
      await _showAgeRestrictionDialog();
      return;
    }

    if (!agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must agree to the terms and conditions.')),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (!_validateEmail(emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (!_validatePasswordLength(passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be between 6 and 30 characters and include uppercase, lowercase, and special characters.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (hasDietaryRestrictions && selectedDietaryRestrictions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one dietary restriction.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbHelper = DatabaseHelper();
      final emailExists = await dbHelper.getUserByEmail(emailController.text);
      final usernameExists = await dbHelper.getUserByUsername(usernameController.text);

      if (emailExists != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email already registered.')),
        );
        return;
      }

      if (usernameExists != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username already taken.')),
        );
        return;
      }

      final user = {
        'firstName': _sanitizeInput(firstNameController.text),
        'middleName': middleNameController.text.trim().isEmpty 
            ? null 
            : _sanitizeInput(middleNameController.text),
        'lastName': _sanitizeInput(lastNameController.text),
        'emailAddress': _sanitizeInput(emailController.text),
        'username': _sanitizeInput(usernameController.text),
        'password': _hashPassword(passwordController.text),
        'hasDietaryRestriction': hasDietaryRestrictions ? 1 : 0,
        'dietaryRestriction': hasDietaryRestrictions 
            ? selectedDietaryRestrictions.join(', ') 
            : null,
        'favorites': null,
        'birthday': _selectedBirthday!.toIso8601String().split('T')[0],
        'age': age,
        'gender': null,
        'street': null,
        'barangay': null,
        'city': null,
        'nationality': null,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await dbHelper.insertUser(user);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _sanitizeInput(String input) {
    return input
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll(';', '');
  }

  Widget _buildTextField(TextEditingController controller, String hintText,
      {bool isObscure = false, 
       TextInputType? keyboardType, 
       String? Function(String?)? validator,
       bool isOptional = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: isOptional ? '$hintText (Optional)' : hintText,
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        prefixIcon: Icon(
          hintText.contains('Email') ? Icons.email_outlined :
          hintText.contains('Password') ? Icons.lock_outline :
          hintText.contains('Username') ? Icons.person_outline :
          Icons.text_fields,
          color: const Color(0xFF184E77),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        errorStyle: const TextStyle(color: Color(0xFF184E77)),
      ),
      validator: validator ?? (isOptional ? null : (value) {
        if (value == null || value.isEmpty) {
          return '$hintText is required';
        }
        return null;
      }),
    );
  }

  Widget _buildBirthdayField() {
    return InkWell(
      onTap: () => _selectBirthday(context),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Select your birthday',
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF184E77)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          errorText: _isUnderage ? 'Must be 18 years or older' : null,
          errorStyle: const TextStyle(color: Color(0xFF184E77)),
        ),
        child: Text(
          _selectedBirthday != null
              ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
              : 'Select your birthday',
          style: TextStyle(
            color: _selectedBirthday != null 
              ? (_isUnderage ? Colors.red : Colors.black87) 
              : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return Form(
      key: _pageFormKeys[0],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Step 1: Personal Information',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildTextField(firstNameController, 'First Name'),
            const SizedBox(height: 16),
            _buildTextField(middleNameController, 'Middle Name', isOptional: true),
            const SizedBox(height: 16),
            _buildTextField(lastNameController, 'Last Name'),
            const SizedBox(height: 16),
            _buildBirthdayField(),
            if (_selectedBirthday != null) ...[
              const SizedBox(height: 8),
              Text(
                'Age: ${_calculateAge(_selectedBirthday!)} years old',
                style: TextStyle(
                  fontSize: 12,
                  color: _isUnderage ? Colors.red : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoPage() {
    return Form(
      key: _pageFormKeys[1],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Step 2: Account Details',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              emailController, 
              'Email Address', 
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!_validateEmail(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              usernameController, 
              'Username',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Username is required';
                }
                if (value.length < 4) {
                  return 'Username must be at least 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              passwordController, 
              'Password', 
              isObscure: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (!_validatePasswordLength(value)) {
                  return 'Password must be 6-30 characters with uppercase, lowercase, and special characters';
                }
                return null;
              },
            ),
            if (_showPasswordNote) ...[
              const SizedBox(height: 8),
              const Text(
                'Password must be at least 6 characters with uppercase, lowercase, and special characters',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              confirmPasswordController, 
              'Confirm Password', 
              isObscure: true,
              validator: (value) {
                if (value != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietaryPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Step 3: Dietary Restrictions',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(2, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Do you have any dietary restrictions?',
            style: TextStyle(color: Colors.white70),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: hasDietaryRestrictions,
                onChanged: _isUnderage ? null : (val) => setState(() => hasDietaryRestrictions = val!),
                activeColor: const Color(0xFF76C893),
                checkColor: Colors.white,
              ),
              const Text('Yes', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 16),
              Checkbox(
                value: !hasDietaryRestrictions,
                onChanged: _isUnderage ? null : (val) => setState(() => hasDietaryRestrictions = !val!),
                activeColor: const Color(0xFF76C893),
                checkColor: Colors.white,
              ),
              const Text('No', style: TextStyle(color: Colors.white70)),
            ],
          ),
          if (hasDietaryRestrictions) ...[
            const SizedBox(height: 16),
            const Text(
              'Please select your dietary restriction(s):',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                'Vegan',
                'Vegetarian',
                'Gluten-Free',
                'Lactose Intolerant',
                'Halal',
                'Kosher',
                'Nut Allergy',
                'Shellfish Allergy',
              ].map((restriction) {
                return FilterChip(
                  label: Text(restriction, style: const TextStyle(color: Colors.black87)),
                  selected: selectedDietaryRestrictions.contains(restriction),
                  onSelected: _isUnderage ? null : (selected) {
                    setState(() {
                      if (selected) {
                        selectedDietaryRestrictions.add(restriction);
                      } else {
                        selectedDietaryRestrictions.remove(restriction);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF76C893),
                  backgroundColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              children: [
                ActionChip(
                  label: const Text('Other...'),
                  onPressed: _isUnderage ? null : _showCustomRestrictionDialog,
                  avatar: const Icon(Icons.add, color: Color(0xFF184E77)),
                  backgroundColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                if (selectedDietaryRestrictions.isNotEmpty)
                  ActionChip(
                    label: const Text('Clear All'),
                    onPressed: _isUnderage ? null : () {
                      setState(() {
                        selectedDietaryRestrictions.clear();
                      });
                    },
                    backgroundColor: Colors.red.withOpacity(0.3),
                    avatar: const Icon(Icons.clear, color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
            if (selectedDietaryRestrictions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Selected Restrictions:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: selectedDietaryRestrictions.map((restriction) {
                  return Chip(
                    label: Text(restriction, style: const TextStyle(color: Colors.black87)),
                    onDeleted: _isUnderage ? null : () {
                      setState(() {
                        selectedDietaryRestrictions.remove(restriction);
                      });
                    },
                    backgroundColor: const Color(0xFF76C893),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    deleteIconColor: Colors.red,
                  );
                }).toList(),
              ),
            ],
            if (selectedDietaryRestrictions.isEmpty && hasDietaryRestrictions)
              const Text(
                'Please select at least one dietary restriction',
                style: TextStyle(color: Color(0xFF184E77)),
              ),
          ],
        ],
      ),
    );
  }

 Widget _buildTermsPage() {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05, vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 4: Terms and Conditions',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 6),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // TERMS CARD — FULL WIDTH, SCROLLABLE
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Scrollbar(
              thumbVisibility: true,
              controller: _termsScrollController,
              child: SingleChildScrollView(
                controller: _termsScrollController,
                child: const Text(
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
                  style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // "I AGREE" CHECKBOX — ONLY AFTER SCROLLING
        if (hasReadTerms)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: agreeToTerms,
                  onChanged: _isUnderage ? null : (val) => setState(() => agreeToTerms = val!),
                  activeColor: const Color(0xFF76C893),
                  checkColor: Colors.white,
                  side: const BorderSide(color: Colors.black54, width: 1.5),
                ),
                const Expanded(
                  child: Text(
                    'I agree to the terms and conditions',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

  Widget _buildNavigationButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentPage--);
                  },
                  child: const Text(
                    'Previous',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                )
              else
                const SizedBox(width: 60),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                )),
              ),
              if (_currentPage < 3)
                ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF184E77),
                    elevation: 10,
                    shadowColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: (_isUnderage || _isLoading || !agreeToTerms) ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUnderage ? Colors.grey : Colors.white,
                    foregroundColor: const Color(0xFF184E77),
                    elevation: 10,
                    shadowColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF184E77)),
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
            child: const Text(
              'Already have an account? Login Here',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Orbitron',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: const Text(
                          'HealthTingi',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 50),
                      Card(
                        color: Colors.white.withOpacity(0.2),
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: PageView(
                                  controller: _pageController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  onPageChanged: (index) => setState(() => _currentPage = index),
                                  children: [
                                    _buildPersonalInfoPage(),
                                    _buildAccountInfoPage(),
                                    _buildDietaryPage(),
                                    _buildTermsPage(),
                                  ],
                                ),
                              ),
                              _buildNavigationButtons(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}