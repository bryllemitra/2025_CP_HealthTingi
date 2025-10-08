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
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(
            fontFamily: 'PixelifySans',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFF66),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and Filter
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('All Users'),
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
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Users List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddUserDialog(context);
        },
        backgroundColor: const Color(0xFFFFFF66),
        child: const Icon(Icons.person_add, color: Colors.black),
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
        title: const Text('Add New User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: userType,
                items: ['Regular', 'Admin'].map((String value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  userType = value;
                },
                decoration: const InputDecoration(labelText: 'User Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
              backgroundColor: const Color(0xFFFFFF66),
            ),
            child: const Text('Add User', style: TextStyle(color: Colors.black)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: type == 'Admin' ? Colors.red : Colors.blue,
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            Text('Joined: $joinDate'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Active' ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit User'),
            onTap: () {
              Navigator.pop(context);
              _showEditUserDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete User'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('View Details'),
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
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: userType,
                items: ['Regular', 'Admin'].map((String value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  userType = value;
                },
                decoration: const InputDecoration(labelText: 'User Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
              backgroundColor: const Color(0xFFFFFF66),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['firstName']} ${user['lastName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
        title: Text('User Details: ${user['firstName']} ${user['lastName']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${user['firstName']} ${user['lastName']}'),
              Text('Email: ${user['email']}'),
              Text('Username: ${user['username']}'),
              Text('Type: ${user['isAdmin'] == 1 ? 'Admin' : 'Regular'}'),
              Text('Join Date: ${user['createdAt']?.substring(0, 10) ?? 'Unknown'}'),
              Text('Status: ${user['isActive'] == 1 ? 'Active' : 'Inactive'}'),
              const SizedBox(height: 16),
              const Text('Dietary Restrictions:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(user['dietaryRestrictions'] ?? 'None'),
              const SizedBox(height: 16),
              const Text('Favorite Meals:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...favoriteMeals.map((meal) => Text('• ${meal['mealName']}')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}