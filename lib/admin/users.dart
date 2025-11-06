import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AdminUsersPage extends StatefulWidget {
  final int userId;

  const AdminUsersPage({super.key, required this.userId});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'All Users';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper();
    final users = await dbHelper.getAllUsers();

    setState(() {
      _users = users;
      _filteredUsers = users;
      _isLoading = false;
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = '${user['firstName']} ${user['lastName']}'.toLowerCase();
        final email = user['email']?.toLowerCase() ?? '';
        final matchesSearch = name.contains(query) || email.contains(query);
        if (_selectedFilter == 'All Users') return matchesSearch;
        if (_selectedFilter == 'Admins') {
          return matchesSearch && (user['isAdmin'] == 1 || user['role']?.toLowerCase() == 'admin');
        }
        if (_selectedFilter == 'Regular') {
          return matchesSearch && (user['isAdmin'] == 0 || user['role']?.toLowerCase() != 'admin');
        }
        return false;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                          'User Management',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: Colors.black54),
                      suffixIcon: Icon(Icons.search, color: Color(0xFF184E77)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Users'),
                        labelStyle: const TextStyle(color: Color(0xFF184E77)),
                        selectedColor: const Color(0xFFB5E48C),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'All Users';
                            _filterUsers();
                          });
                        },
                        selected: _selectedFilter == 'All Users',
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Admins'),
                        labelStyle: const TextStyle(color: Color(0xFF184E77)),
                        selectedColor: const Color(0xFFB5E48C),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'Admins';
                            _filterUsers();
                          });
                        },
                        selected: _selectedFilter == 'Admins',
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Regular'),
                        labelStyle: const TextStyle(color: Color(0xFF184E77)),
                        selectedColor: const Color(0xFFB5E48C),
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = 'Regular';
                            _filterUsers();
                          });
                        },
                        selected: _selectedFilter == 'Regular',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refreshUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _UserCard(
                              user: user,
                              onRefresh: _refreshUsers,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddUserDialog(context);
        },
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.person_add, color: Color(0xFF76C893)),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final usernameController = TextEditingController();
    String? userType = 'Regular';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add New User',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFF184E77),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: userType,
                decoration: InputDecoration(
                  labelText: 'User Type',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: ['Regular', 'Admin'].map((String value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  userType = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF184E77))),
          ),
          ElevatedButton(
            onPressed: () async {
              final nameParts = nameController.text.trim().split(' ');
              final firstName = nameParts.isNotEmpty ? nameParts.first : '';
              final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
              final user = {
                'firstName': firstName,
                'lastName': lastName,
                'email': emailController.text,
                'username': usernameController.text,
                'isAdmin': userType == 'Admin' ? 1 : 0,
                'role': userType,
                'createdAt': DateTime.now().toIso8601String(),
              };
              final dbHelper = DatabaseHelper();
              await dbHelper.insertUser(user);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User added successfully')),
              );
              _refreshUsers();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB5E48C),
              foregroundColor: const Color(0xFF184E77),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRefresh;

  const _UserCard({
    required this.user,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${user['firstName']} ${user['lastName']}';
    final status = user['isActive'] == 1 ? 'Active' : 'Inactive';
    final type = user['isAdmin'] == 1 ? 'Admin' : 'Regular';
    final joinDate = user['createdAt']?.substring(0, 10) ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: type == 'Admin' ? const Color(0xFF184E77) : const Color(0xFFB5E48C),
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Color(0xFF184E77),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] ?? '',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              'Joined: $joinDate',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'Active' ? const Color(0xFFB5E48C) : Colors.grey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Color(0xFF184E77), fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF184E77)),
              onPressed: () {
                _showUserOptions(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF184E77)),
            title: const Text('Edit User', style: TextStyle(color: Color(0xFF184E77))),
            onTap: () {
              Navigator.pop(context);
              _showEditUserDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete User', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility, color: Color(0xFF184E77)),
            title: const Text('View Details', style: TextStyle(color: Color(0xFF184E77))),
            onTap: () {
              Navigator.pop(context);
              _showUserDetails(context);
            },
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context) {
    final nameController = TextEditingController(text: '${user['firstName']} ${user['lastName']}');
    final emailController = TextEditingController(text: user['email']);
    final usernameController = TextEditingController(text: user['username']);
    String? userType = user['isAdmin'] == 1 ? 'Admin' : 'Regular';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit User',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFF184E77),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: userType,
                decoration: InputDecoration(
                  labelText: 'User Type',
                  labelStyle: const TextStyle(color: Color(0xFF184E77)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: ['Regular', 'Admin'].map((String value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  userType = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF184E77))),
          ),
          ElevatedButton(
            onPressed: () async {
              final nameParts = nameController.text.trim().split(' ');
              final firstName = nameParts.isNotEmpty ? nameParts.first : '';
              final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
              final updates = {
                'firstName': firstName,
                'lastName': lastName,
                'email': emailController.text,
                'username': usernameController.text,
                'isAdmin': userType == 'Admin' ? 1 : 0,
                'role': userType,
              };
              final dbHelper = DatabaseHelper();
              await dbHelper.updateUser(user['userID'], updates);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User updated successfully')),
              );
              onRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB5E48C),
              foregroundColor: const Color(0xFF184E77),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete User',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFF184E77),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('Are you sure you want to delete ${user['firstName']} ${user['lastName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF184E77))),
          ),
          TextButton(
            onPressed: () async {
              final dbHelper = DatabaseHelper();
              await dbHelper.deleteUser(user['userID']);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User deleted successfully')),
              );
              onRefresh();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDetails(BuildContext context) async {
    final dbHelper = DatabaseHelper();
    final favorites = user['favorites']?.toString().split(',') ?? [];
    final favoriteMeals = <Map<String, dynamic>>[];
    for (var mealId in favorites) {
      final id = int.tryParse(mealId.trim());
      if (id != null) {
        final meal = await dbHelper.getMealById(id);
        if (meal != null) favoriteMeals.add(meal);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'User Details: ${user['firstName']} ${user['lastName']}',
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFF184E77),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${user['firstName']} ${user['lastName']}', style: const TextStyle(color: Color(0xFF184E77))),
              Text('Email: ${user['email']}', style: const TextStyle(color: Color(0xFF184E77))),
              Text('Username: ${user['username']}', style: const TextStyle(color: Color(0xFF184E77))),
              Text('Type: ${user['isAdmin'] == 1 ? 'Admin' : 'Regular'}', style: const TextStyle(color: Color(0xFF184E77))),
              Text('Join Date: ${user['createdAt']?.substring(0, 10) ?? 'Unknown'}', style: const TextStyle(color: Color(0xFF184E77))),
              Text('Status: ${user['isActive'] == 1 ? 'Active' : 'Inactive'}', style: const TextStyle(color: Color(0xFF184E77))),
              const SizedBox(height: 16),
              const Text('Dietary Restrictions:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77))),
              Text(user['dietaryRestrictions'] ?? 'None', style: const TextStyle(color: Color(0xFF184E77))),
              const SizedBox(height: 16),
              const Text('Favorite Meals:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77))),
              ...favoriteMeals.map((meal) => Text('• ${meal['mealName']}', style: const TextStyle(color: Color(0xFF184E77)))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF184E77))),
          ),
        ],
      ),
    );
  }
}