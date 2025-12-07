import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../searchMeals/favorites.dart';

class ProfilePage extends StatefulWidget {
  final int userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final dbHelper = DatabaseHelper();
  Map<String, dynamic> userData = {};
  bool isLoading = true;
  final Map<String, dynamic> _editedValues = {};
  final TextEditingController _otherRestrictionController = TextEditingController();
  List<String> selectedDietaryRestrictions = [];
  bool hasDietaryRestrictions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await dbHelper.getUserById(widget.userId);
    setState(() {
      userData = user ?? {};
      hasDietaryRestrictions = user?['hasDietaryRestriction'] == 1;
      selectedDietaryRestrictions = user?['dietaryRestriction']?.toString().split(', ') ?? [];
      isLoading = false;
    });
  }

  String getInitials() {
    final firstName = userData['firstName']?.toString() ?? '';
    final lastName = userData['lastName']?.toString() ?? '';
    if (firstName.isEmpty && lastName.isEmpty) return '?';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  }

  void _handleFieldChange(String field, dynamic value) {
    setState(() {
      _editedValues[field] = value;
    });
  }

  Future<void> _updateProfile() async {
    if (_editedValues.isEmpty) return;

    setState(() => isLoading = true);
    try {
      if (hasDietaryRestrictions != (userData['hasDietaryRestriction'] == 1)) {
        _editedValues['hasDietaryRestriction'] = hasDietaryRestrictions ? 1 : 0;
      }
      
      if (hasDietaryRestrictions) {
        _editedValues['dietaryRestriction'] = selectedDietaryRestrictions.join(', ');
      } else {
        _editedValues['dietaryRestriction'] = null;
      }

      await dbHelper.updateUser(widget.userId, _editedValues);
      await _loadUserData();
      _editedValues.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!', style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Color(0xFF76C893),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: ${e.toString()}', style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _showEditDialog(BuildContext context, String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit ${field.replaceAll('_', ' ')}',
          style: TextStyle(
            fontFamily: 'Exo', // Updated to Exo
            color: Color(0xFF184E77),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(fontFamily: 'Poppins'), // Updated
          decoration: InputDecoration(
            hintText: 'Enter new ${field.replaceAll('_', ' ')}',
            hintStyle: TextStyle(fontFamily: 'Poppins'), // Updated
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF184E77), fontFamily: 'Poppins'), // Updated
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF184E77),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _handleFieldChange(field, controller.text);
              });
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Updated
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBirthdayPickerDialog() async {
    final DateTime initialDate = userData['birthday'] != null 
        ? DateTime.parse(userData['birthday']) 
        : DateTime.now().subtract(const Duration(days: 365 * 20));
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Color(0xFF184E77),
            colorScheme: ColorScheme.light(primary: Color(0xFF184E77)),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null) {
      setState(() {
        _handleFieldChange('birthday', pickedDate.toIso8601String().split('T')[0]);
      });
    }
  }

  Future<void> _showDietaryRestrictionsDialog() async {
    final List<String> allRestrictions = [
      'Vegan',
      'Vegetarian',
      'Gluten-Free',
      'Lactose Intolerant',
      'Halal',
      'Kosher',
      'Nut Allergy',
      'Shellfish Allergy',
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dietary Restrictions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Exo', // Updated to Exo
                        color: Color(0xFF184E77),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: hasDietaryRestrictions,
                          onChanged: (val) => setState(() => hasDietaryRestrictions = val!),
                          activeColor: Color(0xFF184E77),
                        ),
                        const Expanded(
                          child: Text(
                            'I have dietary restrictions',
                            style: TextStyle(fontSize: 16, fontFamily: 'Poppins'), // Updated
                          ),
                        ),
                      ],
                    ),
                    if (hasDietaryRestrictions) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select your restrictions:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins'), // Updated
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: allRestrictions.map((restriction) {
                          return FilterChip(
                            label: Text(restriction, style: TextStyle(fontFamily: 'Poppins')), // Updated
                            selected: selectedDietaryRestrictions.contains(restriction),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedDietaryRestrictions.add(restriction);
                                } else {
                                  selectedDietaryRestrictions.remove(restriction);
                                }
                              });
                            },
                            selectedColor: Color(0xFFB5E48C),
                            checkmarkColor: Colors.black,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Other restrictions:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins'), // Updated
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _otherRestrictionController,
                              style: TextStyle(fontFamily: 'Poppins'), // Updated
                              decoration: InputDecoration(
                                hintText: 'Enter other restriction',
                                hintStyle: TextStyle(fontFamily: 'Poppins'), // Updated
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF184E77),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                if (_otherRestrictionController.text.trim().isNotEmpty) {
                                  setState(() {
                                    selectedDietaryRestrictions.add(_otherRestrictionController.text.trim());
                                    _otherRestrictionController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selectedDietaryRestrictions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Selected restrictions:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins'), // Updated
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: selectedDietaryRestrictions.map((r) => Chip(
                            label: Text(r, style: TextStyle(fontFamily: 'Poppins')), // Updated
                            backgroundColor: Color(0xFFB5E48C),
                            deleteIconColor: Colors.black,
                            onDeleted: () {
                              setState(() => selectedDietaryRestrictions.remove(r));
                            },
                          )).toList(),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF184E77), fontFamily: 'Poppins'), // Updated
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF184E77),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _handleFieldChange('hasDietaryRestriction', hasDietaryRestrictions ? 1 : 0);
                              if (hasDietaryRestrictions) {
                                _handleFieldChange('dietaryRestriction', selectedDietaryRestrictions.join(', '));
                              } else {
                                _handleFieldChange('dietaryRestriction', null);
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Save',
                            style: TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Updated
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
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
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
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
        child: Column(
          children: [
            // Fixed App Bar - won't move when scrolling
            Container(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Account Information',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Exo', // Updated to Exo
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 48), // For balance
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Profile Avatar with glow effect
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Color(0xFFB5E48C),
                          child: Text(
                            getInitials(),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF184E77),
                              fontFamily: 'Exo', // Updated to Exo
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // User Name
                    Text(
                      '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
                      style: TextStyle(
                        fontFamily: 'Exo', // Updated to Exo
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Saved Recipes Card
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesPage(userId: widget.userId)));
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: Row(
                              children: [
                                Icon(Icons.favorite, color: Color(0xFF184E77)),
                                SizedBox(width: 12),
                                Text(
                                  'Saved Recipes',
                                  style: TextStyle(
                                    fontFamily: 'Poppins', // Updated to Poppins
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF184E77),
                                  ),
                                ),
                                Spacer(),
                                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF184E77)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Profile Information Cards
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontFamily: 'Exo', // Updated to Exo
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF184E77),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Personal Info Fields
                          _editableInfoTile(
                            context,
                            title: 'First Name',
                            value: _editedValues['firstName'] ?? userData['firstName']?.toString() ?? '',
                            field: 'firstName',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Middle Name',
                            value: _editedValues['middleName'] ?? userData['middleName']?.toString() ?? '',
                            field: 'middleName',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Last Name',
                            value: _editedValues['lastName'] ?? userData['lastName']?.toString() ?? '',
                            field: 'lastName',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Username',
                            value: _editedValues['username'] ?? userData['username']?.toString() ?? '',
                            field: 'username',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Email',
                            value: _editedValues['emailAddress'] ?? userData['emailAddress']?.toString() ?? '',
                            field: 'emailAddress',
                          ),
                          
                          // Birthday field
                          GestureDetector(
                            onTap: _showBirthdayPickerDialog,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Birthday',
                                            style: TextStyle(
                                              fontFamily: 'Poppins', // Updated to Poppins
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF184E77),
                                            )),
                                        SizedBox(height: 2),
                                        Text(
                                          _editedValues['birthday'] ?? userData['birthday']?.toString() ?? 'Not set',
                                          style: TextStyle(
                                            fontFamily: 'Poppins', // Updated to Poppins
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.calendar_today, size: 20, color: Color(0xFF184E77)),
                                ],
                              ),
                            ),
                          ),

                          _editableInfoTile(
                            context,
                            title: 'Age',
                            value: _editedValues['age'] ?? userData['age']?.toString() ?? '',
                            field: 'age',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Gender',
                            value: _editedValues['gender'] ?? userData['gender']?.toString() ?? '',
                            field: 'gender',
                          ),
                          
                          SizedBox(height: 16),
                          Text(
                            'Address Information',
                            style: TextStyle(
                              fontFamily: 'Exo', // Updated to Exo
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF184E77),
                            ),
                          ),
                          SizedBox(height: 16),

                          _editableInfoTile(
                            context,
                            title: 'Street',
                            value: _editedValues['street'] ?? userData['street']?.toString() ?? '',
                            field: 'street',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Barangay',
                            value: _editedValues['barangay'] ?? userData['barangay']?.toString() ?? '',
                            field: 'barangay',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'City',
                            value: _editedValues['city'] ?? userData['city']?.toString() ?? '',
                            field: 'city',
                          ),
                          _editableInfoTile(
                            context,
                            title: 'Nationality',
                            value: _editedValues['nationality'] ?? userData['nationality']?.toString() ?? '',
                            field: 'nationality',
                          ),

                          // Dietary Restrictions
                          GestureDetector(
                            onTap: _showDietaryRestrictionsDialog,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Dietary Restrictions',
                                            style: TextStyle(
                                              fontFamily: 'Poppins', // Updated to Poppins
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF184E77),
                                            )),
                                        SizedBox(height: 2),
                                        Text(
                                          _editedValues.containsKey('dietaryRestriction')
                                              ? (_editedValues['dietaryRestriction'] ?? 'None')
                                              : (userData['dietaryRestriction']?.toString() ?? 'None'),
                                          style: TextStyle(
                                            fontFamily: 'Poppins', // Updated to Poppins
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF184E77)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Update Profile Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF184E77),
                          elevation: 10,
                          shadowColor: Colors.greenAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _updateProfile,
                        child: Text(
                          'Update Profile',
                          style: TextStyle(
                            fontFamily: 'Poppins', // Updated to Poppins
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Subtle Footer
                    const Text(
                      'Keep your information updated',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.2,
                        fontFamily: 'Poppins', // Updated to Poppins
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableInfoTile(
    BuildContext context, {
    required String title,
    required String value,
    required String field,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(1, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontFamily: 'Poppins', // Updated to Poppins
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF184E77),
                    )),
                SizedBox(height: 2),
                Text(value.isEmpty ? 'Not set' : value,
                    style: TextStyle(
                      fontFamily: 'Poppins', // Updated to Poppins
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF184E77),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.edit, size: 16, color: Colors.white),
              onPressed: () => _showEditDialog(context, field, value),
            ),
          )
        ],
      ),
    );
  }
}