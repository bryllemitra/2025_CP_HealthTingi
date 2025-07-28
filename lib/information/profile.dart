import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final dbHelper = DatabaseHelper();
  Map<String, dynamic> userData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // In a real app, you would get the current user's ID
    final user = await dbHelper.getUserById(1); // Replace with actual user ID
    setState(() {
      userData = user ?? {};
      isLoading = false;
    });
  }

  String getInitials() {
    final firstName = userData['firstName']?.toString() ?? '';
    final lastName = userData['lastName']?.toString() ?? '';
    if (firstName.isEmpty && lastName.isEmpty) return '?';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  }

  Future<void> _updateUserData(Map<String, dynamic> updates) async {
    setState(() => isLoading = true);
    await dbHelper.updateUser(1, updates); // Replace with actual user ID
    await _loadUserData();
  }

  void _showEditDialog(BuildContext context, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new $field'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _updateUserData({field.toLowerCase(): controller.text});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
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
                // Navigate to saved recipes
              },
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 8),
            _editableInfoTile(
              context,
              title: 'First Name',
              value: userData['firstName']?.toString() ?? '',
              field: 'firstName',
            ),
            _editableInfoTile(
              context,
              title: 'Middle Name',
              value: userData['middleName']?.toString() ?? '',
              field: 'middleName',
            ),
            _editableInfoTile(
              context,
              title: 'Last Name',
              value: userData['lastName']?.toString() ?? '',
              field: 'lastName',
            ),
            _editableInfoTile(
              context,
              title: 'Username',
              value: userData['username']?.toString() ?? '',
              field: 'username',
            ),
            _editableInfoTile(
              context,
              title: 'Email',
              value: userData['emailAddress']?.toString() ?? '',
              field: 'emailAddress',
            ),
            _editableInfoTile(
              context,
              title: 'Age',
              value: userData['age']?.toString() ?? '',
              field: 'age',
            ),
            _editableInfoTile(
              context,
              title: 'Gender',
              value: userData['gender']?.toString() ?? '',
              field: 'gender',
            ),
            _editableInfoTile(
              context,
              title: 'Street',
              value: userData['street']?.toString() ?? '',
              field: 'street',
            ),
            _editableInfoTile(
              context,
              title: 'Barangay',
              value: userData['barangay']?.toString() ?? '',
              field: 'barangay',
            ),
            _editableInfoTile(
              context,
              title: 'City',
              value: userData['city']?.toString() ?? '',
              field: 'city',
            ),
            _editableInfoTile(
              context,
              title: 'Nationality',
              value: userData['nationality']?.toString() ?? '',
              field: 'nationality',
            ),
            _infoTile(
              title: 'Dietary Restrictions',
              value: userData['dietaryRestriction']?.toString() ?? 'None',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Perform bulk update if needed
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellowAccent,
                foregroundColor: Colors.black,
                elevation: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
            onPressed: () => _showEditDialog(context, title, value),
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