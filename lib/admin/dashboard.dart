import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../database/db_helper.dart';
import 'ingredients.dart';
import 'meals.dart';
import 'users.dart';

class AdminDashboardPage extends StatefulWidget {
  final int userId;
  
  const AdminDashboardPage({super.key, required this.userId});
  
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late String adminName = 'Administrator';
  late String totalUsersValue = 'Loading...';
  late String totalMealsValue = 'Loading...';
  late String ingredientsValue = 'Loading...';
  late String activeTodayValue = 'Loading...';
  late String userGrowthValue = 'Loading...';
  late String popularMealValue = 'Loading...';
  late String mostUsedIngredientValue = 'Loading...';
  late String activeSessionsValue = 'N/A';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    // Get admin details
    final admin = await dbHelper.getUserById(widget.userId);
    if (admin != null) {
      adminName = '${admin['firstName']} ${admin['lastName']}';
    }

    // Total Users
    final users = await db.query('users');
    totalUsersValue = users.length.toString();

    // Total Meals
    final meals = await db.query('meals');
    totalMealsValue = meals.length.toString();

    // Total Ingredients
    final ingredients = await db.query('ingredients');
    ingredientsValue = ingredients.length.toString();

    // New Users Today (as proxy for Active Today, since no login tracking)
    final todayResult = await db.rawQuery(
      "SELECT COUNT(*) FROM users WHERE strftime('%Y-%m-%d', createdAt) = strftime('%Y-%m-%d', 'now')"
    );
    activeTodayValue = (sqflite.Sqflite.firstIntValue(todayResult) ?? 0).toString();

    // User Growth
    final thisMonthResult = await db.rawQuery(
      "SELECT COUNT(*) FROM users WHERE strftime('%Y-%m', createdAt) = strftime('%Y-%m', 'now')"
    );
    int thisMonth = sqflite.Sqflite.firstIntValue(thisMonthResult) ?? 0;

    final lastMonthResult = await db.rawQuery(
      "SELECT COUNT(*) FROM users WHERE strftime('%Y-%m', createdAt) = strftime('%Y-%m', 'now', '-1 month')"
    );
    int lastMonth = sqflite.Sqflite.firstIntValue(lastMonthResult) ?? 0;

    double growth = lastMonth == 0 
        ? (thisMonth > 0 ? 100.0 : 0.0) 
        : ((thisMonth - lastMonth) / lastMonth) * 100;
    userGrowthValue = '${growth > 0 ? '+' : ''}${growth.toStringAsFixed(0)}% this month';

    // Most Used Ingredient
    final mostIngResult = await db.rawQuery(
      '''
      SELECT i.ingredientName, COUNT(mi.ingredientID) as count 
      FROM ingredients i 
      LEFT JOIN meal_ingredients mi ON i.ingredientID = mi.ingredientID 
      GROUP BY i.ingredientID 
      ORDER BY count DESC 
      LIMIT 1
      '''
    );
    mostUsedIngredientValue = mostIngResult.isNotEmpty 
        ? mostIngResult.first['ingredientName'] as String? ?? 'None' 
        : 'None';

    // Popular Meal (based on favorites count across users)
    final allUsers = await db.query('users');
    Map<int, int> mealCounts = {};
    for (var user in allUsers) {
      String? favorites = user['favorites'] as String?;
      if (favorites != null && favorites.isNotEmpty) {
        for (var idStr in favorites.split(',')) {
          int? id = int.tryParse(idStr.trim());
          if (id != null) {
            mealCounts.update(id, (value) => value + 1, ifAbsent: () => 1);
          }
        }
      }
    }
    if (mealCounts.isNotEmpty) {
      final popularId = mealCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final popularMeal = await dbHelper.getMealById(popularId);
      popularMealValue = popularMeal?['mealName'] as String? ?? 'Unknown';
    } else {
      popularMealValue = 'None';
    }

    // Active Sessions (not tracked, so N/A)
    activeSessionsValue = 'N/A';

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1DC),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontFamily: 'PixelifySans',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFF66),
        foregroundColor: Colors.black,
        elevation: 5,
        shadowColor: Colors.grey[700],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Card(
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $adminName!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User ID: ${widget.userId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Quick Stats Section
              Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Users',
                      value: totalUsersValue,
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'Total Meals',
                      value: totalMealsValue,
                      icon: Icons.restaurant,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Ingredients',
                      value: ingredientsValue,
                      icon: Icons.kitchen,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'Active Today',
                      value: activeTodayValue,
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Management Sections
              Text(
                'Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _ManagementCard(
                      title: 'Users',
                      icon: Icons.people_outline,
                      color: const Color(0xFFFFFF66),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminUsersPage(userId: widget.userId),
                          ),
                        );
                      },
                    ),
                    _ManagementCard(
                      title: 'Meals',
                      icon: Icons.restaurant_menu,
                      color: const Color(0xFFFFFF66),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminMealsPage(userId: widget.userId),
                          ),
                        );
                      },
                    ),
                    _ManagementCard(
                      title: 'Ingredients',
                      icon: Icons.kitchen_outlined,
                      color: const Color(0xFFFFFF66),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminIngredientsPage(userId: widget.userId),
                          ),
                        );
                      },
                    ),
                    _ManagementCard(
                      title: 'Analytics',
                      icon: Icons.analytics_outlined,
                      color: const Color(0xFFFFFF66),
                      onTap: () {
                        _showAnalyticsDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showAnalyticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics Overview'),
        content: SizedBox(
          height: 300,
          child: Column(
            children: [
              _AnalyticsItem(
                title: 'User Growth',
                value: userGrowthValue,
                color: Colors.green,
              ),
              _AnalyticsItem(
                title: 'Popular Meal',
                value: popularMealValue,
                color: Colors.blue,
              ),
              _AnalyticsItem(
                title: 'Most Used Ingredient',
                value: mostUsedIngredientValue,
                color: Colors.orange,
              ),
              _AnalyticsItem(
                title: 'Active Sessions',
                value: activeSessionsValue,
                color: Colors.purple,
              ),
              const SizedBox(height: 20),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    '📈 Activity Chart Placeholder\n(Weekly User Activity)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.black),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _AnalyticsItem({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}