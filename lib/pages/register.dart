import 'package:flutter/material.dart';
import 'login.dart';
import '../information/termsAndCond.dart';

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

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleInitialController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    middleInitialController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() {
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

      // Registration logic goes here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registering user...')),
      );
    }
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isObscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
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
                    _buildTextField(middleInitialController, 'Middle Initial'),
                    const SizedBox(height: 8),
                    _buildTextField(lastNameController, 'Last Name'),
                    const SizedBox(height: 8),
                    _buildTextField(usernameController, 'Username'),
                    const SizedBox(height: 8),
                    _buildTextField(emailController, 'Email Address'),

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
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildTextField(passwordController, 'Password', isObscure: true),
                    const SizedBox(height: 8),
                    _buildTextField(confirmPasswordController, 'Confirm Password', isObscure: true),
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
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('REGISTER'),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? "),
                        GestureDetector(
                          onTap: () {
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
