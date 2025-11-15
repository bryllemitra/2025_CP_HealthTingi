import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'dart:math';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _currentVersion = 19; 

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'healthtingi.db');
    final db = await openDatabase(
      path,
      version: _currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDowngrade,
    );
    await loadSubstitutions(); // Load substitutions here to ensure ready after DB init
    _database = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create tables in proper order considering foreign key dependencies
    await _createIngredientsTable(db);
    await _createMealsTable(db);
    await _createMealIngredientsTable(db);
    await _createUsersTable(db);
    await _createFaqsTable(db);
    await _createAboutUsTable(db);
    // New tables for substitutions
    await db.execute('''
      CREATE TABLE unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_name TEXT NOT NULL UNIQUE,
        grams_per_unit REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE substitutions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_ingredient_id INTEGER NOT NULL,
        substitute_ingredient_id INTEGER NOT NULL,
        equivalence_ratio REAL NOT NULL DEFAULT 1.0,
        flavor_similarity REAL NOT NULL DEFAULT 0.5,
        notes TEXT,
        confidence TEXT DEFAULT 'medium',
        FOREIGN KEY (original_ingredient_id) REFERENCES ingredients(ingredientID),
        FOREIGN KEY (substitute_ingredient_id) REFERENCES ingredients(ingredientID)
      )
    ''');
    await db.execute('''
      CREATE TABLE meal_substitution_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        original_ingredient_id INTEGER NOT NULL,
        substitute_ingredient_id INTEGER NOT NULL,
        original_amount_g REAL NOT NULL,
        substitute_amount_g REAL NOT NULL,
        cost_delta REAL NOT NULL,
        calorie_delta REAL NOT NULL,
        substitution_date TEXT NOT NULL,
        FOREIGN KEY (meal_id) REFERENCES meals(mealID),
        FOREIGN KEY (user_id) REFERENCES users(userID)
      )
    ''');
    await db.execute('''
      CREATE TABLE customized_meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_meal_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        customized_name TEXT,
        original_ingredients TEXT NOT NULL,
        substituted_ingredients TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (original_meal_id) REFERENCES meals(mealID),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    await _insertAdminUser(db);
    await _insertInitialData(db);
    await _insertInitialFaqs(db);
    await _insertInitialAboutUs(db);
    //await _insertCompleteSubstitutionData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE meals ADD COLUMN availableFrom TEXT');
      await db.execute('ALTER TABLE meals ADD COLUMN availableTo TEXT');
    }
    if (oldVersion < 3) {
      await _createMealIngredientsTable(db);
      // Migrate existing data if needed
    }
    if (oldVersion < 4) {
      // Add picture columns if they don't exist
      try {
        await db.execute('ALTER TABLE ingredients ADD COLUMN ingredientPicture TEXT');
        await db.execute('ALTER TABLE meals ADD COLUMN mealPicture TEXT');
        // Update existing records with picture paths
        await _updateExistingRecordsWithPictures(db);
      } catch (e) {
        // Columns might already exist, ignore
      }
    }
     if (oldVersion < 6) {
    // Add this block to ensure new meals are inserted during upgrade
    await _insertIngredients(db);
    await _insertMeals(db);
    }
    if (oldVersion < 8) {
      // Clear old data and reload from JSON
      await db.delete('meal_ingredients');
      await db.delete('meals');
      await db.delete('ingredients');
      await _insertInitialData(db);
    }
    if (oldVersion < 10) {
      // Add isAdmin column to users table
      try {
        await db.execute('ALTER TABLE users ADD COLUMN isAdmin INTEGER DEFAULT 0');
        await _insertAdminUser(db);
      } catch (e) {
        // Column might already exist, ignore
      }
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE meals ADD COLUMN additionalPictures TEXT');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE ingredients ADD COLUMN additionalPictures TEXT');
    }
    if (oldVersion < 13) {
      await _createFaqsTable(db);
      await _createAboutUsTable(db);
      await _insertInitialFaqs(db);
      await _insertInitialAboutUs(db);
    }
    if (oldVersion < 15) {
      // Add new tables and fields for substitutions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS unit_conversions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_name TEXT NOT NULL UNIQUE,
          grams_per_unit REAL NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS substitutions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_ingredient_id INTEGER NOT NULL,
          substitute_ingredient_id INTEGER NOT NULL,
          equivalence_ratio REAL NOT NULL DEFAULT 1.0,
          flavor_similarity REAL NOT NULL DEFAULT 0.5,
          notes TEXT,
          confidence TEXT DEFAULT 'medium',
          FOREIGN KEY (original_ingredient_id) REFERENCES ingredients(ingredientID),
          FOREIGN KEY (substitute_ingredient_id) REFERENCES ingredients(ingredientID)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_substitution_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          meal_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          original_ingredient_id INTEGER NOT NULL,
          substitute_ingredient_id INTEGER NOT NULL,
          original_amount_g REAL NOT NULL,
          substitute_amount_g REAL NOT NULL,
          cost_delta REAL NOT NULL,
          calorie_delta REAL NOT NULL,
          substitution_date TEXT NOT NULL,
          FOREIGN KEY (meal_id) REFERENCES meals(mealID),
          FOREIGN KEY (user_id) REFERENCES users(userID)
        )
      ''');
      // Add new fields to ingredients
      try {
        await db.execute('ALTER TABLE ingredients ADD COLUMN price_text TEXT');
        await db.execute('ALTER TABLE ingredients ADD COLUMN unit TEXT');
        await db.execute('ALTER TABLE ingredients ADD COLUMN sodium_mg_per_100g REAL DEFAULT 0');
        await db.execute('ALTER TABLE ingredients ADD COLUMN protein_g_per_100g REAL DEFAULT 0');
        await db.execute('ALTER TABLE ingredients ADD COLUMN carbs_g_per_100g REAL DEFAULT 0');
        await db.execute('ALTER TABLE ingredients ADD COLUMN fat_g_per_100g REAL DEFAULT 0');
        await db.execute('ALTER TABLE ingredients ADD COLUMN unit_density_tbsp REAL DEFAULT 15');
        await db.execute('ALTER TABLE ingredients ADD COLUMN unit_density_tsp REAL DEFAULT 5');
        await db.execute('ALTER TABLE ingredients ADD COLUMN unit_density_cup REAL DEFAULT 240');
        await db.execute('ALTER TABLE ingredients ADD COLUMN tags TEXT');
      } catch (e) {}
      //await _insertCompleteSubstitutionData(db);
    }
    if (oldVersion < 18) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS customized_meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_meal_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        customized_name TEXT,
        original_ingredients TEXT NOT NULL,
        substituted_ingredients TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        FawaitOREIGN KEY (original_meal_id) REFERENCES meals(mealID),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
  }
  }

  // ADD THIS NEW METHOD
  Future<void> _insertAdminUser(Database db) async {
    // Check if admin already exists to avoid duplicates
    final existingAdmin = await db.query(
      'users',
      where: 'emailAddress = ? OR username = ?',
      whereArgs: ['admin@healthtingi.com', 'admin'],
    );

    if (existingAdmin.isEmpty) {
      final adminPassword = _hashPassword('admin123');
      
      await db.insert('users', {
        'firstName': 'System',
        'middleName': null,
        'lastName': 'Administrator',
        'emailAddress': 'admin@healthtingi.com',
        'username': 'admin',
        'password': adminPassword,
        'hasDietaryRestriction': 0,
        'dietaryRestriction': null,
        'favorites': null,
        'recentlyViewed': null,
        'birthday': '1990-01-01',
        'age': 34,
        'gender': null,
        'street': null,
        'barangay': null,
        'city': null,
        'nationality': null,
        'createdAt': DateTime.now().toIso8601String(),
        'isAdmin': 1,
      });
      
      print('Admin user created successfully');
    } else {
      print('Admin user already exists');
    }
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _updateExistingRecordsWithPictures(Database db) async {
    // Update ingredients with picture paths
    await db.update('ingredients', {
      'ingredientPicture': 'assets/chicken_neck_wings.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Chicken (neck/wings)']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/sayote.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Sayote']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/malunggay.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Malunggay']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/ginger.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Ginger']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/onion.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Onion']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/garlic.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Garlic']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/cooking_oil.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Cooking oil']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/bagoong.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Bagoong']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/tomato.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Tomato']);

    await db.update('ingredients', {
      'ingredientPicture': 'assets/soy_sauce.jpg'
    }, where: 'ingredientName = ?', whereArgs: ['Soy Sauce']);

    // Update meals with picture paths
    await db.update('meals', {
      'mealPicture': 'assets/tinolang_manok.jpg'
    }, where: 'mealName = ?', whereArgs: ['Tinolang Manok']);

    await db.update('meals', {
      'mealPicture': 'assets/ginisang_sayote.jpg'
    }, where: 'mealName = ?', whereArgs: ['Ginisang Sayote']);
  }

  Future<void> onDowngrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS users');
    await db.execute('DROP TABLE IF EXISTS ingredients');
    await db.execute('DROP TABLE IF EXISTS meals');
    await db.execute('DROP TABLE IF EXISTS meal_ingredients');
    await db.execute('DROP TABLE IF EXISTS faqs');
    await db.execute('DROP TABLE IF EXISTS about_us');
    await _onCreate(db, _currentVersion);
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        middleName TEXT,
        lastName TEXT NOT NULL,
        emailAddress TEXT NOT NULL UNIQUE,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        hasDietaryRestriction INTEGER DEFAULT 0,
        dietaryRestriction TEXT,
        favorites TEXT,
        recentlyViewed TEXT,
        birthday TEXT,
        age INTEGER,
        gender TEXT,
        street TEXT,
        barangay TEXT,
        city TEXT,
        nationality TEXT,
        createdAt TEXT NOT NULL,
        isAdmin INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createIngredientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ingredients (
      ingredientID INTEGER PRIMARY KEY AUTOINCREMENT,
      ingredientName TEXT NOT NULL,
      price REAL NOT NULL,
      calories INTEGER NOT NULL,
      nutritionalValue TEXT NOT NULL,
      ingredientPicture TEXT,
      category TEXT,
      additionalPictures TEXT,
      price_text TEXT,
      unit TEXT,
      sodium_mg_per_100g REAL DEFAULT 0,
      protein_g_per_100g REAL DEFAULT 0,
      carbs_g_per_100g REAL DEFAULT 0,
      fat_g_per_100g REAL DEFAULT 0,
      unit_density_tbsp REAL DEFAULT 15,
      unit_density_tsp REAL DEFAULT 5,
      unit_density_cup REAL DEFAULT 240,
      tags TEXT
    )
    ''');

    await db.execute('''
      CREATE INDEX idx_ingredient_name ON ingredients(ingredientName)
    ''');

    await db.execute('''
    CREATE INDEX idx_ingredient_name_lower ON ingredients(LOWER(ingredientName))
  ''');
  }

  Future<void> _createMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meals (
        mealID INTEGER PRIMARY KEY AUTOINCREMENT,
        mealName TEXT NOT NULL,
        price REAL NOT NULL,
        calories INTEGER NOT NULL,
        servings INTEGER NOT NULL,
        cookingTime TEXT NOT NULL,
        mealPicture TEXT,
        category TEXT,
        content TEXT,
        instructions TEXT,
        hasDietaryRestrictions TEXT,
        availableFrom TEXT,
        availableTo TEXT,
        additionalPictures TEXT
      )
    ''');
  }

  Future<void> _createMealIngredientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meal_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mealID INTEGER NOT NULL,
        ingredientID INTEGER NOT NULL,
        quantity TEXT,
        FOREIGN KEY (mealID) REFERENCES meals(mealID) ON DELETE CASCADE,
        FOREIGN KEY (ingredientID) REFERENCES ingredients(ingredientID)
      )
    ''');
  }

  

  Future<void> _createFaqsTable(Database db) async {
    await db.execute('''
      CREATE TABLE faqs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        order_num INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createAboutUsTable(Database db) async {
    await db.execute('''
      CREATE TABLE about_us (
        id INTEGER PRIMARY KEY,
        content TEXT NOT NULL
      )
    ''');
  }

  Future<void> _insertInitialFaqs(Database db) async {
    List<Map<String, dynamic>> initialFaqs = [
      {
        'question': '1. What is HealthTingi?',
        'answer': 'HealthTingi is an Android app that helps you scan ingredients using your phone\'s camera and suggests budget-friendly recipes you can cook with them—even without an internet connection.',
        'order_num': 1
      },
      {
        'question': '2. Who is the app for?',
        'answer': 'It\'s specially designed for low-income Filipino households, but anyone looking for affordable and nutritious meals can use it.',
        'order_num': 2
      },
      {
        'question': '3. Do I need Wi-Fi or mobile data to use it?',
        'answer': 'No. HealthTingi works offline, so you can use all main features like scanning, viewing recipes, and searching ingredients anytime.',
        'order_num': 3
      },
      {
        'question': '4. How does the scanner work?',
        'answer': 'Just take a photo of your ingredients, and the app will identify multiple items at once using image recognition powered by a trained AI model.',
        'order_num': 4
      },
      {
        'question': '5. Can I still get recipe suggestions if I don\'t have a complete ingredient list?',
        'answer': 'Yes! HealthTingi shows substitution options and recommends recipes based on what you do have.',
        'order_num': 5
      },
      {
        'question': '6. What if prices in my area are different?',
        'answer': 'You can manually input or update prices, and the app averages community-submitted prices to stay accurate for your location.',
        'order_num': 6
      },
      {
        'question': '7. Is it free to use?',
        'answer': 'Yes, HealthTingi is completely free.',
        'order_num': 7
      },
      {
        'question': '8. Where does the recipe and nutrition data come from?',
        'answer': 'The app uses locally sourced data and Filipino recipes tailored to ingredients commonly found in local markets.',
        'order_num': 8
      },
      {
        'question': '9. How does it know what recipes are affordable for me?',
        'answer': 'You can enter your budget (like ₱70), and the app filters out recipes that exceed it, using current ingredient prices.',
        'order_num': 9
      },
      {
        'question': '10. Can I suggest a recipe or report a problem?',
        'answer': 'Yes, you can suggest recipes or feedback through the app\'s "Contact Us" feature (if included), or by email.',
        'order_num': 10
      },
    ];

    for (var faq in initialFaqs) {
      await db.insert('faqs', faq);
    }
  }

  Future<void> _insertInitialAboutUs(Database db) async {
    await db.insert('about_us', {
      'id': 1,
      'content': 'HealthTingi is a mobile application designed to promote affordable and nutritious eating for low-income Filipino households. Built with accessibility in mind, the app helps users identify ingredients using a simple photo and suggests budget-friendly recipes based on what they have and how much they can spend.\n\n'
          'By combining real-time ingredient recognition, a local price-aware recipe engine, and offline access, HealthTingi empowers families to make the most of what\'s available—whether in urban or rural communities. Our mission is to use simple technology to address food insecurity, improve nutrition, and support smarter meal planning across the Philippines.'
    });
  }

  Future<void> _insertInitialData(Database db) async {
    // Insert ingredients
    await _insertIngredientsFromJson(db);
    // Insert meals and their relationships
    await _insertMeals(db);
  }

  Future<void> _insertIngredientsFromJson(Database db) async {
    try {
      final String dataString = await rootBundle.loadString('assets/data/ingredients.json');
      final Map<String, dynamic> data = jsonDecode(dataString);
      final List<dynamic> ingredientsList = data['ingredients'];

      await db.transaction((txn) async {
        for (var ingredient in ingredientsList) {
          await txn.insert(
            'ingredients',
            {
              'ingredientName': ingredient['ingredientName'] as String,
              'price': double.parse(ingredient['price'].toString()), // Parse string to double
              'calories': ingredient['calories'] as int,
              'nutritionalValue': ingredient['nutritionalValue'] as String,
              'ingredientPicture': ingredient['ingredientPicture'] as String?,
              'category': ingredient['category'] as String?,
              'additionalPictures': ingredient['additionalPictures'] as String?,
              'price_text': ingredient['price_text'] as String?,
              'unit': ingredient['unit'] as String?,
              'sodium_mg_per_100g': double.tryParse(ingredient['sodium_mg_per_100g'].toString()) ?? 0.0,
              'protein_g_per_100g': double.tryParse(ingredient['protein_g_per_100g'].toString()) ?? 0.0,
              'carbs_g_per_100g': double.tryParse(ingredient['carbs_g_per_100g'].toString()) ?? 0.0,
              'fat_g_per_100g': double.tryParse(ingredient['fat_g_per_100g'].toString()) ?? 0.0,
              'unit_density_tbsp': double.tryParse(ingredient['unit_density_tbsp'].toString()) ?? 15.0,
              'unit_density_tsp': double.tryParse(ingredient['unit_density_tsp'].toString()) ?? 5.0,
              'unit_density_cup': double.tryParse(ingredient['unit_density_cup'].toString()) ?? 240.0,
              'tags': ingredient['tags'] as String?,
            },
            conflictAlgorithm: ConflictAlgorithm.replace, // Overwrite duplicates
          );
        }
      });
      print('Inserted ${ingredientsList.length} ingredients successfully from JSON');
    } catch (e) {
      print('Error loading ingredients from JSON: $e');
      await _insertIngredients(db); // Fallback
    }
  }

  Future<void> _insertIngredients(Database db) async {
    final List<Map<String, dynamic>> fallbackIngredients = [
      {
        'ingredientName': 'Chicken (neck/wings)',
        'price': 30.0,
        'calories': 239,
        'nutritionalValue': 'Good source of protein, niacin, selenium, phosphorus, and vitamin B6.',
        'ingredientPicture': 'assets/chicken_neck_wings.jpg',
        'category': 'main dish',
        'additionalPictures': '',
        'price_text': '30/kg',
        'unit': 'kg',
        'sodium_mg_per_100g': 0.0,
        'protein_g_per_100g': 0.0,
        'carbs_g_per_100g': 0.0,
        'fat_g_per_100g': 0.0,
        'unit_density_tbsp': 15.0,
        'unit_density_tsp': 5.0,
        'unit_density_cup': 240.0,
        'tags': '["protein", "main"]',
      },
      {
        'ingredientName': 'Sayote',
        'price': 12.0,
        'calories': 19,
        'nutritionalValue': 'Rich in Vitamin C, Folate, Fiber, Potassium, Manganese.',
        'ingredientPicture': 'assets/sayote.jpg',
        'category': 'soup, main dish, appetizer',
        'additionalPictures': '',
        'price_text': '12/kg',
        'unit': 'kg',
        'sodium_mg_per_100g': 0.0,
        'protein_g_per_100g': 0.0,
        'carbs_g_per_100g': 0.0,
        'fat_g_per_100g': 0.0,
        'unit_density_tbsp': 15.0,
        'unit_density_tsp': 5.0,
        'unit_density_cup': 240.0,
        'tags': '["vegetable", "soup"]',
      },
    ];

    await db.transaction((txn) async {
      for (var ingredient in fallbackIngredients) {
        await txn.insert(
          'ingredients',
          ingredient,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    print('Inserted ${fallbackIngredients.length} fallback ingredients');
  }

  Future<void> _insertMeals(Database db) async {
    // Insert Tinolang Manok
    final tinolangId = await db.insert('meals', {
      'mealName': 'Tinolang Manok',
      'price': 65.0,
      'calories': 250,
      'servings': 2,
      'cookingTime': '15-20 minutes',
      'mealPicture': 'assets/tinolang_manok.jpg',
      'category': 'main dish, soup',
      'content': 'Chicken soup with sayote, malunggay, and ginger',
      'instructions': '''
1. Prep Time (5 mins)
Wash the chicken pieces thoroughly.
Peel and mince the garlic.
Peel and slice the onion into wedges.
Peel and julienne the ginger.
Peel the sayote, remove the seed, and cut into wedges.
Wash the malunggay leaves and separate them from the stems.

2. Sauté Aromatics (3 mins)
In a cooking pot over medium heat, add the cooking oil.
Once the oil is hot, sauté the garlic until fragrant and light golden.
Add the onion and ginger, and sauté until the onion becomes translucent.

3. Brown the Chicken (5 mins)
Add the chicken pieces to the pot.
Sauté until the chicken is lightly browned on the outside and no longer pink.
Season with a pinch of salt or a splash of fish sauce (patis) at this stage.

4. Simmer the Chicken (20 mins)
Pour in enough water to just cover the chicken (about 2–3 cups).
Bring to a boil, then immediately lower the heat to a gentle simmer.
Cover the pot and let it cook for 20–25 minutes, or until the chicken is fully tender.

5. Add the Sayote (7 mins)
Add the sayote wedges to the pot.
Continue simmering until the sayote is tender but still firm, about 7–10 minutes.

6. Final Touches (2 mins)
Add the malunggay leaves to the pot.
Let it simmer for another 1–2 minutes until the leaves are just wilted.
Do a final taste test and adjust the seasoning with more salt or fish sauce if needed.
Serve hot.
''',
      'hasDietaryRestrictions': 'hypertension, chicken allergy',
      'availableFrom': '17:00',
      'availableTo': '21:00'
    });

    // Insert Tinolang Manok ingredients
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 37, // Chicken
      'quantity': '1/4 kg'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 128, // Sayote
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 153, // Ginger
      'quantity': '1 small thumb'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 149, // Onion
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 152, // Garlic
      'quantity': '2 cloves'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 237, // Cooking oil
      'quantity': '1 tbsp'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 238, // Malunggay
      'quantity': '1 small bundle'
    });

    // Insert Ginisang Sayote
    final ginisangId = await db.insert('meals', {
      'mealName': 'Ginisang Sayote',
      'price': 57.0,
      'calories': 180,
      'servings': 2,
      'cookingTime': '10-15 minutes',
      'mealPicture': 'assets/ginisang_sayote.jpg',
      'category': 'main dish',
      'content': 'Sauteed sayote with tomato, onion, garlic, and bagoong',
      'instructions': '''
1. Prep Time (5 mins)
Peel and slice the sayote into thin strips or matchsticks.
Dice the onion, tomato, and mince the garlic.

2. Heat the Pan (1 min)
In a pan over medium heat, add the oil and let it heat up.

3. Sauté Aromatics (2–3 mins)
Add garlic and stir until fragrant and golden.
Add the onion and tomato. Sauté until softened.

4. Add Bagoong (1 min)
Add the bagoong and sauté for about a minute to release flavor.

5. Cook the Sayote (5–7 mins)
Add the sliced sayote and sauté for a couple of minutes.
Pour in the soy sauce.
Stir occasionally, cover the pan, and let it cook until the sayote is tender but not mushy.

6. Taste and Adjust (1 min)
You may add a bit of water if it's too salty or dry.
Optional: Add chili flakes or ground pepper for heat.

7. Serve
Serve hot with steamed rice. Great with fried fish or just on its own!
''',
      'hasDietaryRestrictions': 'pescatarian',
      'availableFrom': '11:00',
      'availableTo': '13:00'
    });

    // Insert Ginisang Sayote ingredients
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 128, // Sayote
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 23, // Bagoong
      'quantity': '1/4 tsp'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 149, // Onion
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 152, // Garlic
      'quantity': '4 cloves'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 129, // Tomato
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 237, // Cooking oil
      'quantity': '1/8 cup'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 239, // Soy Sauce
      'quantity': '1/4 cup'
    });

    // Insert Adobong Manok
  final adobongManokId = await db.insert('meals', {
    'mealName': 'Adobong Manok',
    'price': 60.0,
    'calories': 217,
    'servings': 2,
    'cookingTime': '45 minutes',
    'mealPicture': 'assets/adobong_manok.jpg',
    'category': 'Main Dish, Soup',
    'content': 'Classic Filipino chicken simmered in soy-vinegar garlic sauce.',
    'instructions': '''
1. Prep Time (5 mins)
Pat the chicken thighs dry with a paper towel.
Peel and crush the garlic cloves.
If using whole peppercorns, you can lightly crush them.

2. Marinate (15–30 mins)
In a large bowl, combine the chicken, soy sauce, crushed garlic, and peppercorns.
You can let it marinate for 15-30 minutes for deeper flavor, or proceed immediately.

3. Initial Simmer (25 mins)
Transfer the chicken and marinade into a wide pot or pan.
Add the bay leaves and 1 cup of water.
Bring to a boil, then reduce the heat to low, cover, and simmer for 25-30 minutes until the chicken is tender.

4. Add Vinegar (5 mins)
Uncover the pot and pour in the vinegar.
Do not stir immediately; let the vinegar cook off its raw acidity for about 3-5 minutes.

5. Reduce the Sauce (7 mins)
After the vinegar has cooked, you can now stir.
Increase the heat to medium and let the sauce reduce and thicken to your desired consistency, stirring occasionally. This should take about 5-10 minutes.

6. Sauté for Color (3 mins)
In a separate pan, heat 1 tsp of cooking oil.
You can optionally sauté the cooked chicken pieces briefly until they get a slightly browned, crispy exterior.
Pour the reduced sauce over the chicken before serving.
''',
    'hasDietaryRestrictions': 'Hypertension, Halal if using halal-certified chicken',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 43, // Chicken thigh
    'quantity': '2 pieces (≈300g)'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 234, // Bay leaf
    'quantity': '1 leaf'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 235, // Peppercorns
    'quantity': '½ tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 239, // Soy sauce
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 236, // Vinegar
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tsp'
  });

  // Insert Biko
  final bikoId = await db.insert('meals', {
    'mealName': 'Biko',
    'price': 50.0,
    'calories': 476,
    'servings': 4,
    'cookingTime': '60 minutes',
    'mealPicture': 'assets/biko.jpg',
    'category': 'Dessert, Snack',
    'content': 'Sticky rice cake with coconut milk and sweet brown sugar caramel (latik).',
    'instructions': '''
1. Prep Time (10 mins)
Rinse the glutinous rice thoroughly until the water runs clear.
In a rice cooker or pot, combine the rinsed rice with 2 cups of coconut milk and 1 cup of water.
Let the rice soak for 30 minutes if you have time.

2. Cook the Rice (20 mins)
Cook the rice mixture as you normally would (in a rice cooker or over the stove) until the liquid is absorbed and the rice is fully cooked.

3. Prepare the Latik / Syrup (15 mins)
In a separate, wide, heavy-bottomed pan, combine the remaining 2 cups of coconut milk and brown sugar.
Cook over medium heat, stirring continuously, until the mixture thickens significantly into a sticky, caramel-like syrup. This can take 15-20 minutes.

4. Combine Rice and Syrup (10 mins)
Add the cooked sticky rice to the pan with the caramel syrup.
Mix vigorously and continuously until the rice is fully coated and the mixture becomes very thick and difficult to stir.

5. Transfer and Flatten (5 mins)
Grease a baking pan or a tray with a little oil.
Transfer the thick rice mixture into the pan.
Using a spatula or a banana leaf, press and flatten the mixture evenly.

6. Top and Cool (10 mins)
If you made latik (coconut curds) from reducing coconut cream, sprinkle it on top.
Allow the Biko to cool completely before slicing into squares or diamonds.
''',
    'hasDietaryRestrictions': 'Vegetarian (contains no meat), not vegan because of sugar/latik (check sugar source)',
    'availableFrom': '14:00',
    'availableTo': '17:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': bikoId,
    'ingredientID': 242, // Glutinous rice
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': bikoId,
    'ingredientID': 243, // Coconut milk
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': bikoId,
    'ingredientID': 241, // Brown sugar
    'quantity': '¾ cup'
  });

  // Insert Binignit
  final binignitId = await db.insert('meals', {
    'mealName': 'Binignit',
    'price': 55.0,
    'calories': 246,
    'servings': 3,
    'cookingTime': '45 minutes',
    'mealPicture': 'assets/binignit.jpg',
    'category': 'Dessert, Snack, Soup',
    'content': 'Creamy Filipino sweet stew of coconut milk with tubers, saba banana, glutinous rice, and jackfruit.',
    'instructions': '''
1. Prep Time (10 mins)
Peel and cube the sweet potato, taro, and purple yam into bite-sized pieces.
Peel the saba bananas and slice into thick rounds.
If using fresh jackfruit, remove the seeds and cut into chunks.
If tapioca pearls are raw, cook them separately according to package directions until translucent.

2. Simmer the Base (10 mins)
In a large pot, bring the coconut milk and 2 cups of water to a gentle simmer over medium heat.
Add the rinsed glutinous rice and cook, stirring occasionally to prevent sticking, for about 10-15 minutes.

3. Cook the Root Vegetables (15 mins)
Add the cubed sweet potato, taro, and purple yam to the pot.
Continue to simmer, stirring occasionally, until the root vegetables are almost tender.

4. Add Soft Fruits (5–7 mins)
Stir in the saba bananas and jackfruit pieces.
Cook for another 5-7 minutes until the bananas are soft.

5. Final Touches (5 mins)
Add the cooked tapioca pearls and brown sugar.
Stir well and simmer for a final 5 minutes until everything is heated through and the sugar is dissolved. The consistency should be thick and porridge-like.
Serve warm or chilled.
''',
    'hasDietaryRestrictions': 'Vegetarian (no meat), Vegan-friendly if sugar is vegan',
    'availableFrom': '14:00',
    'availableTo': '17:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 242, // Glutinous rice
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 144, // Sweet potato
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 148, // Taro (gabi)
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 147, // Purple yam (ube)
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 154, // Saba banana
    'quantity': '2 pieces'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 175, // Jackfruit
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 8, // Tapioca pearls
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 216, // Coconut milk
    'quantity': '4 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 217, // Brown sugar
    'quantity': '½ cup'
  });

  // Insert Halo-Halo
  final haloHaloId = await db.insert('meals', {
    'mealName': 'Halo-Halo',
    'price': 75.0,
    'calories': 226,
    'servings': 2,
    'cookingTime': '15 minutes',
    'mealPicture': 'assets/halo_halo.jpg',
    'category': 'Dessert, Snack',
    'content': 'A classic Filipino shave-ice treat layered with sweet fruit, beans, jellies, milk and topped with ice cream or leche flan.',
    'instructions': '''
1. Prep Time (5 mins)
Ensure all your ingredients (sweetened beans, nata de coco, kaong, macapuno, gulaman, etc.) are prepared, sweetened, and chilled.
If using leche flan, have it sliced and ready.
Scoop the ube ice cream and keep it in the freezer until serving time.

2. Prepare the Glass (3 mins)
Get a tall glass.
Start layering your sweet ingredients at the bottom. Begin with the sweetened beans, then add nata de coco, kaong, saba banana, jackfruit, macapuno, and gulaman.

3. Add Ice (1 min)
Fill the glass to the top with finely shaved ice, pressing down gently.

4. Add Milk and Toppings (1 min)
Drizzle the evaporated milk (and/or condensed milk) over the shaved ice.
Place your chosen toppings on top: a slice of leche flan and a scoop (or two) of ube ice cream.

5. Serve Immediately
Serve immediately with a long spoon. Instruct to mix all the ingredients together thoroughly before eating.
''',
    'hasDietaryRestrictions': 'Vegetarian (contains dairy), not suitable for strict vegans',
    'availableFrom': '11:00',
    'availableTo': '14:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 226, // Sweetened beans (mungo)
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 58, // Nata de coco
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 59, // Kaong
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 154, // Saba banana
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 175, // Jackfruit
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 60, // Macapuno
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 61, // Gulaman
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 62, // Shaved ice
    'quantity': 'To fill'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 253, // Evaporated milk
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 63, // Ube ice cream
    'quantity': '1–2 scoops (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 64, // Leche flan
    'quantity': '1 slice (optional)'
  });

  // Insert Chopsuey
  final chopsueyId = await db.insert('meals', {
    'mealName': 'Chopsuey',
    'price': 60.0,
    'calories': 167,
    'servings': 2,
    'cookingTime': '25 minutes',
    'mealPicture': 'assets/chopsuey.jpg',
    'category': 'Main Dish, Vegetable',
    'content': 'Stir-fried mixed vegetables with chicken/shrimp in savory sauce.',
    'instructions': '''
1. Prep Time (10–15 mins)
Cut the chicken into thin slices or bite-sized pieces.
Peel and mince the garlic.
Slice the onion.
Chop the carrots, broccoli, and cauliflower into florets.
Slice the bell pepper and cabbage.
If using mushrooms, slice them.

2. Sauté Aromatics and Protein (5 mins)
Heat oil in a large wok or pan over medium-high heat.
Sauté garlic and onion until fragrant and softened.
Add the chicken slices and cook until they are no longer pink and are lightly browned.

3. Cook Harder Vegetables (4–5 mins)
Add the carrots, broccoli, and cauliflower to the wok.
Stir-fry for about 4-5 minutes until they start to soften but are still crisp.

4. Add Sauces and Broth (3–4 mins)
Pour in the chicken broth, soy sauce, and oyster sauce.
Stir everything together and bring to a simmer.

5. Thicken the Sauce (2–3 mins)
In a small bowl, mix the cornstarch with 2 tablespoons of water to create a slurry.
While stirring the contents of the wok, slowly pour in the cornstarch slurry.
Continue to cook until the sauce thickens to a glossy consistency.

6. Final Stir-in (2 mins)
Add the bell peppers, cabbage, and mushrooms.
Stir-fry for just another 1-2 minutes until the cabbage is slightly wilted but still colorful and crisp.
Season with ground pepper to taste. Serve immediately.
''',
    'hasDietaryRestrictions': 'Contains soy; can omit meat to make vegetarian',
    'availableFrom': '11:00',
    'availableTo': '14:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 43, // Chicken thigh
    'quantity': '100g'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 52, // Carrots
    'quantity': '⅓ piece'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 139, // Broccoli
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 115, // Cauliflower
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 133, // Bell pepper
    'quantity': '½ small'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 114, // Cabbage
    'quantity': '½ small'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 6, // Mushrooms
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 149, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 239, // Soy sauce
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 247, // Oyster sauce
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 248, // Cornstarch
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 60, // Chicken broth
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tsp'
  });

  // Insert Laing
  final laingId = await db.insert('meals', {
    'mealName': 'Laing',
    'price': 65.0,
    'calories': 380,
    'servings': 2,
    'cookingTime': '75 minutes',
    'mealPicture': 'assets/laing.jpg',
    'category': 'Main Dish, Soup, Vegetable',
    'content': 'Creamy coconut-based taro leaf stew with shrimp paste and chili.',
    'instructions': '''
1. Prep Time (10 mins)
If using dried taro leaves, ensure they are properly rehydrated.
Peel and mince the garlic and ginger.
Slice the onion.
Cut the pork belly into small cubes.
Slice the Thai chilies (for less heat, you can leave them whole).

2. Sauté the Base (3 mins)
In a pot, heat the cooking oil over medium heat.
Sauté the garlic, onion, and ginger until very fragrant and the onion is soft.

3. Cook the Pork and Shrimp Paste (5 mins)
Add the pork belly cubes and cook until they start to render fat and brown slightly.
Add the shrimp paste (bagoong alamang) and sauté for another 2 minutes to incorporate its flavor.

4. Simmer with Coconut Milk (40 mins)
Pour in the coconut milk and bring the mixture to a gentle simmer.
Carefully add the taro leaves, pushing them down into the liquid. IMPORTANT: Do not stir for the first 15 minutes to prevent itching.
Let it simmer uncovered for 40-45 minutes, stirring occasionally after the first 15 minutes, until the leaves have absorbed much of the liquid and the sauce has thickened.

5. Add Cream and Chili (10 mins)
Stir in the coconut cream and the sliced chilies.
Continue to simmer for another 10 minutes until the sauce is rich and creamy, and the oil starts to separate slightly.
Season with salt if needed. Serve hot.
''',
    'hasDietaryRestrictions': 'Not suitable for strict vegetarians due to shrimp paste',
    'availableFrom': '12:00',
    'availableTo': '15:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 19, // Taro leaves
    'quantity': '3 cups dried (rehydrated)'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 237, // Cooking oil
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 152, // Garlic
    'quantity': '4 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 149, // Onion
    'quantity': '1 medium'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 153, // Ginger
    'quantity': '1 thumb'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 52, // Pork belly
    'quantity': '100g'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 23, // Shrimp paste
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 243, // Coconut milk
    'quantity': '3 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 250, // Thai chilies
    'quantity': '5–7 pieces'
  });

  // Insert Sinigang na Baboy (Pork)
  final sinigangBaboyId = await db.insert('meals', {
    'mealName': 'Sinigang na Baboy (Pork)',
    'price': 70.0,
    'calories': 150,
    'servings': 2,
    'cookingTime': '70 minutes',
    'mealPicture': 'assets/sinigang_na_baboy.jpg',
    'category': 'Soup, Main Dish',
    'content': 'Sour tamarind broth soup with pork and veggies.',
    'instructions': '''
1. Prep Time (8 mins)
Wash the pork belly and cut into serving pieces.
Slice the tomato.
Quarter the onion.
Peel and slice the gabi (taro) into chunks.
Peel and slice the radish.
Slice the eggplant.
Wash the kangkong leaves.

2. Boil the Pork (40–45 mins)
In a large pot, combine the pork, tomato, and onion.
Cover with about 8-10 cups of water.
Bring to a boil, then skim off any scum that rises to the surface.
Lower the heat, cover, and simmer for 40-45 minutes or until the pork is tender.

3. Add Gabi and Tamarind (10 mins)
Add the gabi (taro) and your tamarind seasoning mix (or fresh tamarind pulp).
Simmer for about 10 minutes until the gabi starts to soften.

4. Add Other Vegetables (5–7 mins)
Add the radish and eggplant.
Continue to simmer for 5-7 minutes until these vegetables are tender.

5. Final Touches (2 mins)
Add the kangkong leaves.
Season the soup with fish sauce (patis) to your taste.
Let it cook for just another minute until the kangkong wilts. Serve hot.
''',
    'hasDietaryRestrictions': 'Halal/vegetarian option if using fish instead of pork',
    'availableFrom': '11:00',
    'availableTo': '14:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 52, // Pork belly
    'quantity': '300g'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 129, // Tomato
    'quantity': '1 medium'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 149, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 245, // Tamarind
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 117, // Kangkong
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 148, // Gabi (taro)
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 34, // Radish
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 122, // Eggplant
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 246, // Fish sauce
    'quantity': '1 tsp'
  });

  // Insert Ginataang Gulay
  final ginataangGulayId = await db.insert('meals', {
    'mealName': 'Ginataang Gulay',
    'price': 55.0,
    'calories': 210,
    'servings': 2,
    'cookingTime': '30 minutes',
    'mealPicture': 'assets/ginataang_gulay.jpg',
    'category': 'Main Dish, Vegetable',
    'content': 'A creamy vegetable stew simmered in coconut milk, rich and comforting.',
    'instructions': '''
1. Prep Time (8 mins)
Slice the string beans into 2-inch lengths.
Peel the squash, remove seeds, and cut into cubes.
Slice the eggplant.
Peel and mince the garlic and ginger.
Slice the onion.

2. Sauté Aromatics (2 mins)
In a pot, heat the cooking oil over medium heat.
Sauté the garlic, onion, and ginger until fragrant and the onion is translucent.

3. Sauté Vegetables (4–5 mins)
Add the string beans and squash cubes.
Stir-fry for about 4-5 minutes to lightly cook the exterior.

4. Simmer in Coconut Milk (10–12 mins)
Pour in the coconut milk and bring to a gentle simmer.
Let it cook, uncovered, for 10-12 minutes, or until the squash is fork-tender.

5. Add Cream and Season (3–5 mins)
Stir in the coconut cream.
Add the sliced eggplant and simmer for another 3-5 minutes until the eggplant is cooked and the sauce has thickened slightly.
Season with salt and pepper to taste. Serve hot.
''',
    'hasDietaryRestrictions': 'Vegan, Halal, Gluten-Free',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 134, // String beans
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 127, // Squash
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 122, // Eggplant
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 243, // Coconut milk
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 149, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 153, // Ginger
    'quantity': '1 thumb'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });

  // Insert Ginisang Kalabasa
  final ginisangKalabasaId = await db.insert('meals', {
    'mealName': 'Ginisang Kalabasa',
    'price': 50.0,
    'calories': 185,
    'servings': 2,
    'cookingTime': '25 minutes',
    'mealPicture': 'assets/ginisang_kalabasa.jpg',
    'category': 'Main Dish, Vegetable',
    'content': 'A budget-friendly sautéed squash dish that is simple and hearty.',
    'instructions': '''
1. Prep Time (8 mins)
Peel the kalabasa (squash), remove seeds, and cut into small cubes.
Dice the tomato and onion.
Mince the garlic.
If using meat, have your ground pork or shrimp ready.

2. Sauté Aromatics and Protein (5–7 mins)
Heat oil in a pan over medium heat.
Sauté the garlic and onion until soft and fragrant.
Add the tomato and cook until it softens and releases its juice.
If using, add the ground pork or shrimp and cook until browned or opaque.

3. Cook the Squash (12–15 mins)
Add the kalabasa cubes to the pan.
Pour in about ½ cup of water or broth.
Cover the pan and let it simmer for 12-15 minutes, or until the kalabasa is very tender and can be easily mashed with a spoon.

4. Mash and Season (2–3 mins)
You can lightly mash some of the kalabasa with the back of your spoon to thicken the sauce.
Season with salt and plenty of ground black pepper to taste.
Simmer for another 2-3 minutes. Serve hot.
''',
    'hasDietaryRestrictions': 'Vegetarian (if no meat), Halal',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 127, // Kalabasa (squash)
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 129, // Tomato
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 149, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });

  // Insert Sinigang na Isda
  final sinigangIsdaId = await db.insert('meals', {
    'mealName': 'Sinigang na Isda',
    'price': 60.0,
    'calories': 130,
    'servings': 2,
    'cookingTime': '30 minutes',
    'mealPicture': 'assets/sinigang_na_isda.jpg',
    'category': 'Soup, Main Dish',
    'content': 'A tangy tamarind-based fish soup perfect for rainy days.',
    'instructions': '''
1. Prep Time (8–10 mins)
Clean the fish (bangus or tilapia) and cut into large slices.
Slice the tomato.
Quarter the onion.
Peel and slice the radish.
Slice the eggplant.
Wash the kangkong leaves.

2. Boil the Broth Base (5 mins)
In a pot, bring 6-8 cups of water to a boil.
Add the tomato and onion, and boil for about 5 minutes until they soften.

3. Add Tamarind and Fish (7–10 mins)
Stir in the tamarind seasoning mix until dissolved.
Gently add the fish slices and simmer for 7-10 minutes until the fish is cooked through.

4. Add Vegetables (5–7 mins)
Add the radish and eggplant.
Continue to simmer for 5-7 minutes until the vegetables are tender.

5. Final Touches (2 mins)
Add the kangkong leaves and the whole green chili (if using).
Season with fish sauce to taste.
Cook for just another minute until the kangkong wilts. Serve immediately.
''',
    'hasDietaryRestrictions': 'Halal, Pescatarian',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 183, // Bangus or tilapia
    'quantity': '2 medium slices'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 129, // Tomato
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 149, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 245, // Tamarind paste
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 117, // Kangkong
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 34, // Radish
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 122, // Eggplant
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 132, // Green chili
    'quantity': '1 (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 246, // Fish sauce
    'quantity': 'To taste'
  });

  // Insert Sinigang na Hipon
  final sinigangHiponId = await db.insert('meals', {
    'mealName': 'Sinigang na Hipon',
    'price': 75.0,
    'calories': 160,
    'servings': 2,
    'cookingTime': '25 minutes',
    'mealPicture': 'assets/sinigang_na_hipon.jpg',
    'category': 'Soup, Main Dish',
    'content': 'A light and tangy shrimp soup that warms and satisfies with its sour kick.',
    'instructions': '''
1. Prep Time (10 mins)
Clean the shrimp, leaving the heads on for more flavor if desired.
Slice the tomato.
Quarter the onion.
Peel and slice the radish.
Slice the eggplant and cut the sitaw into 2-inch lengths.
Wash the kangkong leaves.

2. Boil the Broth Base (5 mins)
In a pot, bring 6-8 cups of water to a boil.
Add the tomato and onion and boil for about 5 minutes.

3. Add Tamarind and Shrimp (5–7 mins)
Stir in the tamarind paste until it dissolves.
Gently add the shrimp and simmer for 5-7 minutes until they turn pink and are cooked through. Do not overcook.

4. Add Vegetables (5 mins)
Add the radish, eggplant, and sitaw.
Simmer for about 5 minutes until the vegetables are tender but still firm.

5. Final Touches (2 mins)
Add the kangkong leaves and green chili.
Season with fish sauce to taste.
Let it cook for just another minute until the kangkong wilts. Serve hot.
''',
    'hasDietaryRestrictions': 'Halal, Pescatarian',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 206, // Shrimp
    'quantity': '250g'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 129, // Tomato
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 149, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 117, // Kangkong
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 134, // Sitaw
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 34, // Radish
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 122, // Eggplant
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 245, // Tamarind paste
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 132, // Green chili
    'quantity': '1 (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 246, // Fish sauce
    'quantity': 'To taste'
  });

  // Insert Tortang Sayote
  final tortangSayoteId = await db.insert('meals', {
    'mealName': 'Tortang Sayote',
    'price': 50.0,
    'calories': 200,
    'servings': 2,
    'cookingTime': '20 minutes',
    'mealPicture': 'assets/tortang_sayote.jpg',
    'category': 'Appetizer, Vegetable',
    'content': 'A crispy egg-and-chayote omelette—simple, budget-friendly, and filling.',
    'instructions': '''
1. Prep and Grate Sayote (7 mins)
Peel the sayote, remove the seed, and grate them using a grater.
Place the grated sayote in a clean cloth or cheesecloth and squeeze out as much excess water as possible. This is a crucial step for a crispy torta.

2. Mix the Batter (3 mins)
In a bowl, beat the eggs.
Add the squeezed grated sayote, minced garlic, chopped onion, and flour.
Season with salt and pepper. Mix everything until well-combined.

3. Heat the Pan (2 mins)
Place a non-stick skillet over medium heat and add enough cooking oil to coat the surface.
Let the oil get hot.

4. Fry the Patties (10–12 mins)
Scoop about ¼ cup of the mixture and pour it into the pan, shaping it into a patty.
Fry for about 3-4 minutes on one side until the bottom is golden brown and set.
Carefully flip and cook the other side for another 3-4 minutes.
Repeat with the remaining mixture.

5. Drain and Serve (2 mins)
Place the cooked Tortang Sayote on a plate lined with paper towels to drain excess oil.
Serve hot with ketchup or a vinegar and garlic dip.
''',
    'hasDietaryRestrictions': 'Vegetarian, Halal',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 128, // Sayote
    'quantity': '2 medium'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 178, // Eggs
    'quantity': '3'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 152, // Garlic
    'quantity': '2 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 149, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 251, // Flour
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 237, // Cooking oil
    'quantity': 'For frying'
  });

  // Insert Adobong Pusit
  final adobongPusitId = await db.insert('meals', {
    'mealName': 'Adobong Pusit',
    'price': 80.0,
    'calories': 240,
    'servings': 2,
    'cookingTime': '35 minutes',
    'mealPicture': 'assets/adobong_pusit.jpg',
    'category': 'Main Dish, Seafood',
    'content': 'A bold, savory squid dish stewed in soy sauce and vinegar with a hint of garlic.',
    'instructions': '''
1. Prep Time (10 mins)
Clean the squid thoroughly, removing the ink sac, quill, and innards. You can keep the ink for a darker sauce if you like.
Leave the squid whole or slice it into rings.
Mince the garlic and slice the onion.

2. Sauté Aromatics (3 mins)
Heat oil in a pan over medium heat.
Sauté the garlic and onion until soft and aromatic.

3. Cook the Squid (2–3 mins)
Add the squid to the pan and cook for 2-3 minutes, stirring, until it firms up and turns opaque.

4. Add Sauces and Simmer (10 mins)
Pour in the soy sauce and vinegar. DO NOT STIR. Let the vinegar cook for about 3 minutes to lose its raw acidity.
Add the black pepper and, if using, the optional tomato.
After 3 minutes, you can stir. Let it simmer on low heat for 10-15 minutes until the squid is tender and the sauce has reduced. Be careful not to overcook the squid, or it will become rubbery.

5. Final Reduction (2 mins)
If there's still a lot of sauce, increase the heat for the last 2 minutes to reduce it to a glazy consistency.
Serve hot.
''',
    'hasDietaryRestrictions': 'Halal, Pescatarian',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 207, // Squid
    'quantity': '300g'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 149, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 239, // Soy sauce
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 236, // Vinegar
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 233, // Black pepper
    'quantity': '½ tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 129, // Tomato
    'quantity': '1 small (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });

  // Insert Adobong Baboy
  final adobongBaboyId = await db.insert('meals', {
    'mealName': 'Adobong Baboy',
    'price': 120.0,
    'calories': 380,
    'servings': 3,
    'cookingTime': '45 minutes',
    'mealPicture': 'assets/adobong_baboy.jpg',
    'category': 'Main Dish',
    'content': 'A hearty Filipino classic of pork stewed in soy sauce, vinegar, and spices.',
    'instructions': '''
1. Prep and Marinate (20–30 mins)
Cut the pork belly into bite-sized cubes.
In a large bowl, combine the pork, soy sauce, crushed garlic, peppercorns, and bay leaves.
Let it marinate for at least 20-30 minutes.

2. Initial Simmer (30–40 mins)
Transfer the pork and its marinade into a pot.
Add 1 cup of water.
Bring to a boil, then reduce the heat to low, cover, and simmer for 30-40 minutes until the pork is very tender.

3. Add Vinegar (5 mins)
Uncover the pot and pour in the vinegar.
Do not stir. Let it cook undisturbed for about 5 minutes to allow the vinegar's sharpness to mellow.

4. Brown and Reduce (10–15 mins)
You can now stir. Increase the heat to medium.
Let the pork cook in the reducing sauce until the sauce thickens and the pork starts to sizzle and fry in its own rendered fat, getting slightly crispy edges. This should take 10-15 minutes.

5. Serve
Serve the Adobong Baboy hot with its reduced sauce, alongside steamed rice.
''',
    'hasDietaryRestrictions': 'Not suitable for Halal, Hypertension',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 52, // Pork belly
    'quantity': '500g'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 239, // Soy sauce
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 236, // Vinegar
    'quantity': '3 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 234, // Bay leaves
    'quantity': '2'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 235, // Peppercorns
    'quantity': '1 tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });

  // Insert Ginataang Alimango
  final ginataangAlimangoId = await db.insert('meals', {
    'mealName': 'Ginataang Alimango',
    'price': 120.0,
    'calories': 450,
    'servings': 2,
    'cookingTime': '40 minutes',
    'mealPicture': 'assets/ginataang_alimango.jpg',
    'category': 'Main Dish, Seafood',
    'content': 'Rich and creamy crab dish simmered in coconut milk with vegetables.',
    'instructions': '''
1. Prep Time (10–15 mins)
Clean the live crabs thoroughly. You can leave them whole or chop them into sections.
Peel and mince the garlic and ginger.
Slice the onion.
Cut the squash into chunks and the sitaw into lengths.

2. Sauté the Base (2 mins)
In a wide pot, heat oil over medium heat.
Sauté the garlic, onion, and ginger until very fragrant.

3. Cook the Crab (5–7 mins)
Add the crab pieces to the pot.
Sauté for 5-7 minutes until the shells start to turn orange-red.

4. Simmer in Coconut Milk (15–20 mins)
Pour in the coconut milk and bring the mixture to a gentle boil.
Lower the heat, cover, and simmer for 15-20 minutes to cook the crab through and infuse the flavor.

5. Add Veggies and Cream (7–10 mins)
Add the squash and sitaw.
Continue to simmer until the vegetables are tender, about 7-10 minutes.
Stir in the coconut cream and add the red chili.
Simmer for another 5 minutes until the sauce is rich and creamy. Season with salt if needed.
''',
    'hasDietaryRestrictions': 'Pescatarian, Halal',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 202, // Alimango/crab
    'quantity': '2 pcs'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 243, // Coconut milk
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 127, // Squash
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 134, // Sitaw
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 131, // Red chili
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 149, // Onion
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 153, // Ginger
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });

  // Insert Saging Prito
  final sagingPritoId = await db.insert('meals', {
    'mealName': 'Saging Prito',
    'price': 50.0,
    'calories': 160,
    'servings': 2,
    'cookingTime': '15 minutes',
    'mealPicture': 'assets/saging_prito.jpg',
    'category': 'Dessert, Snack',
    'content': 'Golden fried saba bananas—crispy outside, soft and sweet inside.',
    'instructions': '''
1. Prep Time (5 mins)
Peel the saba bananas.
You can leave them whole, slice them in half lengthwise, or diagonally into thick slices.
Place the brown sugar on a plate.

2. Coat Bananas in Sugar (2 mins)
Roll the banana pieces in the brown sugar until they are evenly coated.

3. Heat the Oil (3 mins)
In a frying pan, pour enough cooking oil to reach about ½ inch deep.
Heat the oil over medium heat until hot (a piece of banana should sizzle when added).

4. Fry the Bananas (8–10 mins)
Carefully place the sugar-coated bananas in the hot oil.
Fry for about 4-5 minutes on each side, or until they are golden brown and caramelized, and the sugar forms a crispy coating.

5. Drain and Cool (2 mins)
Remove the bananas from the oil and place them on a wire rack or a plate lined with paper towels to drain excess oil.
Let them cool for a minute or two before serving, as the caramelized sugar will be very hot.
''',
    'hasDietaryRestrictions': 'Vegan, Vegetarian, Halal',
    'availableFrom': '14:00',
    'availableTo': '17:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': sagingPritoId,
    'ingredientID': 154, // Saba banana
    'quantity': '4 pcs'
  });
  await db.insert('meal_ingredients', {
    'mealID': sagingPritoId,
    'ingredientID': 252, // Brown sugar
    'quantity': '3 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sagingPritoId,
    'ingredientID': 237, // Cooking oil
    'quantity': 'For frying'
  });

  // Insert Escabeche
  final escabecheId = await db.insert('meals', {
    'mealName': 'Escabeche',
    'price': 100.0,
    'calories': 320,
    'servings': 2,
    'cookingTime': '35 minutes',
    'mealPicture': 'assets/escabeche.jpg',
    'category': 'Main Dish',
    'content': 'A sweet and tangy fried fish dish topped with sautéed vegetables in sauce.',
    'instructions': '''
1. Prep and Fry the Fish (10–12 mins)
Clean the fish (tilapia or bangus) and score the sides.
Pat it completely dry with paper towels.
Heat oil for frying in a pan over medium-high heat.
Fry the fish until golden brown and crispy on both sides. Remove and set aside on a serving plate.

2. Sauté Vegetables for Sauce (5 mins)
In a separate pan, heat a tablespoon of oil.
Sauté the garlic and onion until soft.
Add the julienned carrots and bell pepper, and stir-fry for 2-3 minutes until they begin to soften.

3. Combine Sauce Ingredients (2 mins)
Pour in the soy sauce, vinegar, and about ½ cup of water.
Add the sugar and stir until dissolved.
Let the mixture come to a simmer.

4. Thicken the Sauce (2 mins)
In a small bowl, create a slurry by mixing the cornstarch with 2 tablespoons of water.
While stirring the simmering sauce, slowly add the cornstarch slurry.
Continue to cook and stir until the sauce thickens to a glossy, syrupy consistency.

5. Assemble and Serve (1 min)
Taste the sauce and adjust seasoning if needed.
Pour the hot sweet and sour sauce with vegetables over the fried fish.
Serve immediately.
''',
    'hasDietaryRestrictions': 'Pescatarian, Halal',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 183, // Tilapia or bangus
    'quantity': '2 pcs'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 139, // Carrots
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 133, // Bell pepper
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 149, // Onion
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 152, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 236, // Vinegar
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 239, // Soy sauce
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 252, // Sugar
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 248, // Cornstarch
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 237, // Cooking oil
    'quantity': 'For frying'
  });

  // Insert Ginataang Kalabasa
  final ginataangKalabasaId = await db.insert('meals', {
    'mealName': 'Ginataang Kalabasa',
    'price': 60.0,
    'calories': 250,
    'servings': 2,
    'cookingTime': '25 minutes',
    'mealPicture': 'assets/ginataang_kalabasa.jpg',
    'category': 'Vegetable, Main Dish',
    'content': 'Creamy coconut-based stew with squash and string beans.',
    'instructions': '''
1. Prep Time (8–10 mins)
Peel the kalabasa, remove seeds, and cut into cubes.
Cut the sitaw into 2-inch lengths.
Mince the garlic and slice the onion.

2. Sauté Aromatics (2 mins)
Heat oil in a pot over medium heat.
Sauté the garlic and onion until soft and translucent.

3. Sauté Squash (2–3 mins)
Add the kalabasa cubes and sauté for 2-3 minutes.

4. Simmer in Coconut Milk (10–12 mins)
Pour in the coconut milk and bring to a gentle simmer.
Let it cook for 10-12 minutes until the kalabasa is almost tender.

5. Add Sitaw and Shrimp (5–7 mins)
Add the sitaw and the shrimp (if using).
Continue to simmer for another 5-7 minutes until the sitaw is cooked but still crisp, the shrimp is pink, and the kalabasa is fully tender.
Season with salt or fish sauce to taste. Serve hot.
''',
    'hasDietaryRestrictions': 'Vegetarian (if no shrimp), Vegan (if no fish), Halal',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 127, // Kalabasa
    'quantity': '1½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 134, // Sitaw
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 243, // Coconut milk
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 149, // Onion
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 152, // Garlic
    'quantity': '2 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 206, // Shrimp
    'quantity': '½ cup (optional)'
  });

  // Insert Ginisang Upo
  final ginisangUpoId = await db.insert('meals', {
    'mealName': 'Ginisang Upo',
    'price': 55.0,
    'calories': 180,
    'servings': 2,
    'cookingTime': '20 minutes',
    'mealPicture': 'assets/ginisang_upo.jpg',
    'category': 'Vegetable',
    'content': 'A healthy sautéed bottle gourd dish, light and perfect for lunch.',
    'instructions': '''
1. Prep Time (8 mins)
Peel the upo (bottle gourd), remove the soft inner part with seeds, and slice into half-moons.
Dice the tomato and onion.
Mince the garlic.
Prepare your protein (ground pork or shrimp).

2. Sauté Aromatics and Protein (5 mins)
Heat oil in a pan over medium heat.
Sauté the garlic and onion until fragrant.
Add the tomato and cook until soft.
Add the ground pork or shrimp and cook until browned or opaque.

3. Cook the Upo (8–10 mins)
Add the sliced upo to the pan.
Season with salt and pepper.
You can add about ¼ cup of water to create some steam.
Cover the pan and let it simmer for 8-10 minutes, or until the upo is translucent and tender but not mushy.

4. Season and Serve (1 min)
Do a final taste test and adjust seasoning if necessary.
Serve hot.
''',
    'hasDietaryRestrictions': 'Halal (if using shrimp), Pescatarian, Not Vegan if using meat',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 125, // Upo
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 129, // Tomato
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 152, // Garlic
    'quantity': '2 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 149, // Onion
    'quantity': '½ small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 25, // Ground pork or shrimp
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tbsp'
  });

  // Insert Fried Egg with Malunggay
  final friedEggMalunggayId = await db.insert('meals', {
    'mealName': 'Fried Egg with Malunggay',
    'price': 50.0,
    'calories': 220,
    'servings': 1,
    'cookingTime': '10 minutes',
    'mealPicture': 'assets/fried_egg_malunggay.jpg',
    'category': 'Breakfast, Appetizer',
    'content': 'Nutritious fried egg packed with moringa leaves for an energy boost.',
    'instructions': '''
1. Prep Time (3 mins)
Crack the eggs into a bowl.
Wash the malunggay leaves and pluck them from the stems.
If using, mince a small amount of garlic.

2. Beat the Eggs (1 min)
Beat the eggs vigorously with a fork or whisk until the yolks and whites are fully combined.
Stir in the malunggay leaves and minced garlic (if using). Season with a pinch of salt and pepper.

3. Heat the Pan (1 min)
Place a non-stick skillet over medium heat and add the cooking oil.
Let the oil get hot.

4. Cook the Egg (3–4 mins)
Pour the egg and malunggay mixture into the hot skillet.
Let it cook undisturbed for about 2 minutes until the edges are set and the bottom is golden.
You can scramble it or flip it to cook as a single omelette until it's cooked to your liking.

5. Serve Immediately
Slide the fried egg onto a plate.
Serve immediately while hot, ideally with a side of rice.
''',
    'hasDietaryRestrictions': 'Halal, Vegetarian',
    'availableFrom': '07:00',
    'availableTo': '09:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': friedEggMalunggayId,
    'ingredientID': 38, // Eggs
    'quantity': '2'
  });
  await db.insert('meal_ingredients', {
    'mealID': friedEggMalunggayId,
    'ingredientID': 179, // Malunggay
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': friedEggMalunggayId,
    'ingredientID': 237, // Cooking oil
    'quantity': '1 tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': friedEggMalunggayId,
    'ingredientID': 152, // Garlic bits (optional)
    'quantity': 'Optional'
  });
  }

   // ========== NEW METHOD: Load meals from JSON ==========
  Future<void> loadMealsFromJson() async {
    final db = await database;
    try {
      final String dataString = await rootBundle.loadString('assets/data/meals.json');
      final Map<String, dynamic> data = jsonDecode(dataString);
      
      // First, get all ingredients to map names to IDs
      final List<Map<String, dynamic>> allIngredients = await db.query('ingredients');
      final Map<String, int> ingredientNameToId = {};
      for (var ingredient in allIngredients) {
        ingredientNameToId[ingredient['ingredientName']] = ingredient['ingredientID'];
      }
      
      // Clear existing meals and relationships
      await db.delete('meal_ingredients');
      await db.delete('meals');
      
      for (var mealData in data['meals']) {
        // Extract ingredients to insert separately
        final List<Map<String, dynamic>> mealIngredients = 
            List<Map<String, dynamic>>.from(mealData['ingredients']);
        mealData.remove('ingredients');
        
        // Insert meal
        final mealId = await db.insert('meals', mealData);
        
        // Insert meal ingredients
        for (var ingredient in mealIngredients) {
          final String ingredientName = ingredient['ingredientName'];
          final int? ingredientId = ingredientNameToId[ingredientName];
          
          if (ingredientId != null) {
            await db.insert('meal_ingredients', {
              'mealID': mealId,
              'ingredientID': ingredientId,
              'quantity': ingredient['quantity']
            });
          } else {
            print('Ingredient not found: $ingredientName');
          }
        }
      }
      print('Meals loaded successfully from JSON');
    } catch (e) {
      print('Error loading meals from JSON: $e');
      // Fallback to hardcoded meals if JSON fails
      await _insertMeals(db);
    }
  }

  // ========== UTILITY METHOD: Reset database with JSON data ==========
  Future<void> resetDatabaseWithJsonData() async {
    final db = await database;
    await db.delete('meal_ingredients');
    await db.delete('meals');
    await db.delete('ingredients');
    await _insertIngredientsFromJson(db);
    await loadMealsFromJson();
  }

  // ========== MEAL OPERATIONS ==========
  Future<List<Map<String, dynamic>>> getAllMeals() async {
    final db = await database;
    return await db.query('meals');
  }

  Future<Map<String, dynamic>?> getMealById(int mealId) async {
    final db = await database;
    final result = await db.query(
      'meals',
      where: 'mealID = ?',
      whereArgs: [mealId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getMealIngredients(int mealId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
      i.ingredientID,
      i.ingredientName,
      i.price,  -- This fetches the per-unit price
      i.category,
      i.ingredientPicture,
      -- Add other fields as needed
      mi.quantity
    FROM meal_ingredients mi
    JOIN ingredients i ON mi.ingredientID = i.ingredientID
    WHERE mi.mealID = ?
    ''', [mealId]);
  }

  // ========== USER OPERATIONS ==========
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'emailAddress = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateUser(int id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'users',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

    Future<List<String>> getAllMealCategories() async {
    final db = await database;
    
    final List<Map<String, dynamic>> meals = await db.query('meals', 
      columns: ['category']);
    
    Set<String> uniqueCategories = {};
    
    for (var meal in meals) {
      final categoryString = meal['category'] as String?;
      if (categoryString != null && categoryString.isNotEmpty) {
        // Split by comma, trim, and convert to lowercase for consistency
        final categories = categoryString.split(',')
          .map((cat) => cat.trim().toLowerCase())
          .toList();
        uniqueCategories.addAll(categories);
      }
    }
    
    // Convert back to title case for display
    return uniqueCategories.map((cat) => 
      cat.split(' ').map((word) => 
        word[0].toUpperCase() + word.substring(1)
      ).join(' ')
    ).toList()..sort();
  }

  // Add to database/db_helper.dart
  Future<void> addToRecentlyViewed(int userId, int mealId) async {
    final db = await database;
    final user = await getUserById(userId);
    if (user == null) return;

    String recentlyViewed = user['recentlyViewed']?.toString() ?? '';
    List<String> viewedList = recentlyViewed.split(',').where((id) => id.isNotEmpty).toList();

    // Remove if already exists to avoid duplicates
    viewedList.remove(mealId.toString());
    // Add to beginning
    viewedList.insert(0, mealId.toString());
    // Keep only last 5
    if (viewedList.length > 5) {
      viewedList = viewedList.sublist(0, 5);
    }

    await db.update(
      'users',
      {'recentlyViewed': viewedList.join(',')},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentlyViewedMeals(int userId) async {
    final db = await database;
    final user = await getUserById(userId);
    if (user == null) return [];

    String recentlyViewed = user['recentlyViewed']?.toString() ?? '';
    if (recentlyViewed.isEmpty) return [];

    final viewedIds = recentlyViewed.split(',').map(int.parse).toList();
    final allMeals = await getAllMeals();

    return viewedIds.map((id) {
      return allMeals.firstWhere((meal) => meal['mealID'] == id, orElse: () => {});
    }).where((meal) => meal.isNotEmpty).toList();
  }

  Future<List<Map<String, dynamic>>> getAllIngredients() async {
    final db = await database;
    return await db.query('ingredients');
  }

  // ========== UTILITY METHODS ==========
  Future<void> verifyDatabaseSchema() async {
    final db = await database;
    try {
      // Verify all tables exist
      final tables = ['users', 'ingredients', 'meals', 'meal_ingredients'];
      for (var table in tables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'"
        );
        if (result.isEmpty) {
          throw Exception('Missing table: $table');
        }
      }
    } catch (e) {
      await onDowngrade(db, 0, _currentVersion);
      throw Exception('Database recreated due to schema issues');
    }
  }

  Future<Map<String, dynamic>?> getIngredientByName(String name) async {
    final db = await database;
    final results = await db.query(
      'ingredients',
      where: 'ingredientName = ?',
      whereArgs: [name],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertMeal(Map<String, dynamic> meal) async {
  final db = await database;
  return await db.insert('meals', meal);
}

Future<int> updateMeal(int mealId, Map<String, dynamic> updates) async {
  final db = await database;
  return await db.update(
    'meals',
    updates,
    where: 'mealID = ?',
    whereArgs: [mealId],
  );
}

Future<int> deleteMeal(int mealId) async {
  final db = await database;
  return await db.delete(
    'meals',
    where: 'mealID = ?',
    whereArgs: [mealId],
  );
}

  Future<int> insertIngredient(Map<String, dynamic> ingredient) async {
  final db = await database;
  return await db.insert('ingredients', ingredient);
}

Future<int> updateIngredient(int ingredientId, Map<String, dynamic> updates) async {
  final db = await database;
  return await db.update(
    'ingredients',
    updates,
    where: 'ingredientID = ?',
    whereArgs: [ingredientId],
  );
}

Future<int> deleteIngredient(int ingredientId) async {
  final db = await database;
  return await db.delete(
    'ingredients',
    where: 'ingredientID = ?',
    whereArgs: [ingredientId],
  );
}

Future<List<Map<String, dynamic>>> getMealsWithIngredient(int ingredientId) async {
  final db = await database;
  return await db.rawQuery(
    '''
    SELECT m.* FROM meals m
    JOIN meal_ingredients mi ON m.mealID = mi.mealID
    WHERE mi.ingredientID = ?
    ''',
    [ingredientId],
  );
}

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<int> deleteUser(int userId) async {
  final db = await database;
  return await db.delete(
    'users',
    where: 'userID = ?',
    whereArgs: [userId],
  );
}

  Map<String, List<String>> _substitutions = {};

  Future<void> loadSubstitutions() async {
    if (_substitutions.isNotEmpty) return; // Already loaded, skip

    try {
      final String dataString = await rootBundle.loadString('assets/data/substitutions.json');
      final Map<String, dynamic> data = jsonDecode(dataString);
      _substitutions = data.map((key, value) => MapEntry(key, List<String>.from(value)));
      print('Substitutions loaded successfully from JSON');
    } catch (e) {
      print('Error loading substitutions from JSON: $e');
      // Optionally, fall back to hardcoded or empty map
      _substitutions = {};
    }
  }

  Future<List<String>> getAlternatives(String ingredient) async {
    await loadSubstitutions();
    // Case-insensitive lookup; adjust as needed for name mismatches (e.g., "Bagoong" vs "Bagoong (Shrimp Paste)")
    final normalizedKey = ingredient.toLowerCase();
    final matchingKey = _substitutions.keys.firstWhere(
      (k) => k.toLowerCase() == normalizedKey || k.toLowerCase().contains(normalizedKey),
      orElse: () => '',
    );
    return _substitutions[matchingKey] ?? [];
  }

  // Add this method to DatabaseHelper class in db_helper.dart
  Future<List<Map<String, dynamic>>> getSimilarMeals(List<String> ingredientNames, {int limit = 6}) async {
    final db = await database;
    
    if (ingredientNames.isEmpty) {
      return [];
    }

    // Create placeholders for the SQL query
    final placeholders = List.generate(ingredientNames.length, (_) => '?').join(',');
    
    // Query to find meals that share the most ingredients with the provided list
    final result = await db.rawQuery('''
      SELECT 
        m.*,
        COUNT(mi.ingredientID) as matching_ingredients,
        (SELECT COUNT(*) FROM meal_ingredients WHERE mealID = m.mealID) as total_ingredients,
        (COUNT(mi.ingredientID) * 100.0 / (SELECT COUNT(*) FROM meal_ingredients WHERE mealID = m.mealID)) as match_percentage
      FROM meals m
      JOIN meal_ingredients mi ON m.mealID = mi.mealID
      JOIN ingredients i ON mi.ingredientID = i.ingredientID
      WHERE i.ingredientName IN ($placeholders)
      GROUP BY m.mealID
      HAVING matching_ingredients > 0
      ORDER BY matching_ingredients DESC, match_percentage DESC
      LIMIT ?
    ''', [...ingredientNames, limit]);

    return result;
  }

  // ========== FAQ OPERATIONS ==========
  Future<List<Map<String, dynamic>>> getFaqs() async {
    final db = await database;
    return await db.query('faqs', orderBy: 'order_num ASC');
  }

  Future<int> insertFaq(Map<String, dynamic> faq) async {
    final db = await database;
    // Set order_num to max + 1
    final maxOrder = await db.rawQuery('SELECT MAX(order_num) as max FROM faqs');
    int newOrder = (maxOrder.first['max'] as int? ?? 0) + 1;
    faq['order_num'] = newOrder;
    return await db.insert('faqs', faq);
  }

  Future<int> updateFaq(int id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update('faqs', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFaq(int id) async {
    final db = await database;
    return await db.delete('faqs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderFaqs(List<Map<String, dynamic>> faqs) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < faqs.length; i++) {
        await txn.update(
          'faqs',
          {'order_num': i + 1},
          where: 'id = ?',
          whereArgs: [faqs[i]['id']],
        );
      }
    });
  }

  // ========== ABOUT US OPERATIONS ==========
  Future<String?> getAboutUsContent() async {
    final db = await database;
    final result = await db.query('about_us', limit: 1);
    return result.isNotEmpty ? result.first['content'] as String? : null;
  }

  Future<int> updateAboutUsContent(String content) async {
    final db = await database;
    if (await db.query('about_us').then((res) => res.isEmpty)) {
      return await db.insert('about_us', {'id': 1, 'content': content});
    } else {
      return await db.update('about_us', {'content': content}, where: 'id = 1');
    }
  }

  Map<String, dynamic> parsePriceString(String priceStr, String ingredientName, String category) {
    priceStr = priceStr.trim().toLowerCase();
    RegExp rangePat = RegExp(r'(\d+)-(\d+)');
    RegExp qtyPat = RegExp(r'(\d+(?:\.\d+)?|1/4|1/2|3/4)');
    RegExp unitPat = RegExp(r'(kg|g|ml|pack|piece|pcs|bottle|can|tray|tie|group|leaves|for|each|/pack|350ml bottle|500ml|250ml pack|10g cube|150g bottle|200g pack|370ml can|50g pack|1/4kg|1/4|100pcs/100 pesos|3 for 120|6 each|12-45/pack|20-25/pack|20-30/pack|70-80/pack)', caseSensitive: false);

    // Densities (g/ml) by category
    Map<String, double> densities = {
      'dairy': 1.03, // Milk
      'pantry': 1.1, // Sauces
      'vegetable': 1.0,
      'spice': 0.5, // Lighter for powders
      'legume': 1.0,
      'starch': 0.8, // For sago, etc.
      'condiment': 1.05,
    };
    double density = densities[category.toLowerCase()] ?? 1.0;

    // Unit to grams (refined with web averages)
    Map<String, double> unitToGrams = {
      'kg': 1000,
      'g': 1,
      'ml': density,
      'piece': category.toLowerCase() == 'vegetable' ? 400 : 100, // Banana blossom ~400g, general 100g
      'pcs': 100,
      'bottle': 500,
      'can': 370, // Evaporated milk ~370g
      'tray': 1800,
      'tie': 250,
      'group': 500,
      'leaves': 1,
      'pack': category.toLowerCase().contains('vegetable') ? 250 : (category.toLowerCase().contains('spice') ? 100 : 500), // Celery 250g, spices 100g, sago 500g, kidney beans 225g ~250g
      '1/4kg': 250,
      '1/4': 250, // Assume kg
      '350ml bottle': 350 * density,
      '500ml': 500 * density,
      '250ml pack': 250 * density,
      '10g cube': 10,
      '150g bottle': 150,
      '200g pack': 200,
      '370ml can': 370 * density,
      '50g pack': 50,
      'bundle': ingredientName.toLowerCase().contains('malunggay') ? 100.0 : 50.0, // Malunggay ~100g/bundle
      'head': 500.0, // E.g., pork head ~500g average portion
    };

    // Handle multiple prices (e.g., "400/kg, 20-25/pack") - prefer kg if present, else last
    List<String> parts = priceStr.split(',');
    String selectedPart = parts.firstWhere((p) => p.contains('/kg'), orElse: () => parts.last.trim());

    // Split by '/' for price/qtyunit
    List<String> subParts = selectedPart.split('/');
    String pricePart = subParts[0].trim();
    String qtyUnitPart = subParts.length > 1 ? subParts[1].trim() : '';

    // Extract avg price from pricePart
    var rangeMatch = rangePat.firstMatch(pricePart);
    double avgPrice = rangeMatch != null
        ? (double.parse(rangeMatch.group(1)!) + double.parse(rangeMatch.group(2)!)) / 2
        : (qtyPat.firstMatch(pricePart)?.group(1) != null ? double.parse(qtyPat.firstMatch(pricePart)!.group(1)!) : 0);

    // Extract qty (handle fractions like 1/4)
    var qtyMatch = qtyPat.firstMatch(qtyUnitPart) ?? qtyPat.firstMatch(pricePart);
    double qty = 1.0;
    if (qtyMatch != null) {
      String qtyStr = qtyMatch.group(1)!;
      if (qtyStr.contains('/')) {
        var frac = qtyStr.split('/');
        qty = double.parse(frac[0]) / double.parse(frac[1]);
      } else {
        qty = double.parse(qtyStr);
      }
    }

    // Extract unit
    var unitMatch = unitPat.firstMatch(qtyUnitPart) ?? unitPat.firstMatch(pricePart);
    String unit = unitMatch?.group(1)?.toLowerCase() ?? 'unit';

    // Special handling for "qty for total"
    if (priceStr.contains('for')) {
      var forMatch = RegExp(r'(\d+/\d+|\d+(?:\.\d+)?|1/4|1/2|3/4)\s*for\s*(\d+(?:\.\d+)?)').firstMatch(priceStr);
      if (forMatch != null) {
        String qtyStr = forMatch.group(1)!;
        double total = double.parse(forMatch.group(2)!);
        if (qtyStr.contains('/')) {
          var frac = qtyStr.split('/');
          qty = double.parse(frac[0]) / double.parse(frac[1]);
        } else {
          qty = double.parse(qtyStr);
        }
        avgPrice = total / qty; // Price per unit qty
      }
    }

    // For ranges like "20-25/pack"
    if (priceStr.contains('/pack') && rangeMatch != null) {
      avgPrice = (double.parse(rangeMatch.group(1)!) + double.parse(rangeMatch.group(2)!)) / 2;
      unit = 'pack';
      qty = 1;
    }

    // For "100pcs/100 pesos"
    if (priceStr.contains('pcs/')) {
      var pcsMatch = RegExp(r'(\d+)pcs/(\d+)').firstMatch(priceStr);
      if (pcsMatch != null) {
        double count = double.parse(pcsMatch.group(1)!);
        double total = double.parse(pcsMatch.group(2)!);
        avgPrice = total / count;
        qty = 1;
        unit = 'pcs';
      }
    }

    // Get grams
    double gramsPerUnit = unitToGrams[unit] ?? 100; // Default 100g
    double qtyGrams = qty * gramsPerUnit;

    // Price per 100g
    double pricePer100g = (qtyGrams > 0) ? (avgPrice / (qtyGrams / 100)) : 0;

    return {
      'price_per_100g': pricePer100g,
      'unit': unit,
      'price_text': priceStr,
    };
  }

/*

  Future<void> _insertCompleteSubstitutionData(Database db) async {
    await _insertUnitConversions(db);
    await _insertFilipinoIngredients(db);
    await _insertSubstitutionRules(db);
  }

  Future<void> _insertUnitConversions(Database db) async {
    final units = [
      {'unit_name': 'tbsp', 'grams_per_unit': 15.0},
      {'unit_name': 'tsp', 'grams_per_unit': 5.0},
      {'unit_name': 'cup', 'grams_per_unit': 240.0},
      {'unit_name': 'ml', 'grams_per_unit': 1.0},
      {'unit_name': 'piece', 'grams_per_unit': 100.0},
      {'unit_name': 'clove', 'grams_per_unit': 5.0},
      {'unit_name': 'kg', 'grams_per_unit': 1000.0},
      {'unit_name': 'g', 'grams_per_unit': 1.0},
      {'unit_name': 'bunch', 'grams_per_unit': 100.0},
      {'unit_name': 'slice', 'grams_per_unit': 30.0},
      {'unit_name': 'wedge', 'grams_per_unit': 75.0},
      // Expanded for 29 units
      {'unit_name': 'pack', 'grams_per_unit': 250.0}, // Average from searches
      {'unit_name': 'pcs', 'grams_per_unit': 100.0},
      {'unit_name': 'bottle', 'grams_per_unit': 500.0},
      {'unit_name': 'tray', 'grams_per_unit': 1800.0},
      {'unit_name': 'tie', 'grams_per_unit': 250.0},
      {'unit_name': 'group', 'grams_per_unit': 500.0},
      {'unit_name': 'can', 'grams_per_unit': 370.0},
      {'unit_name': 'leaves', 'grams_per_unit': 1.0},
      {'unit_name': '1/4kg', 'grams_per_unit': 250.0},
      {'unit_name': '350ml bottle', 'grams_per_unit': 350.0},
      {'unit_name': '500ml', 'grams_per_unit': 500.0},
      {'unit_name': '250ml pack', 'grams_per_unit': 250.0},
      {'unit_name': '10g cube', 'grams_per_unit': 10.0},
      {'unit_name': '150g bottle', 'grams_per_unit': 150.0},
      {'unit_name': '200g pack', 'grams_per_unit': 200.0},
      {'unit_name': '370ml can', 'grams_per_unit': 370.0},
      {'unit_name': '50g pack', 'grams_per_unit': 50.0},
      {'unit_name': '1/4', 'grams_per_unit': 250.0}, // Assume kg
      {'unit_name': '100pcs/100 pesos', 'grams_per_unit': 100.0},
      {'unit_name': '3 for 120', 'grams_per_unit': 100.0},
      {'unit_name': '6 each', 'grams_per_unit': 100.0},
      {'unit_name': '12-45/pack', 'grams_per_unit': 250.0},
      {'unit_name': '20-25/pack', 'grams_per_unit': 250.0},
      {'unit_name': '20-30/pack', 'grams_per_unit': 250.0},
      {'unit_name': '70-80/pack', 'grams_per_unit': 250.0},
    ];
    for (var unit in units) {
      await db.insert('unit_conversions', unit, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertFilipinoIngredients(Database db) async {
    String jsonString = await rootBundle.loadString('assets/data/ingredients.json');
    Map<String, dynamic> jsonData = json.decode(jsonString);
    List<dynamic> ingredientsJson = jsonData['ingredients'] ?? [];

    for (var ing in ingredientsJson) {
      // Existing parsePriceString call
      Map<String, dynamic> parsed = parsePriceString(ing['price_text'] ?? ing['price'] ?? '0', ing['ingredientName'] ?? '', ing['category'] ?? '');

      // Add normalization here (integrate with parsed if needed)
      double normalizedPrice = parsed['price_per_100g'] ?? (ing['price'] as double? ?? 0.0); // Start with existing parsed value
      String unit = (parsed['unit'] ?? ing['unit'] as String?)?.toLowerCase() ?? 'unknown';
      double assumedGrams = 100.0; // Default for per 100g

      if (unit == 'kg') {
        normalizedPrice /= 10; // 400/kg → 40/100g
      } else if (unit == 'pack' || unit == 'bottle' || unit == 'can') {
        // Defaults based on JSON patterns (e.g., packs ~200-350g)
        if (unit == 'pack') assumedGrams = 200.0; // Adjust per category if needed
        else if (unit == 'bottle') assumedGrams = 350.0;
        else if (unit == 'can') assumedGrams = 370.0;
        normalizedPrice = (normalizedPrice / (assumedGrams / 100)); // e.g., 10/200g pack → 5/100g
      } else if (unit == 'cube') {
        assumedGrams = 10.0;
        normalizedPrice = (normalizedPrice / (assumedGrams / 100)); // 65/cube → 650/100g (diluted broth)
      }
      // Handle other units if needed, e.g., add else if for 'ml' or unknowns

      await db.insert('ingredients', {
        'ingredientID': ing['ingredientID'],
        'ingredientName': ing['ingredientName'],
        'price': normalizedPrice, // Use the normalized value
        'calories': ing['calories'],
        'nutritionalValue': ing['nutritionalValue'],
        'ingredientPicture': ing['ingredientPicture'],
        'category': ing['category'],
        'sodium_mg_per_100g': ing['sodium_mg_per_100g'] ?? 0.0, // Preserve from JSON
        'protein_g_per_100g': ing['protein_g_per_100g'] ?? 0.0,
        'carbs_g_per_100g': ing['carbs_g_per_100g'] ?? 0.0,
        'fat_g_per_100g': ing['fat_g_per_100g'] ?? 0.0,
        'unit_density_tbsp': ing['unit_density_tbsp'] ?? 15.0, // Preserve
        'unit_density_tsp': ing['unit_density_tsp'] ?? 5.0,
        'unit_density_cup': ing['unit_density_cup'] ?? 240.0,
        'tags': ing['tags'] ?? '[]',
        'price_text': parsed['price_text'],
        'unit': parsed['unit'] ?? ing['unit'],
        'additionalPictures': ing['additionalPictures'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _insertSubstitutionRules(Database db) async {
  try {
    final String jsonString = await rootBundle.loadString('assets/data/substitutions.json');
    final Map<String, dynamic> subData = jsonDecode(jsonString);
    
    for (var entry in subData.entries) {
      final origName = entry.key;
      final subs = entry.value as List<dynamic>;
      
      // Get original ID
      final origResult = await db.query(
        'ingredients',
        where: 'ingredientName = ?',
        whereArgs: [origName],
      );
      if (origResult.isEmpty) continue; // Skip if original not found
      final origId = origResult.first['ingredientID'] as int;
      
      for (var subName in subs) {
        final subResult = await db.query(
          'ingredients',
          where: 'ingredientName = ?',
          whereArgs: [subName],
        );
        if (subResult.isEmpty) continue; // Skip if substitute not found
        final subId = subResult.first['ingredientID'] as int;
        
        // Insert with defaults (you can adjust based on category)
        await db.insert('substitutions', {
          'original_ingredient_id': origId,
          'substitute_ingredient_id': subId,
          'equivalence_ratio': 1.0,
          'flavor_similarity': 0.7, // Medium similarity
          'notes': 'General substitute based on availability and similar use.',
          'confidence': 'medium',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    print('Inserted substitutions from JSON');
  } catch (e) {
    print('Error loading substitutions.json: $e');
    // Optional: Fallback to hardcoded rules if JSON fails
  }
}

  // SubstitutionCalculator class - FIXED: Moved outside DatabaseHelper
  late final SubstitutionCalculator substitutionCalculator = SubstitutionCalculator(this);

  // Enhanced alternatives method
  Future<List<Map<String, dynamic>>> getEnhancedAlternatives(
    String ingredientName, double amount, String unit) async {
    final db = await database;
    final ingredient = await getIngredientByName(ingredientName); // Assume this method exists or add it
    if (ingredient == null) return [];
    return await substitutionCalculator.getRankedSubstitutes(
      originalIngredientId: ingredient['ingredientID'] as int,
      originalAmount: amount,
      originalUnit: unit,
    );
  }

  // Log substitution
  Future<void> logSubstitution({
    required int mealId,
    required int userId,
    required int originalIngredientId,
    required int substituteIngredientId,
    required double originalAmountG,
    required double substituteAmountG,
    required double costDelta,
    required double calorieDelta,
  }) async {
    final db = await database;
    await db.insert('meal_substitution_log', {
      'meal_id': mealId,
      'user_id': userId,
      'original_ingredient_id': originalIngredientId,
      'substitute_ingredient_id': substituteIngredientId,
      'original_amount_g': originalAmountG,
      'substitute_amount_g': substituteAmountG,
      'cost_delta': costDelta,
      'calorie_delta': calorieDelta,
      'substitution_date': DateTime.now().toIso8601String(),
    });
  }
  */

  // ========== CUSTOMIZED MEALS OPERATIONS ==========

  Future<int> saveCustomizedMeal({
    required int originalMealId,
    required int userId,
    required Map<String, String> originalIngredients,
    required Map<String, Map<String, dynamic>> substitutedIngredients,
    String? customizedName,
  }) async {
    final db = await database;
    
    // Deactivate any existing active customization for this meal and user
    await db.update(
      'customized_meals',
      {'is_active': 0},
      where: 'original_meal_id = ? AND user_id = ? AND is_active = 1',
      whereArgs: [originalMealId, userId],
    );

    return await db.insert('customized_meals', {
      'original_meal_id': originalMealId,
      'user_id': userId,
      'customized_name': customizedName,
      'original_ingredients': jsonEncode(originalIngredients),
      'substituted_ingredients': jsonEncode(substitutedIngredients),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_active': 1,
    });
  }

  Future<Map<String, dynamic>?> getActiveCustomizedMeal(int originalMealId, int userId) async {
    final db = await database;
    final result = await db.query(
      'customized_meals',
      where: 'original_meal_id = ? AND user_id = ? AND is_active = 1',
      whereArgs: [originalMealId, userId],
    );
    
    if (result.isNotEmpty) {
      final meal = result.first;
      return {
        ...meal,
        'original_ingredients': jsonDecode(meal['original_ingredients'] as String),
        'substituted_ingredients': jsonDecode(meal['substituted_ingredients'] as String),
      };
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUserCustomizedMeals(int userId) async {
    final db = await database;
    final result = await db.query(
      'customized_meals',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
    );
    
    return result.map((meal) {
      return {
        ...meal,
        'original_ingredients': jsonDecode(meal['original_ingredients'] as String),
        'substituted_ingredients': jsonDecode(meal['substituted_ingredients'] as String),
      };
    }).toList();
  }

  Future<int> updateCustomizedMeal({
    required int customizedMealId,
    required Map<String, String> substitutedIngredients,
    String? customizedName,
  }) async {
    final db = await database;
    return await db.update(
      'customized_meals',
      {
        'substituted_ingredients': jsonEncode(substitutedIngredients),
        'customized_name': customizedName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customizedMealId],
    );
  }

  Future<int> deleteCustomizedMeal(int customizedMealId) async {
    final db = await database;
    return await db.delete(
      'customized_meals',
      where: 'id = ?',
      whereArgs: [customizedMealId],
    );
  }

}

/*
 ========== SUBSTITUTION CALCULATOR CLASS - MOVED OUTSIDE DatabaseHelper ==========
class SubstitutionCalculator {
  final DatabaseHelper dbHelper;

  SubstitutionCalculator(this.dbHelper);

  // Convert recipe amount to grams
  Future<double> convertToGrams(double amount, String unit, Map<String, dynamic>? ingredient) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'unit_conversions',
      where: 'unit_name = ?',
      whereArgs: [unit.toLowerCase()],
    );
    
    if (result.isEmpty) {
      // Default to grams if unit not found
      return amount;
    }
    
    double gramsPerUnit = result.first['grams_per_unit'] as double;
    
    // Override with per-ingredient if available
    if (ingredient != null) {
      if (unit == 'cup') gramsPerUnit = ingredient['unit_density_cup'] as double? ?? gramsPerUnit;
      if (unit == 'tbsp') gramsPerUnit = ingredient['unit_density_tbsp'] as double? ?? gramsPerUnit;
      if (unit == 'tsp') gramsPerUnit = ingredient['unit_density_tsp'] as double? ?? gramsPerUnit;
    }
    
    return amount * gramsPerUnit;
  }

  // Calculate substitution details
  Future<Map<String, dynamic>> calculateSubstitution({
    required int originalIngredientId,
    required int substituteIngredientId,
    required double originalAmount,
    required String originalUnit,
  }) async {
    final db = await dbHelper.database;
    
    // Get original ingredient data
    final originalIngredient = await db.query(
      'ingredients',
      where: 'ingredientID = ?',
      whereArgs: [originalIngredientId],
    );
    
    // Get substitute ingredient data  
    final substituteIngredient = await db.query(
      'ingredients',
      where: 'ingredientID = ?',
      whereArgs: [substituteIngredientId],
    );
    
    // Get substitution rule
    final substitutionRule = await db.query(
      'substitutions',
      where: 'original_ingredient_id = ? AND substitute_ingredient_id = ?',
      whereArgs: [originalIngredientId, substituteIngredientId],
    );
    
    if (originalIngredient.isEmpty || substituteIngredient.isEmpty) {
      throw Exception('Ingredient not found');
    }
    
    final orig = originalIngredient.first;
    final sub = substituteIngredient.first;
    final rule = substitutionRule.isNotEmpty ? substitutionRule.first : null;
    
    // Convert to grams (fixed: pass orig as the ingredient map)
    final origGrams = await convertToGrams(originalAmount, originalUnit, orig);
    
    // Calculate substitute amount
    final equivalenceRatio = rule?['equivalence_ratio'] as double? ?? 1.0;
    final subGrams = origGrams * equivalenceRatio;
    
    // Calculate nutritional values (per 100g basis)
    final origCalories = (orig['calories'] as int) * (origGrams / 100);
    final subCalories = (sub['calories'] as int) * (subGrams / 100);
    final calorieDelta = subCalories - origCalories;
    
    // Calculate cost
    final origPricePer100g = orig['price'] as double;
    final subPricePer100g = sub['price'] as double;
    final origCost = origPricePer100g * (origGrams / 100);
    final subCost = subPricePer100g * (subGrams / 100);
    final costDelta = subCost - origCost;
    
    // Calculate sodium impact
    final origSodium = (orig['sodium_mg_per_100g'] as double?) ?? 0 * (origGrams / 100);
    final subSodium = (sub['sodium_mg_per_100g'] as double?) ?? 0 * (subGrams / 100);
    final sodiumDelta = subSodium - origSodium;
    
    return {
      'original': {
        'ingredient': orig,
        'amount_g': origGrams,
        'calories': origCalories,
        'cost': origCost,
        'sodium_mg': origSodium,
      },
      'substitute': {
        'ingredient': sub,
        'amount_g': subGrams,
        'calories': subCalories,
        'cost': subCost,
        'sodium_mg': subSodium,
      },
      'deltas': {
        'calories': calorieDelta,
        'cost': costDelta,
        'sodium': sodiumDelta,
      },
      'rule': rule,
      'equivalence_ratio': equivalenceRatio,
    };
  }

  // Get ranked substitutes for an ingredient
  Future<List<Map<String, dynamic>>> getRankedSubstitutes({
    required int originalIngredientId,
    required double originalAmount,
    required String originalUnit,
    Map<String, double> weights = const {
      'cost': 0.3,
      'calories': 0.3,
      'flavor': 0.4,
    },
  }) async {
    final db = await dbHelper.database;
    
    // Get all possible substitutes
    final substitutes = await db.rawQuery('''
      SELECT s.*, i.* 
      FROM substitutions s
      JOIN ingredients i ON s.substitute_ingredient_id = i.ingredientID
      WHERE s.original_ingredient_id = ?
    ''', [originalIngredientId]);
    
    List<Map<String, dynamic>> rankedSubstitutes = [];
    
    for (var sub in substitutes) {
      final calculation = await calculateSubstitution(
        originalIngredientId: originalIngredientId,
        substituteIngredientId: sub['substitute_ingredient_id'] as int,
        originalAmount: originalAmount,
        originalUnit: originalUnit,
      );
      
      // Calculate composite score
      final costDelta = calculation['deltas']['cost'] as double;
      final calorieDelta = calculation['deltas']['calories'] as double;
      final flavorSimilarity = sub['flavor_similarity'] as double;
      
      // Normalize deltas (lower is better)
      final normCost = costDelta.abs() / ((calculation['original']['cost'] as double) + 0.001);
      final normCalories = calorieDelta.abs() / ((calculation['original']['calories'] as double) + 0.001);
      
      // Composite score (lower is better)
      final score = 
          weights['cost']! * normCost +
          weights['calories']! * normCalories +
          weights['flavor']! * (1 - flavorSimilarity);
      
      rankedSubstitutes.add({
        ...calculation,
        'score': score,
        'display_amount': _formatAmountForDisplay(
          calculation['substitute']['amount_g'] as double,
          originalUnit,
        ),
      });
    }
    
    // Sort by score (ascending - lower score is better)
    rankedSubstitutes.sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));
    
    return rankedSubstitutes;
  }

  String _formatAmountForDisplay(double grams, String originalUnit) {
    // Simple conversion back to original units for display
    if (originalUnit == 'tbsp') {
      return '${(grams / 15).toStringAsFixed(1)} tbsp';
    } else if (originalUnit == 'tsp') {
      return '${(grams / 5).toStringAsFixed(1)} tsp';
    } else {
      return '${grams.toStringAsFixed(1)}g';
    }
  }
}
*/