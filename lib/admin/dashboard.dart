import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../database/db_helper.dart';
import 'ingredients.dart';
import 'meals.dart';
import 'users.dart';
import '../pages/navigation.dart'; // Import the navigation drawer

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
  
  // New data for charts
  List<Map<String, dynamic>> userGrowthData = [];
  List<Map<String, dynamic>> topIngredientsData = [];
  List<Map<String, dynamic>> monthlyUserData = [];

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

    // Load chart data
    await _loadChartData(db);

    setState(() {});
  }

  Future<void> _loadChartData(sqflite.Database db) async {
    // User growth over last 6 months
    final monthlyResult = await db.rawQuery('''
      SELECT strftime('%Y-%m', createdAt) as month, 
             COUNT(*) as count
      FROM users 
      WHERE createdAt >= date('now', '-6 months')
      GROUP BY strftime('%Y-%m', createdAt)
      ORDER BY month
    ''');
    
    monthlyUserData = monthlyResult.map((row) {
      return {
        'month': row['month'] as String,
        'count': row['count'] as int,
      };
    }).toList();

    // Top 5 most used ingredients
    final topIngredientsResult = await db.rawQuery('''
      SELECT i.ingredientName, COUNT(mi.ingredientID) as usageCount 
      FROM ingredients i 
      LEFT JOIN meal_ingredients mi ON i.ingredientID = mi.ingredientID 
      GROUP BY i.ingredientID 
      ORDER BY usageCount DESC 
      LIMIT 5
    ''');
    
    topIngredientsData = topIngredientsResult.map((row) {
      return {
        'name': row['ingredientName'] as String,
        'count': row['usageCount'] as int,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Color(0xFF184E77),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF184E77)),
      ),
      drawer: NavigationDrawerWidget(userId: widget.userId),
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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Card(
                    elevation: 10,
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $adminName!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF184E77),
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'User ID: ${widget.userId}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Quick Stats Section – NOW CLICKABLE
                  Text(
                    'Quick Stats',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStatButton(
                          title: 'Total Users',
                          value: totalUsersValue,
                          icon: Icons.people,
                          color: Colors.green,
                          onTap: () => _showStatDetail(
                            context,
                            title: 'Total Users',
                            description: 'The total number of registered users in the system.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _QuickStatButton(
                          title: 'Total Meals',
                          value: totalMealsValue,
                          icon: Icons.restaurant,
                          color: Colors.green,
                          onTap: () => _showStatDetail(
                            context,
                            title: 'Total Meals',
                            description: 'The total number of meals created by all users.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStatButton(
                          title: 'Ingredients',
                          value: ingredientsValue,
                          icon: Icons.kitchen,
                          color: Colors.orange,
                          onTap: () => _showStatDetail(
                            context,
                            title: 'Ingredients',
                            description: 'The total number of unique ingredients stored in the database.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _QuickStatButton(
                          title: 'Active Today',
                          value: activeTodayValue,
                          icon: Icons.trending_up,
                          color: Colors.purple,
                          onTap: () => _showStatDetail(
                            context,
                            title: 'Active Today',
                            description: 'Users who signed up today (proxy for daily activity).',
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Management Sections
                  Text(
                    'Management',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.0,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ManagementCard(
                        title: 'Users',
                        icon: Icons.people_outline,
                        color: Colors.white.withOpacity(0.9),
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
                        color: Colors.white.withOpacity(0.9),
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
                        color: Colors.white.withOpacity(0.9),
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
                        color: Colors.white.withOpacity(0.9),
                        onTap: () {
                          _showAnalyticsDialog(context);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Analytics Charts Section
                  Text(
                    'Analytics & Insights',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // User Growth Chart
                  Card(
                    elevation: 8,
                    color: Colors.white.withOpacity(0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.trending_up, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'User Growth (Last 6 Months)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF184E77),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Container(
                            height: 180, // Increased height to accommodate text
                            child: monthlyUserData.isEmpty
                                ? const Center(child: CircularProgressIndicator())
                                : _buildUserGrowthChart(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Top Ingredients Chart
                  Card(
                    elevation: 8,
                    color: Colors.white.withOpacity(0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.kitchen, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Top 5 Most Used Ingredients',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF184E77),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Container(
                            height: 220, // Increased height for better spacing
                            child: topIngredientsData.isEmpty
                                ? const Center(child: CircularProgressIndicator())
                                : _buildIngredientsChart(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // NEW: Detail dialog for Quick Stats
  // ------------------------------------------------------------
  void _showStatDetail(BuildContext context, {required String title, required String description}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF184E77))),
        content: Text(description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    if (monthlyUserData.isEmpty) return const Center(child: Text('No data available'));

    int maxCount = monthlyUserData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: monthlyUserData.length,
      itemBuilder: (context, index) {
        final data = monthlyUserData[index];
        final month = data['month'] as String;
        final count = data['count'] as int;
        final height = (count / maxCount) * 100; // Reduced max height for text space

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12), // Increased margin
          width: 50, // Fixed width for better spacing
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 10, // Smaller font
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: height,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF76C893), Color(0xFF184E77)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 32, // Fixed height for month text
                child: Text(
                  _formatMonth(month),
                  style: const TextStyle(
                    fontSize: 10, // Smaller font
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIngredientsChart() {
    return ListView.builder(
      itemCount: topIngredientsData.length,
      physics: const BouncingScrollPhysics(), // Better scrolling
      itemBuilder: (context, index) {
        final data = topIngredientsData[index];
        final name = data['name'] as String;
        final count = data['count'] as int;
        
        int maxCount = topIngredientsData.isNotEmpty 
            ? topIngredientsData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b)
            : 1;

        double percentage = maxCount > 0 ? (count / maxCount) : 0;
        double availableWidth = MediaQuery.of(context).size.width - 120; // Account for padding and margins

        return Container(
          margin: const EdgeInsets.only(bottom: 16), // Increased margin
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count uses',
                    style: const TextStyle(
                      fontSize: 12, 
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 20,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[300],
                ),
                child: Stack(
                  children: [
                    // Background bar
                    Container(
                      width: availableWidth * percentage,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // Percentage text
                    if (percentage > 0.3) // Only show text if bar is wide enough
                      Positioned(
                        left: 8,
                        top: 2,
                        child: Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMonth(String month) {
    final parts = month.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final monthNum = int.tryParse(parts[1]);
      if (monthNum != null) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[monthNum - 1]} ${year.substring(2)}';
      }
    }
    return month;
  }
  
  void _showAnalyticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: Colors.white.withOpacity(0.95),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 400, // Limit height to prevent overflow
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Analytics Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF184E77),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
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
                              'Activity Chart Placeholder\n(Weekly User Activity)',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF184E77),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// NEW: Clickable Quick Stat Card
// -----------------------------------------------------------------
class _QuickStatButton extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickStatButton({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      color: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF184E77),
                        ),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// Keep the rest of your widgets exactly as they were
// -----------------------------------------------------------------
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
      elevation: 10,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.black87), // Slightly smaller icon
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16, // Slightly smaller font
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}