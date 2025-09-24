import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login.dart';
import '../information/terms_and_cond.dart';
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
    super.dispose();
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
    return RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[!@#$%^&*(),.?":{}|<>]).{6,30}$').hasMatch(password);
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
        title: const Text('Age Restriction'),
        content: const Text('You must be at least 18 years old to register.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
          title: const Text('Add Custom Restriction'),
          content: TextField(
            controller: _otherRestrictionController,
            decoration: const InputDecoration(
              hintText: 'Enter your dietary restriction',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addCustomRestriction();
                Navigator.pop(context);
              },
              child: const Text('Add'),
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
          content: Text('Password must be between 6 and 30 characters long.'),
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

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isObscure = false, 
       TextInputType? keyboardType, 
       String? Function(String?)? validator,
       bool isOptional = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: isOptional ? '$label (Optional)' : label,
        border: const OutlineInputBorder(),
        helperStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
      validator: validator ?? (isOptional ? null : (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
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
          labelText: 'Birthday *',
          border: const OutlineInputBorder(),
          errorText: _isUnderage ? 'Must be 18 years or older' : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedBirthday != null
                  ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                  : 'Select your birthday',
              style: TextStyle(
                color: _selectedBirthday != null 
                  ? (_isUnderage ? Colors.red : Colors.black) 
                  : Colors.grey,
              ),
            ),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return Form(
      key: _pageFormKeys[0],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step 1: Name and Birthday',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              _buildTextField(firstNameController, 'First Name'),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              _buildTextField(middleNameController, 'Middle Name', isOptional: true),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              _buildTextField(lastNameController, 'Last Name'),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              _buildBirthdayField(),
              if (_selectedBirthday != null) ...[
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                Text(
                  'Age: ${_calculateAge(_selectedBirthday!)} years old',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isUnderage ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountInfoPage() {
    return Form(
      key: _pageFormKeys[1],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step 2: Account Details',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
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
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
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
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              _buildTextField(
                passwordController, 
                'Password', 
                isObscure: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (!_validatePasswordLength(value)) {
                    return 'Password must be between 6 and 30 characters';
                  }
                  return null;
                },
              ),
              if (_showPasswordNote) ...[
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                const Text(
                  'Password must be at least 6 characters',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
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
      ),
    );
  }

  Widget _buildDietaryPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 3: Dietary Restrictions',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            const Text('Do you have any Dietary Restrictions?'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: hasDietaryRestrictions,
                  onChanged: _isUnderage ? null : (val) => setState(() => hasDietaryRestrictions = val!),
                ),
                const Text('Yes'),
                Checkbox(
                  value: !hasDietaryRestrictions,
                  onChanged: _isUnderage ? null : (val) => setState(() => hasDietaryRestrictions = !val!),
                ),
                const Text('No'),
              ],
            ),
            if (hasDietaryRestrictions) ...[
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              const Text('Please select your dietary restriction(s):'),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
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
                    label: Text(restriction),
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
                  );
                }).toList(),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Wrap(
                spacing: 8.0,
                children: [
                  ActionChip(
                    label: const Text('Other...'),
                    onPressed: _isUnderage ? null : _showCustomRestrictionDialog,
                    avatar: const Icon(Icons.add),
                  ),
                  if (selectedDietaryRestrictions.isNotEmpty)
                    ActionChip(
                      label: const Text('Clear All'),
                      onPressed: _isUnderage ? null : () {
                        setState(() {
                          selectedDietaryRestrictions.clear();
                        });
                      },
                      backgroundColor: Colors.red[100],
                      avatar: const Icon(Icons.clear, color: Colors.red),
                    ),
                ],
              ),
              if (selectedDietaryRestrictions.isNotEmpty) ...[
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                const Text('Selected Restrictions:'),
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                Wrap(
                  spacing: 8.0,
                  children: selectedDietaryRestrictions.map((restriction) {
                    return Chip(
                      label: Text(restriction),
                      onDeleted: _isUnderage ? null : () {
                        setState(() {
                          selectedDietaryRestrictions.remove(restriction);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (selectedDietaryRestrictions.isEmpty && hasDietaryRestrictions)
                const Text(
                  'Please select at least one dietary restriction',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTermsPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 4: Terms and Conditions',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: agreeToTerms,
                  onChanged: _isUnderage ? null : (val) => setState(() => agreeToTerms = val!),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _isUnderage ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'terms and conditions',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      maxLines: null,
                      softWrap: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
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
                  child: const Text('Previous'),
                )
              else
                const SizedBox(width: 60),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.yellow[300] : Colors.grey,
                  ),
                )),
              ),
              if (_currentPage < 3)
                ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[300],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Next'),
                )
              else
                ElevatedButton(
                  onPressed: (_isUnderage || _isLoading || !agreeToTerms) ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUnderage ? Colors.grey : Colors.yellow[300],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text('REGISTER'),
                ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Already have an account? "),
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
                  'Login',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0df),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95),
              child: Card(
                elevation: 8,
                shadowColor: Colors.grey,
                child: Padding(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'HealthTingi',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: PageView(
                          controller: _pageController,
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
            ),
          ),
        ),
      ),
    );
  }
}