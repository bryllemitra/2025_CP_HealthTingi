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
    final user = await dbHelper.getUserById(widget.userId); // Use the actual user ID
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
      // Add dietary restrictions to updates if they were modified
      if (hasDietaryRestrictions != (userData['hasDietaryRestriction'] == 1)) {
        _editedValues['hasDietaryRestriction'] = hasDietaryRestrictions ? 1 : 0;
      }
      
      if (hasDietaryRestrictions) {
        _editedValues['dietaryRestriction'] = selectedDietaryRestrictions.join(', ');
      } else {
        _editedValues['dietaryRestriction'] = null;
      }

      await dbHelper.updateUser(widget.userId, _editedValues); // Use the actual user ID
      await _loadUserData();
      _editedValues.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
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
        title: Text('Edit ${field.replaceAll('_', ' ')}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new ${field.replaceAll('_', ' ')}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _handleFieldChange(field, controller.text);
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                    const Text(
                      'Dietary Restrictions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: hasDietaryRestrictions,
                          onChanged: (val) => setState(() => hasDietaryRestrictions = val!),
                        ),
                        const Expanded(
                          child: Text(
                            'I have dietary restrictions',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    if (hasDietaryRestrictions) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select your restrictions:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      // Use Wrap instead of GridView for better responsiveness
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: allRestrictions.map((restriction) {
                          return FilterChip(
                            label: Text(restriction),
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
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Other restrictions:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _otherRestrictionController,
                              decoration: const InputDecoration(
                                hintText: 'Enter other restriction',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              if (_otherRestrictionController.text.trim().isNotEmpty) {
                                setState(() {
                                  selectedDietaryRestrictions.add(_otherRestrictionController.text.trim());
                                  _otherRestrictionController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      if (selectedDietaryRestrictions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Selected restrictions:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: selectedDietaryRestrictions.map((r) => Chip(
                            label: Text(r),
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
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
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
                          child: const Text('Save'),
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
      return const Scaffold(
        backgroundColor: Color(0xFFF3F2DF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2DF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F2DF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Account\nInformation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.yellow,
                child: Text(
                  getInitials(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            _menuTile(
              title: 'Saved Recipes',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesPage(userId: widget.userId)));
              },
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 8),
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
            GestureDetector(
              onTap: _showDietaryRestrictionsDialog,
              child: _infoTile(
                title: 'Dietary Restrictions',
                value: _editedValues.containsKey('dietaryRestriction')
                    ? (_editedValues['dietaryRestriction'] ?? 'None')
                    : (userData['dietaryRestriction']?.toString() ?? 'None'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellowAccent,
                foregroundColor: Colors.black,
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                textStyle: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Update Profile'),
            ),
            const SizedBox(height: 30),
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
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 2),
            blurRadius: 4,
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
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'Not set' : value,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _showEditDialog(context, field, value),
          )
        ],
      ),
    );
  }

  Widget _infoTile({required String title, required String value}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 2),
            blurRadius: 4,
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
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          const Icon(Icons.edit, size: 20),
        ],
      ),
    );
  }

  Widget _menuTile({required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}