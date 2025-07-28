import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for the utf8.encode method
import 'login.dart';
import '../information/terms_and_cond.dart';
import '../database/db_helper.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  bool hasDietaryRestrictions = false;
  String selectedDietaryRestriction = '';
  bool agreeToTerms = false;
  bool _isLoading = false;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    // Clear all controllers to prevent memory leaks
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Password hashing function
  String _hashPassword(String password) {
    var bytes = utf8.encode(password); // Convert password to bytes
    var digest = sha256.convert(bytes); // Create SHA-256 hash
    return digest.toString(); // Return the hashed password
  }

  // Email validation
  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Password strength validation
  bool _validatePasswordStrength(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) && // At least one uppercase
        RegExp(r'[a-z]').hasMatch(password) && // At least one lowercase
        RegExp(r'[0-9]').hasMatch(password); // At least one number
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
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

      if (!_validatePasswordStrength(passwordController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 8 characters long and contain uppercase, lowercase, and numbers.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Check if email or username already exists
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

        // Register the user with hashed password
        final user = {
          'firstName': _sanitizeInput(firstNameController.text),
          'middleName': _sanitizeInput(middleNameController.text),
          'lastName': _sanitizeInput(lastNameController.text),
          'emailAddress': _sanitizeInput(emailController.text),
          'username': _sanitizeInput(usernameController.text),
          'password': _hashPassword(passwordController.text), // Hashing the password
          'hasDietaryRestriction': hasDietaryRestrictions ? 1 : 0,
          'dietaryRestriction': hasDietaryRestrictions ? _sanitizeInput(selectedDietaryRestriction) : null,
          'favorites': null,
          'age': null,
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
  }

  // Basic input sanitization
  String _sanitizeInput(String input) {
    return input
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll(';', '');
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isObscure = false, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0df),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            shadowColor: Colors.grey,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'HealthTingi',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(firstNameController, 'First Name'),
                    const SizedBox(height: 8),
                    _buildTextField(middleNameController, 'Middle Name'),
                    const SizedBox(height: 8),
                    _buildTextField(lastNameController, 'Last Name'),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    _buildTextField(
                      passwordController, 
                      'Password', 
                      isObscure: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (!_validatePasswordStrength(value)) {
                          return 'Must be 8+ chars with uppercase, lowercase & number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 12),
                    const Text('Do you have any Dietary Restrictions?'),
                    Row(
                      children: [
                        Checkbox(
                          value: hasDietaryRestrictions,
                          onChanged: (val) => setState(() => hasDietaryRestrictions = val!),
                        ),
                        const Text('Yes'),
                        Checkbox(
                          value: !hasDietaryRestrictions,
                          onChanged: (val) => setState(() => hasDietaryRestrictions = !val!),
                        ),
                        const Text('No'),
                      ],
                    ),

                    if (hasDietaryRestrictions) ...[
                      const SizedBox(height: 8),
                      const Text('Please select your dietary restriction:'),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select one'),
                        items: [
                          'Vegan',
                          'Vegetarian',
                          'Gluten-Free',
                          'Lactose Intolerant',
                        ].map((restriction) {
                          return DropdownMenuItem<String>(
                            value: restriction,
                            child: Text(restriction),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedDietaryRestriction = val!),
                        validator: (value) {
                          if (hasDietaryRestrictions && (value == null || value.isEmpty)) {
                            return 'Please select a dietary restriction';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: agreeToTerms,
                          onChanged: (val) => setState(() => agreeToTerms = val!),
                        ),
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
                              );
                            },
                            child: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'terms and conditions',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('REGISTER'),
                    ),

                    const SizedBox(height: 16),
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
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
