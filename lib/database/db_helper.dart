import 'package:firebase_database/firebase_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _currentVersion = 20; 

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
    await _createUsersTable(db);           // <--- Was missing!
    await _createIngredientsTable(db);
    await _createMealsTable(db);
    await _createMealIngredientsTable(db); // <--- This was the cause of your crash!
    await _createFaqsTable(db);            // <--- Was missing!
    await _createAboutUsTable(db);

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
    await _insertInitialData(db); 
    
    // Admin User
    await _insertAdminUser(db);
    
    // Content Pages
    await _insertInitialFaqs(db);
    await _insertInitialAboutUs(db);
    
    // Logic Data
    await _insertUnitConversions(db); 
    await _insertCompleteSubstitutionData(db);
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
    if (oldVersion < 20) {
      try {
        // Create temporary table with new structure
        await db.execute('''
          CREATE TABLE meal_ingredients_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mealID INTEGER NOT NULL,
            ingredientID INTEGER NOT NULL,
            quantity REAL,
            unit TEXT,
            content TEXT,
            FOREIGN KEY (mealID) REFERENCES meals(mealID) ON DELETE CASCADE,
            FOREIGN KEY (ingredientID) REFERENCES ingredients(ingredientID)
          )
        ''');
        
        // Copy data from old table to new table
        await db.execute('''
          INSERT INTO meal_ingredients_new (id, mealID, ingredientID, quantity, unit, content)
          SELECT id, mealID, ingredientID, NULL, NULL, quantity FROM meal_ingredients
        ''');
        
        // Drop old table
        await db.execute('DROP TABLE meal_ingredients');
        
        // Rename new table
        await db.execute('ALTER TABLE meal_ingredients_new RENAME TO meal_ingredients');
        
        print('Successfully migrated meal_ingredients table to new structure');
      } catch (e) {
        print('Error migrating meal_ingredients table: $e');
        // If migration fails, recreate the table
        await _createMealIngredientsTable(db);
      }
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
        unit REAL,
        content REAL,
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
        'quantity': 0.25,
        'unit': 'kg',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': tinolangId,
        'ingredientID': 128, // Sayote
        'quantity': 1,
        'unit': 'piece',
        'content': 'peeled and wedged'
      });
      await db.insert('meal_ingredients', {
        'mealID': tinolangId,
        'ingredientID': 153, // Ginger
        'quantity': 1,
        'unit': 'small thumb',
        'content': 'julienned'
      });
      await db.insert('meal_ingredients', {
        'mealID': tinolangId,
        'ingredientID': 149, // Onion
        'quantity': 1,
        'unit': 'small',
        'content': 'wedged'
      });
      await db.insert('meal_ingredients', {
        'mealID': tinolangId,
        'ingredientID': 152, // Garlic
        'quantity': 2,
        'unit': 'cloves',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': tinolangId,
        'ingredientID': 237, // Cooking oil
        'quantity': 1,
        'unit': 'tbsp',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': tinolangId,
        'ingredientID': 238, // Malunggay
        'quantity': 1,
        'unit': 'bundle',
        'content': 'leaves separated'
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
        'quantity': 1,
        'unit': 'small',
        'content': 'sliced into strips'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangId,
        'ingredientID': 23, // Bagoong
        'quantity': 0.25,
        'unit': 'tsp',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangId,
        'ingredientID': 149, // Onion
        'quantity': 1,
        'unit': 'small',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangId,
        'ingredientID': 152, // Garlic
        'quantity': 4,
        'unit': 'cloves',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangId,
        'ingredientID': 129, // Tomato
        'quantity': 1,
        'unit': 'small',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangId,
        'ingredientID': 237, // Cooking oil
        'quantity': 1,
        'unit': 'tbsp',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangId,
        'ingredientID': 239, // Soy Sauce
        'quantity': 0.25,
        'unit': 'cup',
        'content': null
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
      'quantity': 2,
      'unit': 'pieces',
      'content': '≈300g'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongManokId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'crushed'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongManokId,
      'ingredientID': 234, // Bay leaf
      'quantity': 1,
      'unit': 'leaf',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongManokId,
      'ingredientID': 235, // Peppercorns
      'quantity': 0.5,
      'unit': 'tsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongManokId,
      'ingredientID': 239, // Soy sauce
      'quantity': 2,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongManokId,
      'ingredientID': 236, // Vinegar
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongManokId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tsp',
      'content': null
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
      'quantity': 2,
      'unit': 'cups',
      'content': 'rinsed'
    });
    await db.insert('meal_ingredients', {
      'mealID': bikoId,
      'ingredientID': 243, // Coconut milk
      'quantity': 2,
      'unit': 'cups',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': bikoId,
      'ingredientID': 241, // Brown sugar
      'quantity': 0.75,
      'unit': 'cup',
      'content': null
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
      'quantity': 1,
      'unit': 'cup',
      'content': 'rinsed'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 144, // Sweet potato
      'quantity': 1,
      'unit': 'cup',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 148, // Taro (gabi)
      'quantity': 1,
      'unit': 'cup',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 147, // Purple yam (ube)
      'quantity': 1,
      'unit': 'cup',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 154, // Saba banana
      'quantity': 2,
      'unit': 'pieces',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 175, // Jackfruit
      'quantity': 1,
      'unit': 'cup',
      'content': 'chunks'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 8, // Tapioca pearls
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'cooked'
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 243, // Coconut milk
      'quantity': 4,
      'unit': 'cups',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': binignitId,
      'ingredientID': 241, // Brown sugar
      'quantity': 0.5,
      'unit': 'cup',
      'content': null
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
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sweetened'
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 58, // Nata de coco
      'quantity': 0.5,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 59, // Kaong
      'quantity': 0.5,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 154, // Saba banana
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sweetened'
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 175, // Jackfruit
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sweetened'
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 60, // Macapuno
      'quantity': 0.25,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 61, // Gulaman
      'quantity': 0.25,
      'unit': 'cup',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 62, // Shaved ice
      'quantity': 1,
      'unit': 'glass',
      'content': 'to fill'
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 253, // Evaporated milk
      'quantity': 0.5,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 63, // Ube ice cream
      'quantity': 1,
      'unit': 'scoop',
      'content': 'optional'
    });
    await db.insert('meal_ingredients', {
      'mealID': haloHaloId,
      'ingredientID': 64, // Leche flan
      'quantity': 1,
      'unit': 'slice',
      'content': 'optional'
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
      'quantity': 100,
      'unit': 'g',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 52, // Carrots
      'quantity': 0.33,
      'unit': 'piece',
      'content': 'julienned'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 139, // Broccoli
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'florets'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 115, // Cauliflower
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'florets'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 133, // Bell pepper
      'quantity': 0.5,
      'unit': 'small',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 114, // Cabbage
      'quantity': 0.5,
      'unit': 'small',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 6, // Mushrooms
      'quantity': 0.25,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'small',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 239, // Soy sauce
      'quantity': 2,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 247, // Oyster sauce
      'quantity': 2,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 248, // Cornstarch
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 60, // Chicken broth
      'quantity': 1,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': chopsueyId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tsp',
      'content': null
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
      'quantity': 3,
      'unit': 'cups',
      'content': 'dried, rehydrated'
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 237, // Cooking oil
      'quantity': 2,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 152, // Garlic
      'quantity': 4,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'medium',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 153, // Ginger
      'quantity': 1,
      'unit': 'thumb',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 52, // Pork belly
      'quantity': 100,
      'unit': 'g',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 23, // Shrimp paste
      'quantity': 0.25,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 243, // Coconut milk
      'quantity': 3,
      'unit': 'cups',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': laingId,
      'ingredientID': 250, // Thai chilies
      'quantity': 6,
      'unit': 'pieces',
      'content': 'sliced'
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
      'quantity': 300,
      'unit': 'g',
      'content': 'serving pieces'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 129, // Tomato
      'quantity': 1,
      'unit': 'medium',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 149, // Onion
      'quantity': 0.5,
      'unit': 'piece',
      'content': 'quartered'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 245, // Tamarind
      'quantity': 2,
      'unit': 'tbsp',
      'content': 'seasoning mix'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 117, // Kangkong
      'quantity': 1,
      'unit': 'cup',
      'content': 'leaves'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 148, // Gabi (taro)
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'chunks'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 34, // Radish
      'quantity': 0.25,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 122, // Eggplant
      'quantity': 0.25,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangBaboyId,
      'ingredientID': 246, // Fish sauce
      'quantity': 1,
      'unit': 'tsp',
      'content': 'to taste'
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
      'quantity': 1,
      'unit': 'cup',
      'content': '2-inch lengths'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 127, // Squash
      'quantity': 1,
      'unit': 'cup',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 122, // Eggplant
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 243, // Coconut milk
      'quantity': 1,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'small',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 153, // Ginger
      'quantity': 1,
      'unit': 'thumb',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangGulayId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
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
      'quantity': 2,
      'unit': 'cups',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangKalabasaId,
      'ingredientID': 129, // Tomato
      'quantity': 1,
      'unit': 'small',
      'content': 'diced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangKalabasaId,
      'ingredientID': 149, // Onion
      'quantity': 0.5,
      'unit': 'piece',
      'content': 'diced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangKalabasaId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangKalabasaId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
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
      'quantity': 2,
      'unit': 'medium slices',
      'content': 'cleaned'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 129, // Tomato
      'quantity': 1,
      'unit': 'small',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 149, // Onion
      'quantity': 0.5,
      'unit': 'piece',
      'content': 'quartered'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 245, // Tamarind paste
      'quantity': 1,
      'unit': 'tbsp',
      'content': 'seasoning mix'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 117, // Kangkong
      'quantity': 1,
      'unit': 'cup',
      'content': 'leaves'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 34, // Radish
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 122, // Eggplant
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 132, // Green chili
      'quantity': 1,
      'unit': 'piece',
      'content': 'optional, whole'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangIsdaId,
      'ingredientID': 246, // Fish sauce
      'quantity': 1,
      'unit': 'tsp',
      'content': 'to taste'
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
      'quantity': 250,
      'unit': 'g',
      'content': 'cleaned'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 129, // Tomato
      'quantity': 1,
      'unit': 'piece',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 149, // Onion
      'quantity': 0.5,
      'unit': 'piece',
      'content': 'quartered'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 117, // Kangkong
      'quantity': 1,
      'unit': 'cup',
      'content': 'leaves'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 134, // Sitaw
      'quantity': 0.5,
      'unit': 'cup',
      'content': '2-inch lengths'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 34, // Radish
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 122, // Eggplant
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 245, // Tamarind paste
      'quantity': 1,
      'unit': 'tbsp',
      'content': 'seasoning mix'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 132, // Green chili
      'quantity': 1,
      'unit': 'piece',
      'content': 'optional, whole'
    });
    await db.insert('meal_ingredients', {
      'mealID': sinigangHiponId,
      'ingredientID': 246, // Fish sauce
      'quantity': 1,
      'unit': 'tsp',
      'content': 'to taste'
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
      'quantity': 2,
      'unit': 'medium',
      'content': 'grated and squeezed'
    });
    await db.insert('meal_ingredients', {
      'mealID': tortangSayoteId,
      'ingredientID': 178, // Eggs
      'quantity': 3,
      'unit': 'pieces',
      'content': 'beaten'
    });
    await db.insert('meal_ingredients', {
      'mealID': tortangSayoteId,
      'ingredientID': 152, // Garlic
      'quantity': 2,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': tortangSayoteId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'small',
      'content': 'chopped'
    });
    await db.insert('meal_ingredients', {
      'mealID': tortangSayoteId,
      'ingredientID': 251, // Flour
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': tortangSayoteId,
      'ingredientID': 237, // Cooking oil
      'quantity': 3,
      'unit': 'tbsp',
      'content': 'for frying'
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
      'quantity': 300,
      'unit': 'g',
      'content': 'cleaned'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'small',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 239, // Soy sauce
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 236, // Vinegar
      'quantity': 2,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 233, // Black pepper
      'quantity': 0.5,
      'unit': 'tsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 129, // Tomato
      'quantity': 1,
      'unit': 'small',
      'content': 'optional, sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongPusitId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
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
      'quantity': 500,
      'unit': 'g',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongBaboyId,
      'ingredientID': 239, // Soy sauce
      'quantity': 0.25,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongBaboyId,
      'ingredientID': 236, // Vinegar
      'quantity': 3,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongBaboyId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'crushed'
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongBaboyId,
      'ingredientID': 234, // Bay leaves
      'quantity': 2,
      'unit': 'pieces',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongBaboyId,
      'ingredientID': 235, // Peppercorns
      'quantity': 1,
      'unit': 'tsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': adobongBaboyId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
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
      'quantity': 2,
      'unit': 'pieces',
      'content': 'cleaned'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 243, // Coconut milk
      'quantity': 1,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 127, // Squash
      'quantity': 1,
      'unit': 'cup',
      'content': 'chunks'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 134, // Sitaw
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'lengths'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 131, // Red chili
      'quantity': 1,
      'unit': 'piece',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'piece',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 153, // Ginger
      'quantity': 1,
      'unit': 'tbsp',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangAlimangoId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
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
      'quantity': 4,
      'unit': 'pieces',
      'content': 'peeled'
    });
    await db.insert('meal_ingredients', {
      'mealID': sagingPritoId,
      'ingredientID': 252, // Brown sugar
      'quantity': 3,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': sagingPritoId,
      'ingredientID': 237, // Cooking oil
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'for frying'
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
      'quantity': 2,
      'unit': 'pieces',
      'content': 'cleaned and scored'
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 139, // Carrots
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'julienned'
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 133, // Bell pepper
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'julienned'
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'piece',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 152, // Garlic
      'quantity': 3,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 236, // Vinegar
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 239, // Soy sauce
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 252, // Sugar
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 248, // Cornstarch
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': escabecheId,
      'ingredientID': 237, // Cooking oil
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'for frying'
    });

    // Insert Ginataang Kalabasa
    final ginataangKalabasaId = await db.insert('meals', {
      'mealName': 'Ginataang Kalabasa',
      'price': 60.0,
      'calories': 250,
      'servings': 2,
      'cookingTime': '25 minutes',
      'mealPicture': 'assets/meals/ginataang_kalabasa.webp',
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
      'quantity': 1.5,
      'unit': 'cup',
      'content': 'cubed'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangKalabasaId,
      'ingredientID': 134, // Sitaw
      'quantity': 1,
      'unit': 'cup',
      'content': '2-inch lengths'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangKalabasaId,
      'ingredientID': 243, // Coconut milk
      'quantity': 1,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangKalabasaId,
      'ingredientID': 149, // Onion
      'quantity': 1,
      'unit': 'piece',
      'content': 'sliced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangKalabasaId,
      'ingredientID': 152, // Garlic
      'quantity': 2,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangKalabasaId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': ginataangKalabasaId,
      'ingredientID': 206, // Shrimp
      'quantity': 0.5,
      'unit': 'cup',
      'content': 'optional, peeled'
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
      'quantity': 2,
      'unit': 'cups',
      'content': 'sliced half-moons'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangUpoId,
      'ingredientID': 129, // Tomato
      'quantity': 1,
      'unit': 'small',
      'content': 'diced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangUpoId,
      'ingredientID': 152, // Garlic
      'quantity': 2,
      'unit': 'cloves',
      'content': 'minced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangUpoId,
      'ingredientID': 149, // Onion
      'quantity': 0.5,
      'unit': 'small',
      'content': 'diced'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangUpoId,
      'ingredientID': 25, // Ground pork or shrimp
      'quantity': 0.5,
      'unit': 'cup',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangUpoId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tbsp',
      'content': null
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
      'ingredientID': 178, // Eggs
      'quantity': 2,
      'unit': 'pieces',
      'content': 'beaten'
    });
    await db.insert('meal_ingredients', {
      'mealID': friedEggMalunggayId,
      'ingredientID': 238, // Malunggay
      'quantity': 0.25,
      'unit': 'cup',
      'content': 'leaves'
    });
    await db.insert('meal_ingredients', {
      'mealID': friedEggMalunggayId,
      'ingredientID': 237, // Cooking oil
      'quantity': 1,
      'unit': 'tsp',
      'content': null
    });
    await db.insert('meal_ingredients', {
      'mealID': friedEggMalunggayId,
      'ingredientID': 152, // Garlic bits (optional)
      'quantity': 1,
      'unit': 'clove',
      'content': 'optional, minced'
    });

    final stirfryId = await db.insert('meals', {
        'mealName': 'Stirfry Alugbati',
        'price': 45.0, 
        'calories': 150, 
        'servings': 4,
        'cookingTime': '10 minutes',
        'mealPicture': 'assets/meals/Stir_Fry_Alugbati.jpg',
        'category': 'side dish, vegetable',
        'content': 'Simple, quick stir-fried Indian spinach (Alugbati) leaves sautéed in butter and seasoned with garlic and salt.',
        'instructions': '''
      1. Wash the alugbati leaves, drain, and dry on a piece of cloth. Make sure there is no water left on the leaves to avoid a watery stir-fry.
      2. Heat a pan over medium-high heat. Sauté garlic in butter.
      3. Add the alugbati leaves and stir-fry. Season with salt and pepper to taste.
      4. Serve immediately.
      ''',
        'hasDietaryRestrictions': 'low calorie, low fat (if using minimal butter)',
        'availableFrom': '10:00',
        'availableTo': '14:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': stirfryId,
        'ingredientID': 255, 
        'quantity': 1,
        'unit': 'bunch',
        'content': 'washed, drained, and dried'
      });
      await db.insert('meal_ingredients', {
        'mealID': stirfryId,
        'ingredientID': 152,
        'quantity': 2,
        'unit': 'cloves',
        'content': 'minced or sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': stirfryId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': stirfryId,
        'ingredientID': 22, 
        'quantity': 1,
        'unit': 'tbsp',
        'content': 'for sautéing'
      });
      await db.insert('meal_ingredients', {
        'mealID': stirfryId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'optional, to taste'
      });

      final saladId = await db.insert('meals', {
        'mealName': 'Alugbati Salad',
        'price': 75.0, 
        'calories': 200, 
        'servings': 4,
        'cookingTime': '10 minutes',
        'mealPicture': 'assets/meals/Alugbati_Salad.jpg',
        'category': 'salad, side dish, vegetable',
        'content': 'A refreshing Filipino-style salad featuring Alugbati leaves, ripe tomatoes, onions, and salty egg, dressed with olive oil and calamansi juice.',
        'instructions': '''
      1. Wash the alugbati, tomatoes, and onions. Drain and dry on a piece of cloth. Chop the vegetables and salted egg to your desired size.
      2. For the dressing, mix a teaspoon of extra virgin olive oil with the lemon or calamansi juice.
      3. Toss the chopped vegetables and salted egg with the dressing.
      4. Season with salt to taste. Serve immediately.
      ''',
        'hasDietaryRestrictions': 'low carbohydrate',
        'availableFrom': '11:00',
        'availableTo': '14:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': saladId,
        'ingredientID': 255, 
        'quantity': 1,
        'unit': 'bunch',
        'content': 'washed, drained, and chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': saladId,
        'ingredientID': 125,
        'quantity': 2,
        'unit': 'pieces',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': saladId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'small',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': saladId,
        'ingredientID': 138, 
        'quantity': 1,
        'unit': 'tbsp',
        'content': 'lemon juice or calamansi juice'
      });
      await db.insert('meal_ingredients', {
        'mealID': saladId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final tempuraId = await db.insert('meals', {
        'mealName': 'Tempura Alugbati',
        'price': 80.0, 
        'calories': 350, 
        'servings': 4,
        'cookingTime': '15 minutes',
        'mealPicture': 'assets/meals/Tempura_Alugbati.jpg',
        'category': 'appetizer, side dish, deep-fried',
        'content': 'Crispy Alugbati leaves deep-fried in a traditional, light tempura batter made extra crisp with ice-cold water and cornstarch.',
        'instructions': '''
      1. Wash the alugbati leaves, drain, and dry on a piece of cloth. Dredge the leaves in cornstarch.
      2. For the batter, combine 1 cup cornstarch, salt, pepper, egg, and enough water to achieve a smooth consistency. Add 2–3 ice cubes.
      3. Heat oil in a deep pan. Dip the dredged alugbati leaves into the batter and deep fry for about 1 minute, or until crispy.
      4. Drain excess oil using a strainer lined with a kitchen towel.
      5. Serve immediately.
      ''',
        'hasDietaryRestrictions': 'deep-fried, high oil content',
        'availableFrom': '15:00',
        'availableTo': '18:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': tempuraId,
        'ingredientID': 255, 
        'quantity': 1,
        'unit': 'bunch',
        'content': 'leaves, washed, drained, and dried'
      });
      await db.insert('meal_ingredients', {
        'mealID': tempuraId,
        'ingredientID': 248, 
        'quantity': 1,
        'unit': 'cup',
        'content': 'for the batter, plus extra for dredging'
      });
      await db.insert('meal_ingredients', {
        'mealID': tempuraId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': tempuraId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': tempuraId,
        'ingredientID': 177,
        'quantity': 1,
        'unit': 'medium',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': tempuraId,
        'ingredientID': 237, // Oil
        'quantity': null,
        'unit': null,
        'content': 'for frying'
      });

      final ampalayaId = await db.insert('meals', {
        'mealName': 'Ginisang Ampalaya',
        'price': 90.0, 
        'calories': 152, 
        'servings': 4,
        'cookingTime': '20 minutes',
        'mealPicture': 'assets/meals/Ginisang_Ampalaya.jpg',
        'category': 'main dish, vegetable, stir-fry',
        'content': 'Sautéed bitter melon (ampalaya) with tomatoes and onions, quickly scrambled with eggs for a nutritious Filipino vegetable dish.',
        'instructions': '''
      1. Place the ampalaya in a large bowl.
      2. Add salt and lukewarm water (about 18 oz), then leave for 5 minutes.
      3. Transfer the ampalaya to a cheesecloth and squeeze tightly until all liquid drips out to reduce bitterness.
      4. Heat the pan and add cooking oil.
      5. Sauté the garlic, onion, and tomato.
      6. Add the ampalaya and mix well with the sautéed ingredients.
      7. Season with salt and pepper to taste.
      8. Beat the eggs and pour over the ampalaya; let the eggs cook partially.
      9. Mix the eggs with the other ingredients.
      10. Serve hot. Enjoy!
      ''',
        'hasDietaryRestrictions': 'low carbohydrate, high fiber',
        'availableFrom': '17:00',
        'availableTo': '21:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 152, 
        'quantity': 1,
        'unit': 'tbsp',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 233, 
        'quantity': 0.5,
        'unit': 'tsp',
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 177, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'beaten'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 125, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'sliced or chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tbs',
        'content': null
      });

      final stuffedAmpalayaId = await db.insert('meals', {
        'mealName': 'Stuffed Ampalaya',
        'price': 150.0,
        'calories': 380, 
        'servings': 4,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Stuffed_Ampalaya.jpg',
        'category': 'main dish, baked, pork',
        'content': 'Ampalaya slices stuffed with a savory mixture of ground pork, carrots, and spices, then baked until tender.',
        'instructions': '''
      1. Preheat oven to 375 degrees Fahrenheit.
      2. In a large bowl, combine ground pork, onion, carrots, shredded bread, salt, pepper, garlic powder, paprika, and egg. Mix well. Set aside.
      3. Stuff the mixture into the ampalaya slices.
      4. Grease a baking pan, and arrange the stuffed ampalaya.
      5. Place inside the oven, and bake for 22 to 26 minutes, or until the meat is cooked.
      6. Transfer to a serving plate.
      7. Serve. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'high protein, pork content',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 260, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'halved and deseeded'
      });
      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 40, 
        'quantity': 1,
        'unit': 'lb',
        'content': 'ground pork'
      });
      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 120,
        'quantity': 0.75,
        'unit': 'cup',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 232, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 233, 
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': stuffedAmpalayaId,
        'ingredientID': 177, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'for binding the filling'
      });

      final ampalayaSaladId = await db.insert('meals', {
        'mealName': 'Ampalaya Salad',
        'price': 65.0, 
        'calories': 120, 
        'servings': 3,
        'cookingTime': '1 minute',
        'mealPicture': 'assets/meals/Ampalaya_Salad.jpg',
        'category': 'salad, side dish, vegetable',
        'content': 'A simple, tart, and refreshing Filipino bitter gourd salad featuring a simple dressing and fresh vegetables.',
        'instructions': '''
      1. Rub the salt all over the sliced bitter gourd. Let it sit for 30 minutes.
      2. Rinse quickly under running water to remove the salt, then drain excess liquid.
      3. Combine vinegar, ground black pepper, sugar, and extra salt (if needed) in a bowl. Stir well.
      4. Add the bitter gourd, onion, and tomato into the bowl. Mix thoroughly.
      5. Cover the bowl with cling wrap and refrigerate for about 3 hours.
      6. Serve as a side dish for fried fish. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'low calorie, low fat',
        'availableFrom': '11:00',
        'availableTo': '14:00'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaSaladId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'thinly sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaSaladId,
        'ingredientID': 125, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'diced and seeds removed'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaSaladId,
        'ingredientID': 233,
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaSaladId,
        'ingredientID': 228,
        'quantity': 1,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaSaladId,
        'ingredientID': 232, 
        'quantity': 1,
        'unit': 'tablespoon',
        'content': 'for rubbing'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaSaladId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'extra salt to taste (for dressing)'
      });

      final ampalayaConCarneId = await db.insert('meals', {
        'mealName': 'Ampalaya Con Carne',
        'price': 130.0, 
        'calories': 280, 
        'servings': 3,
        'cookingTime': '15 minutes',
        'mealPicture': 'assets/meals/Ampalaya_Con_Carne.jpg',
        'category': 'main dish, beef, stir-fry',
        'content': 'Tender beef sirloin and crunchy bitter gourd (ampalaya) stir-fried in a savory brown sauce.',
        'instructions': '''
      1. Combine the beef sirloin, ground black pepper, soy sauce, sesame oil, and oyster sauce. Mix well. Add cornstarch and continue mixing until everything is well coated. Marinate for 10 minutes.
      2. Heat oil in a cooking pot. Add the marinated beef slices and cook each side for 30 seconds. Stir-fry the beef for 3 minutes. Set aside.
      3. Sauté the ginger and garlic using the remaining oil. Add onion and cook until it softens.
      4. Add the ampalaya to the pan and cook for 1 minute.
      5. Return the beef to the pan. Add water (0.75 cup), cover, and let it boil. Cook over medium heat for 5 minutes.
      6. Transfer to a serving bowl. Serve!
      ''',
        'hasDietaryRestrictions': 'high protein, low-carb friendly',
        'availableFrom': '17:00',
        'availableTo': '21:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 39, 
        'quantity': 0.5,
        'unit': 'lb',
        'content': 'sliced into thin pieces'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 149,
        'quantity': 1,
        'unit': 'piece',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'for marinade'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 240,
        'quantity': null,
        'unit': null,
        'content': 'for marinade'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 248,
        'quantity': null,
        'unit': null,
        'content': 'for coating beef'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 153, 
        'quantity': null,
        'unit': null,
        'content': 'for sauté'
      });
      await db.insert('meal_ingredients', {
        'mealID': ampalayaConCarneId,
        'ingredientID': 152, 
        'quantity': null,
        'unit': null,
        'content': 'for sauté'
      });

      final sardinasAmpalayaId = await db.insert('meals', {
        'mealName': 'Ginisang Sardinas with Ampalaya',
        'price': 70.0, 
        'calories': 250,
        'servings': 3,
        'cookingTime': '12 minutes',
        'mealPicture': 'assets/meals/Ginisang_Sardinas_with_Ampalaya.jpg',
        'category': 'main dish, fish, stir-fry, budget-friendly',
        'content': 'Sautéed sardines in tomato sauce combined with bitter gourd (ampalaya), garlic, and onion, seasoned with fish sauce.',
        'instructions': '''
      1. Heat oil (3 tablespoons) in a cooking pot.
      2. Sauté crushed garlic (5 cloves) and onion (1 medium) until the garlic starts to turn light brown.
      3. Add the sliced bitter melon (1 medium) and continue to sauté for 2 minutes.
      4. Pour the contents of the large can of sardines in tomato sauce and gently stir.
      5. Add ground black pepper (1/8 teaspoon) and fish sauce (2 teaspoons). Cover and cook on medium heat for 2 to 3 minutes.
      6. Transfer to a serving plate and top with chopped scallions and toasted garlic.
      7. Serve. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'high sodium (due to canned fish/sauce), fish content',
        'availableFrom': '12:00',
        'availableTo': '18:00'
      });

 
      await db.insert('meal_ingredients', {
        'mealID': sardinasAmpalayaId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': sardinasAmpalayaId,
        'ingredientID': 152, 
        'quantity': 5,
        'unit': 'cloves',
        'content': 'crushed'
      });
      await db.insert('meal_ingredients', {
        'mealID': sardinasAmpalayaId,
        'ingredientID': 233, 
        'quantity': 0.125, 
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': sardinasAmpalayaId,
        'ingredientID': 239, 
        'quantity': 2,
        'unit': 'teaspoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': sardinasAmpalayaId,
        'ingredientID': 237,
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });

  
      final atcharaId = await db.insert('meals', {
        'mealName': 'Atchara',
        'price': 180.0, 
        'calories': 174, 
        'servings': 12, 
        'cookingTime': '20 minutes',
        'mealPicture': 'assets/meals/Atchara.jpg',
        'category': 'condiment, side dish, pickled, vegetable',
        'content': 'A traditional Filipino relish made from pickled grated green papaya, carrots, bell peppers, and raisins in a sweet and sour brine.',
        'instructions': '''
      1. Place the julienned papaya in a large bowl and add 1/4 cup salt. Mix until well distributed.
      2. Cover the bowl and refrigerate overnight to dehydrate the papaya (Prep time is actually much longer due to overnight refrigeration).
      3. Place the papaya in a colander or strainer, then rinse with running water.
      4. Put the rinsed papaya inside a cheesecloth (or any clean cloth) and squeeze until all liquid comes out.
      5. Place the papaya back into the large bowl and add the carrots, garlic, ginger, onions, whole peppercorn, bell pepper, and raisins. Mix well.
      6. Heat a saucepan and pour in the vinegar (2 cups). Bring to a boil.
      7. Add the sugar (1 1/3 cups) and 1 1/2 teaspoons salt. Stir until fully dissolved.
      8. Turn off the heat and let the syrup cool until it is safe to handle.
      9. Place the mixed vegetables and spices into a sterilized airtight jar, then pour the cooled syrup over them.
      10. Seal the jar and refrigerate for at least 5 days (one week for best flavor and texture).
      11. Serve cold with fried dishes. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'high sugar, low fat, contains vinegar',
        'availableFrom': '10:00', 
        'availableTo': '20:00'
      });


      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 120, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'julienned'
      });
      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'thinly sliced lengthwise'
      });
      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 152,
        'quantity': 10,
        'unit': 'cloves',
        'content': 'thinly sliced'
      });
     
      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 153,
        'quantity': 1,
        'unit': 'knob',
        'content': 'cut into thin strips'
      });
      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 232, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': 'for dehydrating papaya'
      });
      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 232, 
        'quantity': 1.5,
        'unit': 'teaspoons',
        'content': 'for the brine/syrup'
      });
     
      await db.insert('meal_ingredients', {
        'mealID': atcharaId,
        'ingredientID': 228, 
        'quantity': 1.33, 
        'unit': 'cups',
        'content': null
      });
      

      final baguioBeansId = await db.insert('meals', {
        'mealName': 'Ginisang Baguio Beans with Pork',
        'price': 110.0, 
        'calories': 260, 
        'servings': 4,
        'cookingTime': '20 minutes',
        'mealPicture': 'assets/meals/Ginisang_Baguio_Beans_with_Pork.jpg',
        'category': 'main dish, pork, vegetable, stir-fry',
        'content': 'Sautéed long green beans (Baguio beans) and ground pork seasoned with fish sauce, a classic Filipino staple.',
        'instructions': '''
      1. Heat the oil (2 tablespoons) in a pan.
      2. Sauté the onion (1 medium), garlic (1 teaspoon), and plum tomato (1 medium).
      3. Add the ground pork (1/2 lb.) once the tomato softens. Continue sautéing until the pork turns light to medium brown and is fully cooked.
      4. Add the fish sauce (1 1/2 tablespoons) and ground black pepper (1/4 teaspoon). Stir well.
      5. Add the sliced beans (1 lb.). Toss and continue to sauté for 5 minutes.
      6. Transfer to a serving plate. Serve.
      7. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'high protein, high fiber',
        'availableFrom': '17:00',
        'availableTo': '21:00'
      });

    
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 40, 
        'quantity': 0.5,
        'unit': 'lb',
        'content': 'ground pork'
      });
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 152, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 125, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 239,
        'quantity': 1.5,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 233, 
        'quantity': 0.25,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': baguioBeansId,
        'ingredientID': 237,
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });

      final baconBeansId = await db.insert('meals', {
        'mealName': 'Sauteed Baguio Beans with Bacon',
        'price': 120.0, 
        'calories': 300, 
        'servings': 3,
        'cookingTime': '10 minutes',
        'mealPicture': 'assets/meals/Sauteed_Baguio_Beans_with_Bacon.jpg',
        'category': 'main dish, side dish, pork, vegetable',
        'content': 'Long green beans sautéed with crispy bacon, garlic, and onion, seasoned with soy sauce, salt, and pepper.',
        'instructions': '''
      1. Sauté the bacon (1/4 kilo) in a preheated pan until the fat is rendered or the bacon is crispy.
      2. Add the onion (1 medium) and garlic (2 cloves), and sauté for 2 minutes.
      3. Add the green beans (1/2 kilo) and soy sauce (2 tablespoons), and cook for another 5 minutes.
      4. Season with salt and pepper to taste.
      5. Serve warm.
      ''',
        'hasDietaryRestrictions': 'high fat (bacon), pork content',
        'availableFrom': '17:00',
        'availableTo': '21:00'
 
      });
      await db.insert('meal_ingredients', {
        'mealID': baconBeansId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': baconBeansId,
        'ingredientID': 152, 
        'quantity': 2,
        'unit': 'cloves',
        'content': 'minced or crushed'
      });
      await db.insert('meal_ingredients', {
        'mealID': baconBeansId,
        'ingredientID': 240, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': baconBeansId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': baconBeansId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final cheesyBeansId = await db.insert('meals', {
        'mealName': 'Cheesy Ginisang Baguio Beans',
        'price': 140.0,
        'calories': 320, 
        'servings': 5,
        'cookingTime': '10 minutes',
        'mealPicture': 'assets/meals/Cheesy_Ginisang_Baguio_Beans.jpg',
        'category': 'side dish, vegetable, stir-fry',
        'content': 'Sautéed Baguio beans with garlic, butter, and a hint of sweetness, traditionally finished with cheese for a savory, creamy vegetable dish.',
        'instructions': '''
      1. In a large frying pan over medium heat, sauté garlic in oil (2 tablespoons). Once the garlic lightly browns, add brown sugar (1/2 teaspoon) and stir.
      2. Add Baguio beans (500 grams) to the pan. Crumble in the chicken bouillon cube and mix well. Stir-fry until the beans are evenly green and slightly crunchy.
      3. Season with ground black pepper (to taste) and add butter (2 tablespoons), stirring until melted.
      4. Add grated cheddar cheese (85 grams) and stir until the cheese is evenly distributed.
      5. Serve hot.
      ''',
        'hasDietaryRestrictions': 'vegetarian friendly (if no bouillon/subbed)',
        'availableFrom': '17:00',
        'availableTo': '21:00'
      });

      // Insert Cheesy Ginisang Baguio Beans ingredients
      // NOTE: Cheddar Cheese and Chicken Bouillon Cube are omitted due to missing Ingredient IDs.
      await db.insert('meal_ingredients', {
        'mealID': cheesyBeansId,
        'ingredientID': 237, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': 'for sautéing'
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBeansId,
        'ingredientID': 152, 
        'quantity': 1,
        'unit': 'head',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBeansId,
        'ingredientID': 227, 
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBeansId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBeansId,
        'ingredientID': 22, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });

      final spicyCoconutPorkId = await db.insert('meals', {
        'mealName': 'Ground Pork and Baguio Beans in Spicy Coconut Sauce',
        'price': 160.0,
        'calories': 350, 
        'servings': 4, 
        'cookingTime': '1 hour',
        'mealPicture': 'assets/meals/Ground_Pork_and_Baguio_Beans_in_Spicy_Coconut_Sauce.jpg',
        'category': 'main dish, pork, spicy, coconut',
        'content': 'Ground pork and Baguio beans cooked in a rich and spicy coconut cream sauce with fish sauce and bird\'s eye chili.',
        'instructions': '''
      1. In a saucepan, sauté garlic (2 cloves) in oil. Add ground pork (1/2 kilo) and water (1/2 cup). Simmer until almost all the water has evaporated, about 10–15 minutes.
      2. Add Baguio beans (2 bundles), fish sauce (1 tablespoon), black pepper (to taste), coconut cream (1 cup), and siling labuyo (2 pieces). Simmer until the beans are cooked.
      3. Serve immediately with white rice.
      ''',
        'hasDietaryRestrictions': 'pork content, high fat (coconut cream), spicy',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

   
      await db.insert('meal_ingredients', {
        'mealID': spicyCoconutPorkId,
        'ingredientID': 152, 
        'quantity': 2,
        'unit': 'cloves',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': spicyCoconutPorkId,
        'ingredientID': 40, 
        'quantity': 0.5,
        'unit': 'kilo',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': spicyCoconutPorkId,
        'ingredientID': 239,
        'quantity': 1,
        'unit': 'tablespoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': spicyCoconutPorkId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': spicyCoconutPorkId,
        'ingredientID': 246, 
        'quantity': 1,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': spicyCoconutPorkId,
        'ingredientID': 236, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'chopped'
      });
      // Water (1/2 cup) is omitted as it is a cooking liquid


      final bananaBreadId = await db.insert('meals', {
        'mealName': 'Banana Bread',
        'price': 220.0, 
        'calories': 359, 
        'servings': 6,
        'cookingTime': '1 hour',
        'mealPicture': 'assets/meals/Banana_Bread.jpg',
        'category': 'dessert, snack, baked goods',
        'content': 'A classic, moist banana bread loaf made with mashed ripe bananas, perfect for a snack or dessert.',
        'instructions': '''
      1. Preheat the oven to 350°F (175°C).
      2. In a bowl, combine all dry ingredients: all-purpose flour (1 1/2 cups), granulated white sugar (10 tablespoons), salt (1 teaspoon), and baking soda (1/2 teaspoon). Set aside.
      3. Mash the bananas (2 large ripe) using a fork or potato masher.
      4. Add eggs (2), cooking oil (1/2 cup), and vanilla extract (1 teaspoon) to the mashed bananas. Mix well.
      5. Gradually add the dry ingredients to the banana mixture. Mix until evenly combined.
      6. Grease a loaf pan with cooking oil or melted butter. Pour the batter into the pan.
      7. Bake for about 1 hour. Check the bread at 40 minutes using a toothpick to prevent overcooking.
      8. Remove from the oven and let the bread cool. Slice and arrange on a serving plate.
      9. Serve immediately or refrigerate for later. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'high sugar, contains gluten',
        'availableFrom': '09:00',
        'availableTo': '20:00'
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaBreadId,
        'ingredientID': 121, 
        'quantity': 2,
        'unit': 'large',
        'content': 'ripe, mashed'
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaBreadId,
        'ingredientID': 228, 
        'quantity': 10,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaBreadId,
        'ingredientID': 247, 
        'quantity': 1.5,
        'unit': 'cups',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaBreadId,
        'ingredientID': 177, 
        'quantity': 2,
        'unit': 'pieces',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaBreadId,
        'ingredientID': 237,
        'quantity': 0.5,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaBreadId,
        'ingredientID': 232,
        'quantity': 1,
        'unit': 'teaspoon',
        'content': null
      });
      

      
      final bananaMuffinId = await db.insert('meals', {
        'mealName': 'Banana Muffin',
        'price': 180.0, 
        'calories': 200, 
        'servings': 8,
        'cookingTime': '16 minutes',
        'mealPicture': 'assets/meals/Banana_Muffin.jpg',
        'category': 'dessert, snack, baked goods',
        'content': 'Fluffy and moist banana muffins made with ripe bananas, perfect for breakfast or an afternoon snack.',
        'instructions': '''
      1. Preheat the oven to 350°F (175°C).
      2. Mash the bananas (3 large ripe) and set aside.
      3. In a bowl, combine flour (1 1/3 cups), baking powder, baking soda, and salt (1/2 teaspoon). Mix well with a wire whisk and set aside.
      4. In a large mixing bowl, combine the mashed bananas, melted butter (5 tablespoons), egg (1), vanilla extract, and sugar (12 tablespoons). Mix thoroughly.
      5. Gradually fold in the dry ingredient mixture until the batter is smooth.
      6. Line a muffin pan with paper cups. Scoop the batter into each cup, filling only halfway to prevent overflow.
      7. Bake in the oven for 13–16 minutes.
      8. Remove from the oven and let the muffins cool on a wire rack.
      9. Serve and enjoy!
      ''',
        'hasDietaryRestrictions': 'high sugar, contains gluten, contains dairy (butter)',
        'availableFrom': '09:00',
        'availableTo': '20:00'
      });

    
      await db.insert('meal_ingredients', {
        'mealID': bananaMuffinId,
        'ingredientID': 121, 
        'quantity': 3,
        'unit': 'large',
        'content': 'ripe, mashed'
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaMuffinId,
        'ingredientID': 247, 
        'quantity': 1.33,
        'unit': 'cups',
        'content': 'sifted'
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaMuffinId,
        'ingredientID': 22,
        'quantity': 5,
        'unit': 'tablespoons',
        'content': 'melted'
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaMuffinId,
        'ingredientID': 228, 
        'quantity': 12,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaMuffinId,
        'ingredientID': 177,
        'quantity': 1,
        'unit': 'piece',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': bananaMuffinId,
        'ingredientID': 232, 
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': null
      });

      final chocoChipMuffinId = await db.insert('meals', {
        'mealName': 'Banana Chocolate Chip Muffin',
        'price': 190.0, 
        'calories': 250, 
        'servings': 6,
        'cookingTime': '17 minutes',
        'mealPicture': 'assets/Banana_Choco_Chip_Muffin.jpg',
        'category': 'dessert, snack, baked goods',
        'content': 'Quick and easy muffins made with ripe bananas and chocolate chips, using a pancake mix base for a fast bake.',
        'instructions': '''
      1. Preheat the oven to 400°F (200°C).
      2. In a mixing bowl, beat the egg (1) and gradually add the sugar (1/2 cup). Mix well.
      3. Add the vegetable oil (3 tablespoons) and mashed bananas (2 medium). Mix thoroughly.
      4. Gradually add the pancake mix (2 cups) and continue mixing until all ingredients are well combined.
      5. Fold in the chocolate chips (1/2 cup).
      6. Line a muffin pan with paper cups and scoop the batter into each cup.
      7. Bake in the preheated oven for 14–17 minutes, or until a toothpick inserted comes out clean.
      8. Remove the muffins from the oven and let cool on a wire rack.
      9. Serve and enjoy!
      ''',
        'hasDietaryRestrictions': 'high sugar, contains gluten',
        'availableFrom': '09:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': chocoChipMuffinId,
        'ingredientID': 121, 
        'quantity': 2,
        'unit': 'medium',
        'content': 'ripe, mashed'
      });
      await db.insert('meal_ingredients', {
        'mealID': chocoChipMuffinId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chocoChipMuffinId,
        'ingredientID': 177,
        'quantity': 1,
        'unit': 'piece',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chocoChipMuffinId,
        'ingredientID': 228, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': null
      });

      final darkChocoBananaBreadId = await db.insert('meals', {
        'mealName': 'Dark Chocolate Banana Bread',
        'price': 240.0, 
        'calories': 380,
        'servings': 4,
        'cookingTime': '50 minutes',
        'mealPicture': 'assets/meals/Dark_Chocolate_Banana_Bread.jpg',
        'category': 'dessert, snack, baked goods',
        'content': 'A rich and moist banana bread infused with dark chocolate, offering a decadent twist on a classic recipe.',
        'instructions': '''
      1. Preheat the oven to 350°F (175°C).
      2. Mash the bananas (2 to 3 large ripe) using a fork and set aside.
      3. In a bowl, combine flour (1 1/2 cups), sugar (1 cup), salt (3/4 teaspoon), baking soda (1 teaspoon), and dark chocolate powder (4 tablespoons). Mix well with a wire whisk.
      4. Add the eggs (2), cooking oil (8 tablespoons), and mashed bananas to the dry mixture. Fold until well blended.
      5. Grease a loaf pan and pour the batter into it.
      6. Bake for 50–55 minutes, or until a toothpick inserted in the center comes out clean.
      7. Remove from the oven and let the banana bread cool. Slice and serve.
      8. Share and enjoy!
      ''',
        'hasDietaryRestrictions': 'high sugar, contains gluten',
        'availableFrom': '09:00',
        'availableTo': '20:00'
      });


      await db.insert('meal_ingredients', {
        'mealID': darkChocoBananaBreadId,
        'ingredientID': 121, 
        'quantity': 3,
        'unit': 'large',
        'content': 'ripe, mashed'
      });
      await db.insert('meal_ingredients', {
        'mealID': darkChocoBananaBreadId,
        'ingredientID': 247, 
        'quantity': 1.5,
        'unit': 'cups',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': darkChocoBananaBreadId,
        'ingredientID': 228, 
        'quantity': 1,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': darkChocoBananaBreadId,
        'ingredientID': 232, 
        'quantity': 0.75,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': darkChocoBananaBreadId,
        'ingredientID': 177, 
        'quantity': 2,
        'unit': 'pieces',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': darkChocoBananaBreadId,
        'ingredientID': 237, 
        'quantity': 8,
        'unit': 'tablespoons',
        'content': null
      });


      final kilawingPusoId = await db.insert('meals', {
        'mealName': 'Kilawing Puso ng Saging',
        'price': 95.0, 
        'calories': 180,
        'servings': 3,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Kilawing_Puso_ng_Saging.jpg',
        'category': 'appetizer, side dish, vegetable, pickled',
        'content': 'A savory and slightly tangy Filipino dish featuring banana blossoms (puso ng saging) cooked in vinegar, spices, and fish sauce.',
        'instructions': '''
      1. Soak the chopped banana blossoms (2-3 cups) in the brine (6 cups water, 5 tablespoons salt) for 15–20 minutes. After soaking, squeeze tightly to release the sap and place in a colander to drain. Set aside.
      2. Heat cooking oil (2 tablespoons) in a pan over medium heat. Sauté garlic (1 tablespoon) and onion (1 medium) until fragrant.
      3. Add the banana blossoms and cook for 5 minutes.
      4. Pour in fish sauce (2 tablespoons) and vegetable broth (3/4 cup). Stir and bring to a boil.
      5. Add the vinegar (6 tablespoons), cover, and simmer for 10–15 minutes.
      6. Add the sliced green chili (3 long) and ground black pepper (1/4 teaspoon). Stir and cook for another 5 minutes.
      7. Turn off the heat and transfer to a serving plate. Serve and enjoy!
      ''',
        'hasDietaryRestrictions': 'vegetarian friendly (if no fish sauce/subbed)',
        'availableFrom': '11:00',
        'availableTo': '14:00'
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 152, 
        'quantity': 1,
        'unit': 'tablespoon',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 264, 
        'quantity': 6,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 236, 
        'quantity': 3,
        'unit': 'pieces',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 239, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 233, 
        'quantity': 0.25,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 232, 
        'quantity': 5,
        'unit': 'tablespoons',
        'content': 'for brine'
      });
      await db.insert('meal_ingredients', {
        'mealID': kilawingPusoId,
        'ingredientID': 237, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });

  
      final beefNilagaId = await db.insert('meals', {
        'mealName': 'Beef Nilaga',
        'price': 280.0, 
        'calories': 820, 
        'servings': 4,
        'cookingTime': '1 hour 30 minutes',
        'mealPicture': 'assets/meals/Beef_Nilaga.jpg',
        'category': 'main dish, soup, beef',
        'content': 'A classic Filipino boiled beef soup (nilaga) with tender beef, corn, potatoes, and various leafy vegetables in a clear, flavorful broth.',
        'instructions': '''
      1. Grill the beef neck bones (3 lbs) for 1 1/2 minutes per side. Remove from the grill and set aside.
      2. Heat cooking oil (3 tablespoons) in a pot and sauté crushed garlic (4 cloves) and chopped onion (1) until the onion softens.
      3. Add the grilled beef and sauté for 2 minutes.
      4. Pour in water (6 cups) and bring to a boil. Cover and simmer over low heat until the meat is tender (approx. 1 hour 30 mins). Add more water as needed.
      5. Add the Knorr beef cube and corn (3 cobs). Cover and cook for 8 minutes.
      6. Add the potatoes (2) and cook for 6 minutes.
      7. Add the long green beans (18), cabbage (1/2 head), and bok choy (1 bunch). Continue cooking for 3 minutes.
      8. Season with fish sauce and ground black pepper to taste.
      9. Transfer to a serving bowl. Serve hot and enjoy!
      ''',
        'hasDietaryRestrictions': 'high protein, high calorie',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

      
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 39, 
        'quantity': 3,
        'unit': 'lbs',
        'content': 'neck bones'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 274, 
        'quantity': 18,
        'unit': 'pieces',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 152, 
        'quantity': 4,
        'unit': 'cloves',
        'content': 'crushed'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 239, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefNilagaId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final calderetaId = await db.insert('meals', {
        'mealName': 'Caldereta',
        'price': 350.0, 
        'calories': 10291, 
        'servings': 5,
        'cookingTime': '1 hour 15 minutes',
        'mealPicture': 'assets/meals/Caldereta.jpg',
        'category': 'main dish, beef, stew, spicy',
        'content': 'A rich and hearty Filipino beef stew, often cooked with tomatoes, spices, and various vegetables, traditionally with a spicy kick.',
        'instructions': '''
      1. Combine beef neck bones (3 lbs), beef chuck (2 lbs), and soy sauce (5 tablespoons) in a bowl. Mix well and marinate for 10 minutes.
      2. Heat 2 cups of cooking oil in a wok. Deep-fry the potatoes (3) and carrots (3) until lightly browned. Remove and set aside.
      3. Heat 3 tablespoons of the used oil in a clean wok. Sauté onions (2) for 1 minute.
      4. Add garlic (5 cloves) and continue sautéing until lightly browned.
      5. Add the marinated beef and sauté until the outer layer starts to turn light brown (about 3–5 minutes).
      6. Pour in tomato sauce (8 ounces) and water (4 cups). Cover and bring to a boil.
      7. Reduce heat to simmer and cook for 40 minutes.
      8. Add tomato paste (2 tablespoons) and continue simmering for 20–35 minutes, or until the beef is tender. Stir occasionally and add water if needed.
      9. Add beef powder (2 teaspoons), liver spread (1/4 cup), and peanut butter (3 tablespoons). Stir well.
      10. Add green olives (5 ounces) and bell peppers (2 red, 2 green). Cook for 3 minutes.
      11. Season with Maggi Magic Sarap (8 grams) and ground black pepper (to taste). Stir to combine.
      12. Return the fried potatoes and carrots to the wok and toss.
      13. Add cheddar cheese (2 ounces) and cook for 2–3 minutes until melted and well combined.
      14. Transfer to a serving bowl and serve with rice. Enjoy!
      ''',
        'hasDietaryRestrictions': 'high calorie, beef content, contains peanuts (peanut butter)',
        'availableFrom': '18:00',
        'availableTo': '23:00'
      });

      
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 39, 
        'quantity': 5,
        'unit': 'lbs', 
        'content': 'neck bones and chuck, cubed'
      });
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 149,
        'quantity': 2,
        'unit': 'pieces',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 152, 
        'quantity': 5,
        'unit': 'cloves',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 240, 
        'quantity': 5,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 125, 
        'quantity': 8,
        'unit': 'ounces',
        'content': 'tomato sauce'
      });
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': calderetaId,
        'ingredientID': 237, 
        'quantity': 2, 
        'unit': 'cups',
        'content': null
      });

      final beefChopSueyId = await db.insert('meals', {
        'mealName': 'Beef Chop Suey',
        'price': 250.0, 
        'calories': 373, 
        'servings': 5,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Beef_Chopsuey.webp',
        'category': 'main dish, beef, vegetable, stir-fry',
        'content': 'A Filipino-style stir-fry featuring tender beef slices and a medley of fresh, partially cooked vegetables seasoned with soy sauce and black pepper.',
        'instructions': '''
      1. Combine the sliced beef (1 lb top sirloin) with soy sauce, oyster sauce, baking soda, cornstarch, ground black pepper, and 1 tablespoon oil. Mix well and set aside for 12 minutes.
      2. Partially cook the vegetables: Heat 2 tablespoons of oil in a wide pan. Stir-fry cabbage (1/2 head), snap peas (2 cups), carrot (2), and bell pepper (1) for 1 minute. Sprinkle some salt, pour in 1/4 cup beef stock, cover, and let boil. Steam for 1 minute, then remove the cover and let remaining liquid evaporate. Set vegetables aside.
      3. Heat the remaining oil (1 tablespoon) in the same pan. Stir-fry the marinated beef until the outside turns light brown.
      4. Add minced garlic (5 cloves), the white part of the green onion (3 stems), and sliced yellow onion (1). Continue stir-frying until the onion softens.
      5. Add the stir-fried vegetables and toss to combine evenly.
      6. Pour in 1 tablespoon soy sauce and the remaining beef stock (1/4 cup). Stir and continue cooking until the sauce thickens.
      7. Season with Maggi Magic Sarap as needed.
      8. Transfer to a serving plate. Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'high protein',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

     
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 39, 
        'quantity': 1,
        'unit': 'lb',
        'content': 'sliced into thin pieces'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 152,
        'quantity': 5,
        'unit': 'cloves',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'sliced thinly'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 240, 
        'quantity': 2,
        'unit': 'tablespoons', 
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons', 
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefChopSueyId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'for seasoning vegetables'
      });


      final garlicPepperBeefId = await db.insert('meals', {
        'mealName': 'Garlic Pepper Beef in Mushroom Gravy',
        'price': 295.0,
        'calories': 420, 
        'servings': 4,
        'cookingTime': '25 minutes',
        'mealPicture': 'assets/meals/Garlic_Pepper_Beef_in_Mushroom_Gravy.jpg',
        'category': 'main dish, beef, stir-fry, savory',
        'content': 'Thinly sliced beef marinated and cooked in a rich, peppery gravy with garlic and mushrooms, served hot.',
        'instructions': '''
      1. Heat cooking oil (1/4 cup) in a large skillet over medium heat and add the minced garlic (1 1/2 heads). Cook until golden brown and crispy, about 2–3 minutes. Separate the crispy garlic from the oil and set aside for garnish.
      2. Reduce the garlic oil to 2 tablespoons in the pan. Increase heat to medium-high and sauté the sliced beef (1 1/2 lbs sirloin) until browned on all sides, about 4–5 minutes.
      3. Pour in soy sauce (2 tablespoons) and oyster sauce (3 tablespoons), then season with salt (1/4 teaspoon), ground black pepper (1/2 teaspoon), and half of the toasted garlic. Stir and cook for 1 minute. Remove beef from the pan and set aside.
      4. In the same pan, melt butter (3 tablespoons) over medium heat. Add all-purpose flour (4 tablespoons) and whisk continuously until the mixture turns golden brown, about 2–3 minutes.
      5. Gradually pour in beef broth (1 3/4 cups) while whisking constantly to prevent lumps. Add the sliced mushrooms (14 oz) and simmer until the sauce thickens, about 3–4 minutes. Season with onion powder, garlic powder, salt, and ground black pepper (1/8 teaspoon).
      6. Return the cooked beef to the pan and toss until well combined with the mushroom gravy. Cook for 2–3 minutes to heat through.
      7. Transfer to a serving plate, top with the remaining crispy garlic, and serve immediately.
      ''',
        'hasDietaryRestrictions': 'high protein, high fat (gravy)',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 39,
        'quantity': 1.5,
        'unit': 'lbs',
        'content': 'thinly sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 152,
        'quantity': 1.5,
        'unit': 'heads',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 240, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 233, 
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': 'for meat'
      });
      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 232, 
        'quantity': 0.25, 
        'unit': 'teaspoon',
        'content': 'for meat'
      });
      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 237, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': garlicPepperBeefId,
        'ingredientID': 247, 
        'quantity': 4,
        'unit': 'tablespoons',
        'content': 'for gravy'
      });

      final creamyBeefMushroomId = await db.insert('meals', {
        'mealName': 'Creamy Beef with Mushroom',
        'price': 275.0, 
        'calories': 422, 
        'servings': 4,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Creamy_Beef_with_Mushroom.webp',
        'category': 'main dish, beef, creamy, savory',
        'content': 'Tender, thinly sliced beef and mushrooms in a rich, creamy sauce, typically served over rice.',
        'instructions': '''
      1. Melt butter (3 tablespoons) in a pan and add cooking oil (1 tablespoon).
      2. Sauté sliced garlic (1 head) until browned, then add diced onion (1) and cook until softened.
      3. Add the beef (2 lbs sirloin) and cook, stirring, until the sides turn brown.
      4. Pour in 1 cup water, cover, and simmer for 35 minutes.
      5. Add button mushrooms (8 ounces) and stir.
      6. In a bowl, combine the remaining 1 cup water with Knorr Cream of Mushroom Soup (62 grams) and mix well. Pour the mixture into the pan and bring to a boil.
      7. Continue cooking uncovered on low heat for 10–15 minutes.
      8. Season with salt and ground black pepper to taste.
      9. Top with chopped parsley (1 tablespoon) and serve warm with rice. Enjoy!
      ''',
        'hasDietaryRestrictions': 'high protein, dairy content (from soup/butter)',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

    
      await db.insert('meal_ingredients', {
        'mealID': creamyBeefMushroomId,
        'ingredientID': 39,
        'quantity': 2,
        'unit': 'lbs',
        'content': 'sliced thinly'
      });
      await db.insert('meal_ingredients', {
        'mealID': creamyBeefMushroomId,
        'ingredientID': 152, 
        'quantity': 1,
        'unit': 'head',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': creamyBeefMushroomId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': creamyBeefMushroomId,
        'ingredientID': 237, 
        'quantity': 1,
        'unit': 'tablespoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': creamyBeefMushroomId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': creamyBeefMushroomId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
     
      final steamedBroccoliId = await db.insert('meals', {
        'mealName': 'Steam Broccoli',
        'price': 60.0, 
        'calories': 55, 
        'servings': 2,
        'cookingTime': '5 minutes',
        'mealPicture': 'assets/meals/Steamed_Broccoli.jpg',
        'category': 'side dish, vegetable, healthy, low calorie',
        'content': 'Fresh or frozen broccoli lightly steamed and ready to be seasoned to preference with salt, pepper, or butter.',
        'instructions': '''
      1. Add 1–2 inches of water (1 1/2 cups) to a medium pot and bring to a boil over high heat.
      2. Arrange the broccoli chunks (2 cups) in a steamer basket and suspend it over the boiling water. Cover with a lid and steam for up to 5 minutes, adjusting for desired tenderness.
      3. When the broccoli turns bright green, remove the steamer basket from heat and let it cool slightly.
      4. Season with salt, pepper, butter, or drizzle with salad dressing as desired. Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'low carb, low fat, vegetarian, vegan (if unbuttered)',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': steamedBroccoliId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': steamedBroccoliId,
        'ingredientID': 233,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': steamedBroccoliId,
        'ingredientID': 22, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final cheesyBroccoliSoupId = await db.insert('meals', {
        'mealName': 'Cheesy Broccoli Soup',
        'price': 150.0, 
        'calories': 380, 
        'servings': 2,
        'cookingTime': '20 minutes',
        'mealPicture': 'assets/meals/Cheesy_Broccoli_Soup.jpg',
        'category': 'soup, creamy, vegetable',
        'content': 'A thick and comforting soup featuring melted cheese, chopped vegetables, and a creamy milk base.',
        'instructions': '''
      1. Heat a cooking pan and melt the butter (2 tablespoons).
      2. Add the chopped onion (1/4 cup) and cook until soft.
      3. Stir in the all-purpose flour (2 tablespoons) and cook for a minute.
      4. Pour in the milk (2 3/4 cups) and bring to a boil. Simmer for 2 minutes over medium heat.
      5. Add ground black pepper (1/8 teaspoon) and stir.
      6. Add the broccoli (8 ounces) and cook for 3–5 minutes.
      7. Stir in the sharp cheddar cheese (3/4 cups) until it melts.
      8. Turn off the heat and transfer to a serving bowl. Serve hot and enjoy.
      ''',
        'hasDietaryRestrictions': 'contains dairy, contains gluten (flour)',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': cheesyBroccoliSoupId,
        'ingredientID': 22, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBroccoliSoupId,
        'ingredientID': 149, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBroccoliSoupId,
        'ingredientID': 233, 
        'quantity': 0.125,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBroccoliSoupId,
        'ingredientID': 247, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cheesyBroccoliSoupId,
        'ingredientID': 223, 
        'quantity': 2.75,
        'unit': 'cups',
        'content': null
      });

    
      final roastedBroccoliId = await db.insert('meals', {
        'mealName': 'Oven Roasted Broccoli',
        'price': 70.0, 
        'calories': 34, 
        'servings': 3,
        'cookingTime': '9 minutes',
        'mealPicture': 'assets/meals/Oven_Roasted_Broccoli.jpg',
        'category': 'side dish, vegetable, healthy, roasted',
        'content': 'Broccoli florets tossed with oil and seasonings, then roasted until tender-crisp with slightly browned edges.',
        'instructions': '''
      1. Preheat the oven to broil (about 510°F).
      2. In a medium bowl, combine broccoli florets (1/2 lb), salt (1/2 teaspoon), and garlic powder (1/2 teaspoon). Toss to mix.
      3. Pour in olive oil (1 tablespoon) and toss again until the florets are coated evenly.
      4. Arrange the florets on a baking tray.
      5. Roast in the oven for 6–9 minutes, or until the edges start to brown.
      6. Remove from the oven and transfer to a serving plate. Serve warm as a side dish.
      ''',
        'hasDietaryRestrictions': 'low calorie, low carb, vegetarian, vegan',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

    
      await db.insert('meal_ingredients', {
        'mealID': roastedBroccoliId,
        'ingredientID': 232, 
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': null
      });
     
      await db.insert('meal_ingredients', {
        'mealID': roastedBroccoliId,
        'ingredientID': 237,
        'quantity': 1,
        'unit': 'tablespoon',
        'content': 'extra-virgin'
      });
   


      final tofuBroccoliStirFryId = await db.insert('meals', {
        'mealName': 'Tofu and Broccoli Stir fry',
        'price': 180.0, 
        'calories': 320, 
        'servings': 4,
        'cookingTime': '18 minutes',
        'mealPicture': 'assets/meals/Tofu_and_Broccoli_Stir_Fry.jpg',
        'category': 'main dish, vegetarian, stir-fry, Asian',
        'content': 'A quick and healthy stir-fry combining crispy tofu and fresh broccoli in a savory sauce.',
        'instructions': '''
      1. Heat a pan and add 4 tablespoons of cooking oil (6 tablespoons total used).
      2. Fry the tofu slices (8 oz extra firm) until crisp on both sides, about 8–10 minutes per side.
      3. Remove the tofu from the pan, let cool, and slice into smaller rectangles. Set aside.
      4. In a clean pan, heat the remaining oil (2 tablespoons).
      5. Sauté garlic (1 teaspoon), ginger (1 teaspoon), and onion (1 medium) until fragrant.
      6. Add the fried tofu slices and oyster sauce (2 tablespoons). Stir to combine.
      7. Add the broccoli florets (3 cups) and cook for 5–8 minutes, stirring occasionally.
      8. Season with salt and pepper to taste.
      9. Transfer to a serving plate and serve with rice. Enjoy.
      ''',
        'hasDietaryRestrictions': 'vegetarian, high protein',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });


      await db.insert('meal_ingredients', {
        'mealID': tofuBroccoliStirFryId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': tofuBroccoliStirFryId,
        'ingredientID': 152, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': tofuBroccoliStirFryId,
        'ingredientID': 237, 
        'quantity': 6,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': tofuBroccoliStirFryId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': tofuBroccoliStirFryId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });


      final beefBroccoliId = await db.insert('meals', {
        'mealName': 'Beef with Broccoli',
        'price': 260.0, 
        'calories': 380, 
        'servings': 4,
        'cookingTime': '18 minutes',
        'mealPicture': 'assets/meals/Beef_with_Broccoli.jpg',
        'category': 'main dish, beef, vegetable, stir-fry',
        'content': 'A classic savory stir-fry dish featuring tender beef slices and crisp broccoli florets, coated in a seasoned sauce.',
        'instructions': '''
      1. In a bowl, combine beef (1 lb), oyster sauce (1/4 cup), Knorr Liquid Seasoning (1 tablespoon), sesame oil (1/2 teaspoon), cooking wine (3 tablespoons), and sugar (1 teaspoon). Mix well and marinate for 15 minutes. Add cornstarch (1 tablespoon) and mix until evenly coated. Set aside.
      2. Heat 2 tablespoons of cooking oil in a pan. Sauté ginger (2 teaspoons) and garlic (2 cloves), then add broccoli (2 cups) and stir-fry for 1–2 minutes. Remove broccoli from the pan and set aside.
      3. Add the remaining oil (2 tablespoons) to the pan. Stir-fry the marinated beef until browned. Add water (1/2 to 3/4 cups) if needed to tenderize the beef, letting it boil and evaporate. Season with salt and ground black pepper.
      4. Return the cooked broccoli to the pan with the beef and stir-fry for 3 minutes.
      5. Transfer to a serving plate and serve.
      ''',
        'hasDietaryRestrictions': 'high protein',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': beefBroccoliId,
        'ingredientID': 39, 
        'quantity': 1,
        'unit': 'lb',
        'content': 'sliced into thin pieces'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefBroccoliId,
        'ingredientID': 152, 
        'quantity': 2,
        'unit': 'cloves',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefBroccoliId,
        'ingredientID': 237, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': beefBroccoliId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefBroccoliId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': beefBroccoliId,
        'ingredientID': 228, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': null
      });

 
      final cabbageSoupId = await db.insert('meals', {
        'mealName': 'Cabbage Soup',
        'price': 85.0, 
        'calories': 120, 
        'servings': 3,
        'cookingTime': '20 minutes',
        'mealPicture': 'assets/meals/Cabbage_Soup.jpg',
        'category': 'soup, vegetable, healthy',
        'content': 'A light and savory soup featuring cored and chopped cabbage cooked in a broth with tomato sauce and simple aromatics.',
        'instructions': '''
      1. Heat olive oil (2 teaspoons) in a cooking pot and sauté onion (1 medium) and garlic (2 teaspoons) until fragrant.
      2. Add the chopped cabbage (1 medium head) and cook for 1 minute.
      3. Pour in the tomato sauce (15 ounces) and chicken broth (3 cups). Stir and bring to a boil.
      4. Simmer for 5–7 minutes until the cabbage is tender.
      5. Turn off the heat and transfer to a serving bowl. Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'low calorie, vegetarian, vegan',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': cabbageSoupId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': cabbageSoupId,
        'ingredientID': 125, 
        'quantity': 15,
        'unit': 'ounces',
        'content': 'organic tomato sauce'
      });
      await db.insert('meal_ingredients', {
        'mealID': cabbageSoupId,
        'ingredientID': 231, 
        'quantity': 3,
        'unit': 'cups',
        'content': 'low sodium'
      });
      await db.insert('meal_ingredients', {
        'mealID': cabbageSoupId,
        'ingredientID': 152,
        'quantity': 2,
        'unit': 'teaspoons',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': cabbageSoupId,
        'ingredientID': 237, 
        'quantity': 2,
        'unit': 'teaspoons',
        'content': 'extra virgin olive oil'
      });


      final crispyCabbageRollsId = await db.insert('meals', {
        'mealName': 'Crispy Cabbage Rolls',
        'price': 220.0, 
        'calories': 350, 
        'servings': 6,
        'cookingTime': '35 minutes',
        'mealPicture': 'assets/meals/Crispy_Cabbage_Rolls.jpg',
        'category': 'main dish, pork, savory, fried',
        'content': 'Crispy deep-fried rolls filled with seasoned ground pork, rice, vegetables, and wrapped in boiled Napa cabbage leaves.',
        'instructions': '''
      1. Boil 4 cups of water in a pot with 1 teaspoon salt. Add the Napa cabbage (12 leaves) and boil for 1 minute. Submerge the cabbage in ice-cold water (3 cups) until cooled. Remove and dry. Set aside.
      2. Heat 3 tablespoons of cooking oil in a pan. Sauté chopped garlic (5 cloves) until lightly browned. Add chopped onion (1) and cook until softened. Add ground pork (1 lb) and cook until lightly browned. Add Knorr Pork Cube (1) and cook for 2 minutes. Season with salt and black pepper. Transfer to a large bowl and let cool.
      3. Mix in minced carrot (1/2 cup), green onion (1/2 cup), egg (1), all-purpose flour (5 tablespoons), soy sauce (2 tablespoons), and sesame oil (2 teaspoons) with the cooled meat.
      4. Scoop 3 tablespoons of meat mixture onto a cabbage leaf. Fold both sides inward and roll to cover the filling. Secure with a toothpick.
      5. Heat cooking oil (1 cup) in a pan. Dredge the cabbage rolls in flour (1/2 cup), dip in beaten egg (2), and coat with panko breadcrumbs (1 1/2 cups). Fry until golden brown on all sides. Remove and drain on paper towels or a wire rack.
      6. Slice cabbage rolls into bite-sized pieces. Serve with your favorite dipping sauce and enjoy.
      ''',
        'hasDietaryRestrictions': 'contains gluten, high sodium, high fat',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

    
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 232, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': 'for boiling cabbage'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 247, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': 'for dredging'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 177, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'beaten, for dredging'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 237,
        'quantity': 1.15, 
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 247, 
        'quantity': 5,
        'unit': 'tablespoons',
        'content': 'for filling'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 177, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'for filling'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 33, 
        'quantity': 1,
        'unit': 'lb',
        'content': 'ground'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 149,
        'quantity': 1,
        'unit': 'piece',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 152, 
        'quantity': 5,
        'unit': 'cloves',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 240, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 233,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCabbageRollsId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final cornedBeefCabbageId = await db.insert('meals', {
        'mealName': 'Cabbage with Corned beef and Potato',
        'price': 180.0, 
        'calories': 450, 
        'servings': 3,
        'cookingTime': '18 minutes',
        'mealPicture': 'assets/meals/Cabbage_with_Corned_Beef_and_Potato.jpg',
        'category': 'main dish, stew, beef, comfort food',
        'content': 'A simple, savory stew of canned corned beef, cabbage, and potatoes cooked in a flavorful broth with aromatics.',
        'instructions': '''
      1. Heat oil (3 tablespoons) in a pot.
      2. Sauté crushed garlic (4 cloves) and chopped onion (1 medium) until fragrant.
      3. Add corned beef (1 12-oz can) and sauté for 3 minutes.
      4. Pour in beef broth (2 cups) and bring to a boil.
      5. Add potato (1 large) and cabbage (1/2 small), cover, and cook over medium heat for 8–10 minutes.
      6. Stir in parsley (2 tablespoons), salt, and black pepper to taste. Transfer to a serving bowl and serve.
      ''',
        'hasDietaryRestrictions': 'high sodium (corned beef), high fat',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': cornedBeefCabbageId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': cornedBeefCabbageId,
        'ingredientID': 152,
        'quantity': 4,
        'unit': 'cloves',
        'content': 'crushed'
      });
      await db.insert('meal_ingredients', {
        'mealID': cornedBeefCabbageId,
        'ingredientID': 230, 
        'quantity': 2,
        'unit': 'cups',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cornedBeefCabbageId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cornedBeefCabbageId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': cornedBeefCabbageId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final ginisangRepolyoId = await db.insert('meals', {
        'mealName': 'Ginisang Repolyo',
        'price': 160.0, 
        'calories': 280, 
        'servings': 4,
        'cookingTime': '25 minutes',
        'mealPicture': 'assets/meals/Ginisang_Repolyo.webp',
        'category': 'main dish, side dish, pork, vegetable, stir-fry',
        'content': 'A simple Filipino dish of stir-fried cabbage (repolyo) with ground or sliced pork and aromatics in a light broth.',
        'instructions': '''
      1. Heat cooking oil (3 tablespoons) in a pan.
      2. Sauté crushed and minced garlic (4 cloves) and sliced onion (1 medium) until fragrant.
      3. Add pork (4 ounces, sliced) and cook for 5 minutes or until medium brown.
      4. Pour in half of the beef broth (1 cup total), bring to a boil, and simmer until the liquid evaporates.
      5. Add cabbage (1 head, chopped) and cook for 1–2 minutes.
      6. Add red bell pepper (1, sliced) and stir-fry for 1 more minute.
      7. Season with salt and pepper.
      8. Pour in the remaining beef broth, bring to a boil, and stir.
      9. Transfer to a serving bowl and serve.
      ''',
        'hasDietaryRestrictions': 'high vegetable content',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

    
      await db.insert('meal_ingredients', {
        'mealID': ginisangRepolyoId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangRepolyoId,
        'ingredientID': 152, 
        'quantity': 4,
        'unit': 'cloves',
        'content': 'crushed and minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangRepolyoId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangRepolyoId,
        'ingredientID': 230, 
        'quantity': 1,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangRepolyoId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': ginisangRepolyoId,
        'ingredientID': 233,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final chopSueyId = await db.insert('meals', {
        'mealName': 'Chop Suey',
        'price': 240.0, 
        'calories': 350,
        'servings': 4,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Chop_Suey.jpg',
        'category': 'main dish, stir-fry, vegetable, meat',
        'content': 'A Filipino-style mixed vegetable and meat stir-fry, combining shrimp, pork, and chicken with a variety of vegetables in a thick, savory sauce.',
        'instructions': '''
      1. Heat oil (3 tablespoons) in a wok or pan.
      2. Pan-fry shrimp (7 pieces) for 1 minute per side, then remove and set aside.
      3. Sauté sliced onion (1 yellow) and crushed garlic (4 cloves) until onion softens.
      4. Add pork (3 ounces) and chicken (3 ounces boneless); stir-fry until lightly browned.
      5. Add soy sauce (1/4 cup) and oyster sauce (1 1/2 tablespoons), stir to combine.
      6. Pour in water (3/4 cup), bring to a boil, cover, and cook over medium heat for 15 minutes.
      7. Add cauliflower (1 1/2 cups), carrots (1), bell peppers (1 red, 1 green), snow peas (15 pieces), and baby corn (8 pieces); stir to combine.
      8. Add cabbage (1 1/2 cups), toss, cover, and cook for 5–7 minutes.
      9. Return shrimp to the pan, add ground black pepper (1/4 teaspoon), quail eggs (12), and cornstarch mixture (1 tablespoon cornstarch diluted in 1/2 cup water); toss until sauce thickens.
      10. Transfer to a serving plate and serve.
      ''',
        'hasDietaryRestrictions': 'contains shellfish (shrimp), contains gluten (soy sauce)',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

      
      await db.insert('meal_ingredients', {
        'mealID': chopSueyId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'sliced'
      });
      await db.insert('meal_ingredients', {
        'mealID': chopSueyId,
        'ingredientID': 152, 
        'quantity': 4,
        'unit': 'cloves',
        'content': 'crushed'
      });
      await db.insert('meal_ingredients', {
        'mealID': chopSueyId,
        'ingredientID': 240, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chopSueyId,
        'ingredientID': 233, 
        'quantity': 0.25,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chopSueyId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
  
      final cassavaCakeId = await db.insert('meals', {
        'mealName': 'Cassava Cake',
        'price': 320.0,
        'calories': 550,
        'servings': 6,
        'cookingTime': '1 hour',
        'mealPicture': 'assets/meals/Cassava_Cake.webp',
        'category': 'dessert, cake, Filipino, baked',
        'content': 'A traditional Filipino moist cake made from grated cassava, coconut milk, and condensed milk, topped with a creamy custard.',
        'instructions': '''
      1. In a mixing bowl, combine grated cassava (2 lbs), melted butter (1/4 cup), 1/2 cup condensed milk, evaporated milk (6 oz), 6 tablespoons grated cheddar cheese, granulated white sugar (14 tablespoons), and 2 eggs (total 3 eggs needed). Mix thoroughly.
      2. Add 2 cups coconut milk to the mixture and stir again.
      3. Grease a baking tray and pour in the batter. Preheat oven to 350°F for 10 minutes. Bake the batter for 1 hour. Remove from oven and set aside.
      4. Prepare the topping by combining flour (2 tablespoons) and sugar (2 tablespoons) in a heated saucepan.
      5. Pour in 1/2 cup condensed milk and mix thoroughly.
      6. Add 2 tablespoons grated cheddar cheese while stirring constantly.
      7. Pour in 2 cups coconut milk and stir for 10 minutes.
      8. Spread the topping evenly over the baked cassava batter.
      9. Separate the yolk from the remaining egg (1 yolk) and use the egg white to glaze the topping with a basting brush.
      10. Broil the cassava cake until the topping turns light brown.
      11. Garnish with extra grated cheese. Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'contains dairy, contains egg, high sugar',
        'availableFrom': '09:00',
        'availableTo': '21:00'
      });

      
      await db.insert('meal_ingredients', {
        'mealID': cassavaCakeId,
        'ingredientID': 214, 
        'quantity': 4, 
        'unit': 'cups',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cassavaCakeId,
        'ingredientID': 177,
        'quantity': 3,
        'unit': 'pieces',
        'content': '2 for batter, 1 for topping'
      });
      await db.insert('meal_ingredients', {
        'mealID': cassavaCakeId,
        'ingredientID': 22, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': 'melted'
      });
      await db.insert('meal_ingredients', {
        'mealID': cassavaCakeId,
        'ingredientID': 228, 
        'quantity': 16, 
        'unit': 'tablespoons',
        'content': null
      });
  
      await db.insert('meal_ingredients', {
        'mealID': cassavaCakeId,
        'ingredientID': 247,
        'quantity': 2,
        'unit': 'tablespoons',
        'content': 'for topping'
      });

      final cassavaSumanId = await db.insert('meals', {
        'mealName': 'Cassava Suman',
        'price': 150.0, 
        'calories': 380,
        'servings': 6,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Cassava_Suman.jpg',
        'category': 'dessert, snack, Filipino, steamed',
        'content': 'A Filipino delicacy made from grated cassava, brown sugar, and coconut cream, steamed in banana leaves to create a sweet, sticky cake.',
        'instructions': '''
      1. In a large mixing bowl, combine grated cassava (2 lbs) and brown sugar (1 1/2 cups). Fold gently until well distributed.
      2. Add coconut cream (1/2 cup) and stir until fully incorporated.
      3. Scoop about 1/2 cup of mixture and place on one side of a banana leaf (cut into 12 x 6 inch pieces). Shape into a cylinder about 4–5 inches long.
      4. Roll the banana leaf tightly around the mixture, folding the top and bottom inward to secure.
      5. Boil 5–6 cups of water in a steamer.
      6. Arrange the wrapped cassava suman in the steamer and steam for 30–35 minutes, or until firm.
      7. Remove from steamer and allow to cool. Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'vegetarian, high sugar, high carb',
        'availableFrom': '10:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': cassavaSumanId,
        'ingredientID': 229, 
        'quantity': 1.5,
        'unit': 'cups',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cassavaSumanId,
        'ingredientID': 214, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': 'coconut cream or milk'
      });

      final steamedCassavaCakeId = await db.insert('meals', {
        'mealName': 'Steamed Cassava Cake',
        'price': 280.0, 
        'calories': 520, 
        'servings': 6,
        'cookingTime': '45 minutes',
        'mealPicture': 'assets/meals/Steamed_Cassava_Cake.jpg',
        'category': 'dessert, cake, Filipino, steamed',
        'content': 'A sweet and dense cake made primarily from cassava and coconut milk, steamed until cooked, and usually topped with cheese.',
        'instructions': '''
      1. Pour water (5 cups) into a cooking pot and bring to a boil.
      2. In a large bowl, combine grated cassava (24 oz), coconut milk (1 cup), melted butter (6 tablespoons), eggs (2), and condensed milk (1 can). Mix well using a whisk.
      3. Pour the cassava mixture into individual molds. Arrange the molds in a steamer.
      4. Steam for 45 minutes or until the cassava cake is cooked through.
      5. Remove the molds from the steamer and let cool.
      6. Gently remove the cassava cake from the molds and arrange on a plate.
      7. Top with shredded quick-melt or sharp cheddar cheese (1/2 cup). Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'contains dairy, contains egg, high sugar',
        'availableFrom': '10:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': steamedCassavaCakeId,
        'ingredientID': 214, 
        'quantity': 1,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': steamedCassavaCakeId,
        'ingredientID': 177, 
        'quantity': 2,
        'unit': 'pieces',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': steamedCassavaCakeId,
        'ingredientID': 22,
        'quantity': 6,
        'unit': 'tablespoons',
        'content': 'melted'
      });

      final roastedCauliflowerId = await db.insert('meals', {
        'mealName': 'Roasted Cauliflower',
        'price': 100.0, 
        'calories': 180, 
        'servings': 4,
        'cookingTime': '25 minutes',
        'mealPicture': 'assets/meals/Roasted_Cauliflower.jpg',
        'category': 'side dish, vegetable, healthy, roasted',
        'content': 'Cauliflower florets tossed with garlic and oil, roasted until tender, and finished with a sprinkle of Parmesan cheese.',
        'instructions': '''
      1. In a large mixing bowl, combine cauliflower florets (1 head), olive oil (1/4 cup), minced garlic (2 tablespoons), salt, parsley, and ground black pepper. Toss until evenly coated.
      2. Preheat oven to 425°F.
      3. Transfer cauliflower to a greased baking tray and bake for 25 minutes, stirring each floret halfway through.
      4. Sprinkle Parmesan cheese (1/2 cup) on top and roast for an additional 4 minutes.
      5. Remove from oven and transfer to a serving plate. Serve and enjoy.
      ''',
        'hasDietaryRestrictions': 'low carb, vegetarian, contains dairy',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': roastedCauliflowerId,
        'ingredientID': 152, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': roastedCauliflowerId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': roastedCauliflowerId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': roastedCauliflowerId,
        'ingredientID': 237, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': 'olive oil'
      });

      final chickenBistekId = await db.insert('meals', {
        'mealName': 'Chicken Bistek',
        'price': 250.0,
        'calories': 380, 
        'servings': 4,
        'cookingTime': '45 minutes', 
        'mealPicture': 'assets/meals/Chicken_Bistek.jpg',
        'category': 'main dish, chicken, Filipino, savory, citrus',
        'content': 'A Filipino dish of chicken marinated in soy sauce and lemon (or calamansi) juice, then pan-fried and served with a savory sauce and onion rings.',
        'instructions': '''
      1. In a large bowl, combine soy sauce (3/4 cup), lemon juice (1 lemon), salt (1/4 teaspoon), and crushed garlic (3 cloves) to make the marinade. Add chicken (2 lbs boneless breast) and coat thoroughly. Cover and refrigerate overnight.
      2. Remove the chicken from the marinade, letting excess liquid drip off.
      3. Heat 2 tablespoons of cooking oil in a wok. Fry the chicken 2 minutes per side until lightly browned. Remove and set aside.
      4. In the same wok, heat the remaining oil (2 tablespoons) and sauté garlic and half of the sliced onions (3 total) until softened.
      5. Add the fried chicken back to the wok and stir for 30 seconds.
      6. Pour in the remaining marinade and 1 cup water. Bring to a boil, then reduce heat, cover, and simmer for 35 minutes, adding more water if needed.
      7. Add the remaining onions and cook for 2 minutes. Season with sugar (1/2 teaspoon), salt, and ground black pepper to taste.
      8. Transfer to a serving bowl and serve hot.
      ''',
        'hasDietaryRestrictions': 'high protein, high sodium (soy sauce)',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 149, 
        'quantity': 3,
        'unit': 'pieces',
        'content': 'sliced into rings'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 152,
        'quantity': 3,
        'unit': 'cloves',
        'content': 'crushed'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 228, 
        'quantity': 0.5,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 237, 
        'quantity': 0.25,
        'unit': 'cup', 
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 232, 
        'quantity': 0.25,
        'unit': 'teaspoon',
        'content': 'for marinade and to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 240, 
        'quantity': 0.75,
        'unit': 'cup',
        'content': null
      });
  
      await db.insert('meal_ingredients', {
        'mealID': chickenBistekId,
        'ingredientID': 4,
        'quantity': 2,
        'unit': 'lbs',
        'content': 'boneless chicken breast'
      });

 
      final roastChickenId = await db.insert('meals', {
        'mealName': 'Roast Chicken',
        'price': 350.0,
        'calories': 450,
        'servings': 5,
        'cookingTime': '1 hour 20 minutes',
        'mealPicture': 'assets/meals/Roast_Chicken.jpg',
        'category': 'main dish, chicken, savory, roasted',
        'content': 'A classic whole roasted chicken seasoned with salt, pepper, garlic, lemon, and thyme, yielding a tender, flavorful main course.',
        'instructions': '''
      1. Clean the whole chicken (1) and pat dry. Rub sea salt and freshly ground black pepper all over.
      2. Boil water with salt, whole lemon (1 large), and garlic (6 cloves), then set the lemon and garlic aside.
      3. Gently lift the chicken breast skin and pour a little olive oil underneath.
      4. Pierce the lemon to release its juice and place it, along with the garlic and fresh thyme, inside the chicken cavity.
      5. Preheat oven to 350°F (175°C). Place the chicken in a roasting pan. Roast for 1 hour and 20 minutes.
      6. Remove from oven and serve. Store any leftovers in the fridge for future meals.
      ''',
        'hasDietaryRestrictions': 'high protein',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': roastChickenId,
        'ingredientID': 152,
        'quantity': 6,
        'unit': 'cloves',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': roastChickenId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': roastChickenId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': roastChickenId,
        'ingredientID': 4,
        'quantity': 1,
        'unit': 'whole',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': roastChickenId,
        'ingredientID': 237,
        'quantity': null,
        'unit': null,
        'content': 'a little'
      });

      final pocherongManokId = await db.insert('meals', {
        'mealName': 'Pocherong Manok',
        'price': 280.0,
        'calories': 420, 
        'servings': 4,
        'cookingTime': '35 minutes',
        'mealPicture': 'assets/meals/Pocherong_Manok.jpg',
        'category': 'main dish, stew, Filipino, chicken, savory',
        'content': 'A hearty Filipino chicken stew (Pochero) featuring chicken pieces, potatoes, saba bananas, chickpeas, and various vegetables in a rich tomato-based broth.',
        'instructions': '''
      1. Heat the cooking oil (1 cup) in a wok. Fry the saba bananas (3) and potatoes (2) until lightly browned. Remove and set aside.
      2. Leave about 3 tablespoons of oil in the wok. Pan-fry the chicken (2 lbs) for 2 minutes on each side. Remove and set aside.
      3. Add 2 tablespoons more oil. Sauté the chopped onion (1) for 1 minute, then add the chopped garlic (5 cloves) and cook until aromatic. Add the wedged tomatoes (2) and sauté for another minute.
      4. Stir in the Chorizo de Bilbao (2 pieces), then add the chicken back and sauté for 2 minutes.
      5. Add the tomato paste (3 tablespoons) and pour in 2 cups of water. Bring to a boil.
      6. Crumble in the Maggi Magic Chicken Cube (1) and stir until dissolved.
      7. Add the canned chickpeas (14 oz), fried potatoes, and bananas. Cook for 2 minutes.
      8. Add the long green beans (15) and cabbage (1/2 head). Cover and cook for 3 minutes.
      9. Season with fish sauce and ground black pepper to taste. Add the bok choy (1 bunch), cover, and turn off the heat, letting residual heat finish cooking it for 2 minutes.
      10. Transfer to a serving bowl and serve with rice.
      ''',
        'hasDietaryRestrictions': 'contains fish product (fish sauce)',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 4,
        'quantity': 2,
        'unit': 'lbs',
        'content': 'cut into serving pieces'
      });
      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 133, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'cut into large cubes'
      });
      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 152, 
        'quantity': 5,
        'unit': 'cloves',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 125, 
        'quantity': 2,
        'unit': 'pieces',
        'content': 'wedged'
      });
      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 237,
        'quantity': 1,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': pocherongManokId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

      final chickenAlaKingId = await db.insert('meals', {
        'mealName': 'Filipino Chicken ala King with Creamy Sauce',
        'price': 220.0, 
        'calories': 680, 
        'servings': 1,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Filipino_Chicken_Ala_King_with_Creamy_Sauce.webp',
        'category': 'main dish, chicken, creamy, savory, fried',
        'content': 'Crispy deep-fried chicken breast topped with a rich, creamy sauce made from butter, milk, cream, and vegetables, served with buttered corn.',
        'instructions': '''
      1. Flatten the chicken breast (8 oz) using a meat tenderizer. Rub salt (1/8 tsp), black pepper (1/8 tsp), and garlic powder (1/8 tsp) all over the chicken.
      2. Dredge the chicken in all-purpose flour (1/4 cup), dip in the beaten egg (1), and coat with Good Life breadcrumbs (1 cup). Let rest for 5 minutes.
      3. Heat oil (1 cup) in a pan and deep fry the chicken until golden brown. Remove and set aside.
      4. For the side dish, melt butter (2 tbsp) in a pan, sauté the sweet corn kernels (1 1/2 cups) for 2 minutes, season with garlic powder (1/4 tsp), salt, and black pepper. Set aside.
      5. For the Ala King sauce, melt butter (4 tbsp) in a saucepan. Sauté minced garlic (3 cloves), minced onion (3 tsp), and minced carrot (2 tbsp) for 2 minutes. Add flour (3 tbsp) and stir until a paste forms. Gradually pour in fresh milk (1 cup) and stir until thickened. Season with chicken powder (2 tsp), salt, and black pepper. Add all-purpose cream (1 cup), sliced pimiento (4 oz), and chopped parsley (2 tsp). Stir for 30 seconds.
      6. Pour the sauce over the chicken. Serve with sautéed corn and rice.
      ''',
        'hasDietaryRestrictions': 'contains dairy, contains egg, contains gluten',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 4, 
        'quantity': 8,
        'unit': 'oz',
        'content': 'boneless breast'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 177, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'beaten'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 237, 
        'quantity': 1,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 247, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': 'for breading'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 232, 
        'quantity': 0.125,
        'unit': 'teaspoon',
        'content': 'for seasoning'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 233, 
        'quantity': 0.125,
        'unit': 'teaspoon',
        'content': 'for seasoning'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 22, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': 'for side dish'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste (side)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste (side)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 152, 
        'quantity': 3,
        'unit': 'cloves',
        'content': 'minced (sauce)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 149, 
        'quantity': 3,
        'unit': 'teaspoons',
        'content': 'minced (sauce)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 120, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': 'minced (sauce)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 22,
        'quantity': 4,
        'unit': 'tablespoons',
        'content': 'for sauce'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 247,
        'quantity': 3,
        'unit': 'tablespoons',
        'content': 'for sauce'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 223, 
        'quantity': 1,
        'unit': 'cup',
        'content': 'fresh (sauce)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 223, 
        'quantity': 1,
        'unit': 'cup',
        'content': 'all-purpose cream (sauce)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 232, 
        'quantity': null,
        'unit': null,
        'content': 'to taste (sauce)'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenAlaKingId,
        'ingredientID': 233,
        'quantity': null,
        'unit': null,
        'content': 'to taste (sauce)'
      });

      
      final chickenSotanghonSoupId = await db.insert('meals', {
        'mealName': 'Chicken Sotanghon Soup with Patola',
        'price': 200.0,
        'calories': 250, 
        'servings': 6,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Chicken_Sotanghon_Soup_with_Patola.jpg',
        'category': 'main dish, soup, chicken, Filipino, noodle',
        'content': 'A light and comforting Filipino chicken noodle soup featuring sotanghon (glass noodles), tender chicken, and patola (luffa gourd) in a clear, flavorful broth.',
        'instructions': '''
      1. Heat annatto oil (3 tbsp) in a pot over medium heat. Sauté chopped garlic (8 cloves) until lightly golden, then add chopped onion (1) and cook until soft and fragrant.
      2. Add chicken pieces (1 1/2 lbs) and cook while stirring until lightly browned on all sides.
      3. Pour in water (1.5 quarts) and bring to a boil. Add chicken powder (1 tbsp) and simmer for 20 minutes or until chicken is tender. Skim any foam for a clear broth.
      4. Add sotanghon noodles (5 oz) and cook for about 3 minutes, stirring gently to prevent clumping.
      5. Add patola slices (1 piece) and cook for 2 minutes until tender but not mushy.
      6. Season with fish sauce and ground black pepper to taste. Ladle into bowls and top with roasted garlic (1 tbsp) and chopped green onions (2 tbsp) before serving.
      ''',
        'hasDietaryRestrictions': 'high protein, low fat',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': chickenSotanghonSoupId,
        'ingredientID': 4, 
        'quantity': 1.5,
        'unit': 'lbs',
        'content': 'cut into serving pieces'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenSotanghonSoupId,
        'ingredientID': 152, 
        'quantity': 8,
        'unit': 'cloves',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenSotanghonSoupId,
        'ingredientID': 149,
        'quantity': 1,
        'unit': 'piece',
        'content': 'chopped'
      });
      await db.insert('meal_ingredients', {
        'mealID': chickenSotanghonSoupId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

   
      final bukoSaladId = await db.insert('meals', {
        'mealName': 'Buko Salad',
        'price': 300.0, 
        'calories': 400, 
        'servings': 6,
        'cookingTime': '10 minutes',
        'mealPicture': 'assets/meals/Buko_Salad.jpg',
        'category': 'dessert, fruit, Filipino, sweet',
        'content': 'A popular Filipino dessert made from shredded young coconut (buko), mixed with various preserved fruits, and blended in a sweet, creamy dressing.',
        'instructions': '''
      1. In a mixing bowl, combine young coconut (4 cups), kaong (6 oz), nata de coco (12 oz), pineapple chunks (8 oz), and fruit cocktail (2 cans). Gently stir to evenly distribute the ingredients.
      2. Add sweetened condensed milk (1 can) and table cream (7 oz). Mix until everything is well combined.
      3. Refrigerate for at least 4 hours or place in the freezer for 1 hour to chill.
      4. Transfer to a serving bowl. Serve as a dessert.
      ''',
        'hasDietaryRestrictions': 'contains dairy, high sugar, vegetarian',
        'availableFrom': '10:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': bukoSaladId,
        'ingredientID': 178, 
        'quantity': 8,
        'unit': 'ounces',
        'content': 'drained'
      });

      final coconutMacaroonId = await db.insert('meals', {
        'mealName': 'Coconut Macaroon',
        'price': 120.0, 
        'calories': 320,
        'servings': 4,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Coconut_Macaroon.jpg',
        'category': 'dessert, pastry, Filipino, baked, sweet',
        'content': 'Sweet and chewy macaroons made primarily from shredded coconut, butter, brown sugar, eggs, and sweetened condensed milk.',
        'instructions': '''
      1. In a large bowl, cream the butter (1/2 cup) using a fork until smooth.
      2. Add brown sugar (1/2 cup) and mix well.
      3. Stir in the eggs (3) and condensed milk (14 ounces) until all ingredients are well blended.
      4. Fold in the sweetened shredded coconut (14 ounces), distributing it evenly throughout the mixture.
      5. Prepare a mold or paper-lined cupcake pan. Place about 1 tablespoon of the mixture into each cup.
      6. Preheat the oven to 370°F (188°C) for 10 minutes.
      7. Bake the coconut macaroons for 20–30 minutes, or until they turn golden brown.
      8. Let cool slightly and serve as a dessert or snack.
      ''',
        'hasDietaryRestrictions': 'contains dairy, contains egg, high sugar',
        'availableFrom': '10:00',
        'availableTo': '20:00'
      });

     
      await db.insert('meal_ingredients', {
        'mealID': coconutMacaroonId,
        'ingredientID': 22, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': coconutMacaroonId,
        'ingredientID': 229, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': coconutMacaroonId,
        'ingredientID': 177, 
        'quantity': 3,
        'unit': 'pieces',
        'content': null
      });

 
      final bukoPandanId = await db.insert('meals', {
        'mealName': 'Buko Pandan',
        'price': 180.0, 
        'calories': 350, 
        'servings': 4,
        'cookingTime': '15 minutes',
        'mealPicture': 'assets/meals/Buko_Pandan.webp',
        'category': 'dessert, Filipino, sweet, chilled',
        'content': 'A famous Filipino dessert made from pandan-flavored gelatin cubes, shredded young coconut, and sago pearls mixed in a creamy sauce of condensed milk and cream.',
        'instructions': '''
      1. Boil water (2 cups) in a saucepan and add the pandan leaves (1/2 lb). Cover and simmer for 15 minutes.
      2. Remove the pandan leaves, then stir in sugar (1/4 cup), powdered gelatin (3 oz), and buko pandan flavoring (1/2 tsp) until fully dissolved.
      3. Turn off the heat and pour the mixture into a mold. Let it cool until firm. For faster setting, refrigerate after the mixture has cooled slightly (Optional setting time: 8 hours).
      4. In a separate bowl, combine young coconut strips (20 oz), Nestlé Carnation Condensada (150 ml), Nestlé All Purpose Cream (250 ml), and cooked sago pearls (1/2 cup, optional). Mix well.
      5. Chill the creamy mixture in the refrigerator until thickened.
      6. Once the gelatin is firm, cut it into 1/2-inch cubes and fold it into the chilled creamy mixture.
      7. Serve in individual cups or platters. Optionally, top with a scoop of vanilla ice cream.
      ''',
        'hasDietaryRestrictions': 'contains dairy, high sugar, vegetarian',
        'availableFrom': '10:00',
        'availableTo': '20:00'
      });


      await db.insert('meal_ingredients', {
        'mealID': bukoPandanId,
        'ingredientID': 228, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': null
      });


      final suamNaMaisId = await db.insert('meals', {
        'mealName': 'Suam na Mais',
        'price': 180.0, 
        'calories': 300, 
        'servings': 4,
        'cookingTime': '25 minutes',
        'mealPicture': 'assets/meals/Suam_na_Mais.jpg',
        'category': 'main dish, soup, Filipino, corn, savory',
        'content': 'A savory Filipino corn soup, thickened and flavored with ground pork, shrimp, and aromatics, finished with leafy vegetables.',
        'instructions': '''
      1. Heat the cooking oil (3 tablespoons) in a pot and sauté the minced garlic (3 cloves) and minced onion (1) until the onion softens.
      2. Add the ground pork (4 ounces) and sauté for 2 minutes or until lightly browned.
      3. Stir in the white corn kernels (30 ounces) and cook for 3 minutes.
      4. Add the chopped shrimp (8 ounces) and sauté for 1 minute.
      5. In a separate bowl, combine Knorr Crab and Corn Soup (37 grams) with water (4 cups), then pour the mixture into the pot. Stir and bring to a boil. Simmer on low to medium heat for 3 minutes while stirring.
      6. Add the hot pepper leaves or spinach (1 bunch) and season with fish sauce and ground white pepper to taste.
      7. Serve hot with rice.
      ''',
        'hasDietaryRestrictions': 'contains shellfish (shrimp)',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

  
      await db.insert('meal_ingredients', {
        'mealID': suamNaMaisId,
        'ingredientID': 149, 
        'quantity': 1,
        'unit': 'piece',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': suamNaMaisId,
        'ingredientID': 152, 
        'quantity': 3,
        'unit': 'cloves',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': suamNaMaisId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': suamNaMaisId,
        'ingredientID': 233, 
        'quantity': null,
        'unit': null,
        'content': 'ground white pepper, to taste'
      });

      final cornSoupQuailEggsId = await db.insert('meals', {
        'mealName': 'Corn Soup with Quail Eggs',
        'price': 150.0, 
        'calories': 220, 
        'servings': 3,
        'cookingTime': '20 minutes',
        'mealPicture': 'assets/meals/Corn_Soup_with_Quail_Eggs.jpg',
        'category': 'side dish, soup, corn, savory',
        'content': 'A creamy and comforting soup featuring sweet corn and whole quail eggs, thickened with cornstarch and a raw egg.',
        'instructions': '''
      1. Combine chicken broth (2 cups) and water (1 cup) in a cooking pot and bring to a boil.
      2. Add the cream-style sweet corn (1 can, 15 oz.), stir, and let it re-boil. Cover and simmer for 15 minutes, adding water if necessary.
      3. Stir in the chopped green onions (3/4 cup), salt, and pepper. Cook for 2 minutes.
      4. Pour in the diluted cornstarch (2 tbsp cornstarch in water) and stir. Continue cooking for 1 minute.
      5. Drop in the raw chicken egg (1) and stir quickly until it is evenly distributed.
      6. Add the boiled quail eggs (2 dozen), cover, and turn off the heat. Let it sit covered for 5 minutes.
      7. Transfer to a serving bowl and serve.
      ''',
        'hasDietaryRestrictions': 'contains egg, vegetarian option (if using vegetable broth)',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

   
      await db.insert('meal_ingredients', {
        'mealID': cornSoupQuailEggsId,
        'ingredientID': 231, 
        'quantity': 2,
        'unit': 'cups',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cornSoupQuailEggsId,
        'ingredientID': 177,
        'quantity': 1,
        'unit': 'piece',
        'content': 'raw'
      });
      await db.insert('meal_ingredients', {
        'mealID': cornSoupQuailEggsId,
        'ingredientID': 232,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });
      await db.insert('meal_ingredients', {
        'mealID': cornSoupQuailEggsId,
        'ingredientID': 233,
        'quantity': null,
        'unit': null,
        'content': 'to taste'
      });

  
      final chiliCrabId = await db.insert('meals', {
        'mealName': 'Chili Crab',
        'price': 650.0, 
        'calories': 400, 
        'servings': 4,
        'cookingTime': '30 minutes',
        'mealPicture': 'assets/meals/Chili_Crab.jpg',
        'category': 'main dish, seafood, spicy, Southeast Asian',
        'content': 'A savory and spicy seafood dish where hard-shell crabs are stir-fried in a thick, tomato-based chili sauce.',
        'instructions': '''
      1. Heat cooking oil (2 tbsp) in a pot over medium heat.
      2. Sauté minced garlic (2 tbsp), minced ginger (3 tbsp), and crushed red pepper or sliced red chili (1 tbsp or 3 pieces) until fragrant.
      3. Add the crab (2 lbs, cut in half) and cook for 3 to 4 minutes.
      4. Stir in hoisin sauce (2 tbsp), tomato ketchup or tomato sauce (1/2 cup), sweet chili sauce (1/4 cup), fish sauce (2 tbsp), and sesame oil (1/2 tsp) until evenly combined.
      5. Pour in water (1/4 cup) and bring to a boil, then simmer for 10 to 15 minutes or until the sauce thickens.
      6. Garnish with thinly sliced green onions or scallions (3 tbsp) on top.
      7. Serve hot and enjoy!
      ''',
        'hasDietaryRestrictions': 'contains shellfish (crab), contains fish product (fish sauce)',
        'availableFrom': '18:00',
        'availableTo': '22:00'
      });

     
      await db.insert('meal_ingredients', {
        'mealID': chiliCrabId,
        'ingredientID': 237, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': chiliCrabId,
        'ingredientID': 152, 
        'quantity': 2,
        'unit': 'tablespoons',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': chiliCrabId,
        'ingredientID': 125, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': 'tomato ketchup or sauce'
      });

 
      final crispyCrabletsId = await db.insert('meals', {
        'mealName': 'Crispy Crablets',
        'price': 280.0,
        'calories': 550, 
        'servings': 6,
        'cookingTime': '12 minutes',
        'mealPicture': 'assets/meals/Crispy_Crablets.jpg',
        'category': 'appetizer, snack, seafood, fried, crunchy',
        'content': 'Whole small crabs (crablets) coated in cornstarch and deep-fried until extremely crispy, often seasoned simply with salt and pepper.',
        'instructions': '''
      1. Place the crablets (2 lbs, cleaned) in a bowl and pour in gin or sherry (4 tablespoons, optional). Mix gently.
      2. Sprinkle with salt (1/2 tablespoon) and ground black pepper (2 teaspoons) and mix well.
      3. Heat cooking oil (3 cups) in a frying pan or pot.
      4. Dredge the crablets in cornstarch (1 cup) and deep-fry until crispy.
      5. Remove from the pan and drain on a plate lined with paper towels.
      6. Once excess oil has drained, arrange on a serving plate and serve with spicy vinegar dip.
      ''',
        'hasDietaryRestrictions': 'contains shellfish (crablets), high fat',
        'availableFrom': '11:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': crispyCrabletsId,
        'ingredientID': 232, 
        'quantity': 0.5,
        'unit': 'tablespoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCrabletsId,
        'ingredientID': 233, 
        'quantity': 2,
        'unit': 'teaspoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': crispyCrabletsId,
        'ingredientID': 237, 
        'quantity': 3,
        'unit': 'cups',
        'content': 'for deep frying'
      });

      final rellenongAlimasagId = await db.insert('meals', {
        'mealName': 'Rellenong Alimasag',
        'price': 400.0,
        'calories': 350,
        'servings': 8,
        'cookingTime': '18 minutes',
        'mealPicture': 'assets/meals/Rellenong_Alimasag.jpg',
        'category': 'main dish, seafood, Filipino, fried, stuffed',
        'content': 'Stuffed crab shells, where the meat is flaked and mixed with diced potatoes, carrots, and seasonings, then returned to the shell and deep-fried.',
        'instructions': '''
      1. Heat 2 tablespoons of cooking oil in a pan. Sauté the minced onion (1 medium) and diced tomato (1 medium) until soft.
      2. Add the diced potato (1 medium) and diced carrot (1 medium). Cook for 3 to 5 minutes.
      3. Add the chopped long green chili (1) and crab meat (8 crabs), including some of the crab juice for extra flavor. Cook for 2 minutes.
      4. Stir in dried parsley (3 tsp), garlic powder (2 tsp), salt (2 tsp), and ground black pepper (1 tsp). Remove from heat and transfer to a large bowl.
      5. Once the mixture has cooled, combine it with bread crumbs (1/2 cup) and raw eggs (2). Mix thoroughly.
      6. Stuff each crab shell with the mixture.
      7. Heat 1 cup of cooking oil in a pan. When hot, fry the stuffed crab shells with the stuffing side facing up. Spoon hot oil over the stuffing to cook it slowly.
      8. Flip the crab shells and fry the other side for 3 to 5 minutes over medium heat.
      9. Transfer to a serving plate and serve.
      ''',
        'hasDietaryRestrictions': 'contains shellfish (crab), contains egg, high fat',
        'availableFrom': '17:00',
        'availableTo': '22:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 133, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 120, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 248, 
        'quantity': 0.5,
        'unit': 'cup',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 149,
        'quantity': 1,
        'unit': 'medium',
        'content': 'minced'
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 125, 
        'quantity': 1,
        'unit': 'medium',
        'content': 'diced'
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 232,
        'quantity': 2,
        'unit': 'teaspoons',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 233, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 237, 
        'quantity': 1,
        'unit': 'cup',
        'content': '1 cup for frying + 2 tbsp for sautéing'
      });
      await db.insert('meal_ingredients', {
        'mealID': rellenongAlimasagId,
        'ingredientID': 177, 
        'quantity': 2,
        'unit': 'raw pieces',
        'content': null
      });

      final cucumberSaladId = await db.insert('meals', {
        'mealName': 'Cucumber Salad',
        'price': 60.0, 
        'calories': 36, 
        'servings': 3,
        'cookingTime': '5 minutes',
        'mealPicture': 'assets/meals/Cucumber_Salad.jpg',
        'category': 'side dish, salad, cold, refreshing, savory',
        'content': 'A simple, refreshing salad made with thinly sliced cucumbers and onions marinated in a sweet and sour vinegar-based dressing.',
        'instructions': '''
      1. Wash the cucumber (2 pieces) and pat dry.
      2. Thinly slice the cucumber crosswise. Peeling the skin is optional.
      3. Combine salt (1 tsp), ground black pepper (1/8 tsp), sugar (1 tbsp), minced ginger (1 tbsp), and apple cider vinegar or white vinegar (1/4 cup), then mix well.
      4. Add the sliced cucumber and red onion (1 piece, optional). Refrigerate for 2 hours.
      5. Serve.
      ''',
        'hasDietaryRestrictions': 'vegetarian, vegan, gluten-free, low calorie',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': cucumberSaladId,
        'ingredientID': 232, 
        'quantity': 1,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cucumberSaladId,
        'ingredientID': 233,
        'quantity': 0.125,
        'unit': 'teaspoon',
        'content': null
      });
      await db.insert('meal_ingredients', {
        'mealID': cucumberSaladId,
        'ingredientID': 149,
        'quantity': 1,
        'unit': 'piece',
        'content': 'sliced, optional'
      });
      await db.insert('meal_ingredients', {
        'mealID': cucumberSaladId,
        'ingredientID': 228, 
        'quantity': 1,
        'unit': 'tablespoon',
        'content': null
      });

      final friedEggplantId = await db.insert('meals', {
        'mealName': 'Fried Eggplant (Pritong Talong)',
        'price': 80.0, 
        'calories': 200, 
        'servings': 2,
        'cookingTime': '10 minutes',
        'mealPicture': 'assets/meals/Fried_Eggplant.jpg',
        'category': 'side dish, vegetable, Filipino, fried',
        'content': 'Slices of eggplant lightly coated in flour and pan-fried until tender, typically served with a savory shrimp paste (bagoong) dip.',
        'instructions': '''
      1. Slice the large Chinese eggplant (1) in half lengthwise, then cut into 3-inch pieces.
      2. Dredge the eggplant pieces in all-purpose flour (1/4 cup).
      3. Heat 4 tablespoons of cooking oil in a pan. When hot, pan-fry the eggplant slices until one side turns dark brown, then flip to cook the other side. Add more oil if needed, as eggplant absorbs oil during frying. Continue cooking until the eggplant is fully done.
      4. Transfer to a plate and serve with bagoong alamang (3 tbsp) and a dip of soy sauce with chili.
      5. Eat with rice.
      ''',
        'hasDietaryRestrictions': 'vegetarian, vegan (without bagoong), contains gluten',
        'availableFrom': '11:00',
        'availableTo': '20:00'
      });

      await db.insert('meal_ingredients', {
        'mealID': friedEggplantId,
        'ingredientID': 237, 
        'quantity': 6,
        'unit': 'tablespoons',
        'content': 'for frying'
      });
      await db.insert('meal_ingredients', {
        'mealID': friedEggplantId,
        'ingredientID': 247, 
        'quantity': 0.25,
        'unit': 'cup',
        'content': 'for dredging'
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
      i.unit AS base_unit,
      i.category,
      i.ingredientPicture,
      mi.quantity,
      mi.unit,
      mi.content
    FROM meal_ingredients mi
    JOIN ingredients i ON mi.ingredientID = i.ingredientID
    WHERE mi.mealID = ?
    ''', [mealId]);
  }

  // ========== USER OPERATIONS ==========
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    
    // 1. Local Save: SQLite ID will likely reset to 1, 2, 3... on reinstall
    int id = await db.insert('users', user);

    // 2. Cloud Backup: Use Push() to generate a unique key like "-Mz..."
    try {
      Map<String, dynamic> cloudData = Map.from(user);
      cloudData['local_id'] = id; // Optional: Save local ID for reference

      // FIX: Use push() to generate a guaranteed unique ID
      // This creates a key like "-N8...abc" which NEVER collides with "1" or "2"
      await FirebaseDatabase.instance.ref("users").push().set(cloudData);
      
      print("🚀 User synced safely with unique Push ID");
    } catch (e) {
      print("⚠️ Offline: User saved locally only.");
    }

    return id;
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
    
    // 1. Fetch current local data to get the unique Username/Email
    // We need this to find the correct record in Firebase since IDs don't match anymore
    final currentUser = await getUserById(id);
    if (currentUser == null) return 0;
    String lookupKey = currentUser['username']; // or 'emailAddress'

    // 2. Update Local SQLite
    int rowsAffected = await db.update(
      'users',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );

    // 3. Update Firebase (Query First Strategy)
    try {
      // Find the node where 'username' matches, regardless of whether the key is "1" or "-Mz..."
      final snapshot = await FirebaseDatabase.instance.ref("users")
          .orderByChild("username")
          .equalTo(lookupKey)
          .get();

      if (snapshot.exists) {
        // We found the record! Update it.
        for (var child in snapshot.children) {
          await child.ref.update(updates);
          print("🚀 User updated in Cloud: ${child.key}");
        }
      } else {
        print("⚠️ User not found in cloud, skipping update.");
      }
    } catch (e) {
      print("⚠️ Offline: User update saved locally only. Error: $e");
    }

    return rowsAffected;
  }

  Future<int> deleteUser(int id) async { 
    final db = await database;

    // 1. Fetch current local data to get lookup key
    final currentUser = await getUserById(id);
    if (currentUser == null) return 0;
    String lookupKey = currentUser['username']; 

    // 2. Local Delete
    int rows = await db.delete('users', where: 'id = ?', whereArgs: [id]);
    
    // 3. Cloud Delete (Query First Strategy)
    try {
      final snapshot = await FirebaseDatabase.instance.ref("users")
          .orderByChild("username")
          .equalTo(lookupKey)
          .get();

      if (snapshot.exists) {
        for (var child in snapshot.children) {
          await child.ref.remove();
          print("🚀 User deleted from Cloud: ${child.key}");
        }
      }
    } catch (e) {
      print("Error deleting from cloud: $e");
    }
    return rows;
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
    //final db = await database;
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
    
    // 1. Local Save
    int id = await db.insert('meals', meal);

    // 2. Cloud Backup (Safe Insert)
    try {
      Map<String, dynamic> cloudData = Map.from(meal);
      cloudData['local_id'] = id; // Save local ID for reference

      // Use push() to generate a unique key (e.g. "-Mz7...")
      await FirebaseDatabase.instance.ref("meals").push().set(cloudData);
      print("🚀 Meal synced safely with unique Push ID");
    } catch (e) {
       print("⚠️ Offline: Meal saved locally only.");
    }

    return id;
  }

  Future<int> updateMeal(int mealId, Map<String, dynamic> updates) async {
    final db = await database;
    
    // 1. Get the CURRENT meal name before updating (to find it in cloud)
    final currentMeal = await getMealById(mealId);
    String? searchName = currentMeal?['mealName'];

    // 2. Local Update
    int rows = await db.update(
      'meals',
      updates,
      where: 'mealID = ?',
      whereArgs: [mealId],
    );

    // 3. Cloud Update (Find by Name, then Update)
    if (searchName != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref("meals")
            .orderByChild("mealName")
            .equalTo(searchName)
            .get();

        if (snapshot.exists) {
          for (var child in snapshot.children) {
            await child.ref.update(updates);
            print("🚀 Meal updated in Cloud: ${child.key}");
          }
        }
      } catch (e) {
        print("⚠️ Offline: Meal update saved locally only.");
      }
    }

    return rows;
  }

  Future<int> deleteMeal(int mealId) async {
    final db = await database;
    
    // 1. Get name to find in cloud
    final currentMeal = await getMealById(mealId);
    String? searchName = currentMeal?['mealName'];

    // 2. Local Delete
    int rows = await db.delete(
      'meals',
      where: 'mealID = ?',
      whereArgs: [mealId],
    );

    // 3. Cloud Delete
    if (searchName != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref("meals")
            .orderByChild("mealName")
            .equalTo(searchName)
            .get();

        if (snapshot.exists) {
          for (var child in snapshot.children) {
            await child.ref.remove();
            print("🚀 Meal deleted from Cloud");
          }
        }
      } catch (e) {
        print("Error deleting from cloud: $e");
      }
    }
    return rows;
  }

  Future<int> insertIngredient(Map<String, dynamic> ingredient) async {
    final db = await database;
    int id = await db.insert('ingredients', ingredient);

    // Cloud Sync
    try {
      Map<String, dynamic> cloudData = Map.from(ingredient);
      cloudData['local_id'] = id; 
      // Safe Push
      await FirebaseDatabase.instance.ref("ingredients").push().set(cloudData);
    } catch (e) {
      print("⚠️ Offline: Ingredient saved locally only.");
    }
    return id;
  }

  Future<int> updateIngredient(int ingredientId, Map<String, dynamic> updates) async {
    final db = await database;
    
    // Get current name to find in cloud
    final results = await db.query('ingredients', where: 'ingredientID = ?', whereArgs: [ingredientId]);
    String? searchName = results.isNotEmpty ? results.first['ingredientName'] as String? : null;

    int rows = await db.update(
      'ingredients',
      updates,
      where: 'ingredientID = ?',
      whereArgs: [ingredientId],
    );

    if (searchName != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref("ingredients")
            .orderByChild("ingredientName")
            .equalTo(searchName)
            .get();

        if (snapshot.exists) {
          for (var child in snapshot.children) {
            await child.ref.update(updates);
          }
        }
      } catch (e) {
        print("⚠️ Offline: Ingredient update saved locally only.");
      }
    }
    return rows;
  }

  Future<int> deleteIngredient(int ingredientId) async {
    final db = await database;
    
    // Get current name
    final results = await db.query('ingredients', where: 'ingredientID = ?', whereArgs: [ingredientId]);
    String? searchName = results.isNotEmpty ? results.first['ingredientName'] as String? : null;

    int rows = await db.delete('ingredients', where: 'ingredientID = ?', whereArgs: [ingredientId]);

    if (searchName != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref("ingredients")
            .orderByChild("ingredientName")
            .equalTo(searchName)
            .get();

        if (snapshot.exists) {
          for (var child in snapshot.children) {
            await child.ref.remove();
          }
        }
      } catch (e) { print("Error deleting cloud ingredient"); }
    }
    return rows;
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

/*
  Future<int> deleteUser(int id) async { // Change userId to id
    final db = await database;
    int rows = await db.delete('users', where: 'id = ?', whereArgs: [id]); // Change userID to id
    
    // Add Firebase Delete here too!
    try {
      await FirebaseDatabase.instance.ref("users/$id").remove();
    } catch (e) {
      print("Error deleting from cloud: $e");
    }
    return rows;
  }
  */

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
    final maxOrder = await db.rawQuery('SELECT MAX(order_num) as max FROM faqs');
    int newOrder = (maxOrder.first['max'] as int? ?? 0) + 1;
    faq['order_num'] = newOrder;
    
    int id = await db.insert('faqs', faq);

    try {
      Map<String, dynamic> cloudData = Map.from(faq);
      cloudData['local_id'] = id;
      // Use push() to avoid ID collision
      await FirebaseDatabase.instance.ref("faqs").push().set(cloudData);
    } catch (e) {
      print("⚠️ Offline: FAQ insert saved locally only.");
    }

    return id;
  }

  Future<int> updateFaq(int id, Map<String, dynamic> updates) async {
    final db = await database;
    
    // Find current question text
    final results = await db.query('faqs', where: 'id = ?', whereArgs: [id]);
    String? searchQuestion = results.isNotEmpty ? results.first['question'] as String? : null;

    int rows = await db.update('faqs', updates, where: 'id = ?', whereArgs: [id]);

    if (searchQuestion != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref("faqs")
            .orderByChild("question")
            .equalTo(searchQuestion)
            .get();

        if (snapshot.exists) {
          for (var child in snapshot.children) {
            await child.ref.update(updates);
          }
        }
      } catch (e) {
        print("⚠️ Offline: FAQ update saved locally only.");
      }
    }
    return rows;
  }

  Future<int> deleteFaq(int id) async {
    final db = await database;
    
    // Find current question text
    final results = await db.query('faqs', where: 'id = ?', whereArgs: [id]);
    String? searchQuestion = results.isNotEmpty ? results.first['question'] as String? : null;

    int rows = await db.delete('faqs', where: 'id = ?', whereArgs: [id]);

    if (searchQuestion != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref("faqs")
            .orderByChild("question")
            .equalTo(searchQuestion)
            .get();

        if (snapshot.exists) {
          for (var child in snapshot.children) {
            await child.ref.remove();
          }
        }
      } catch (e) { print("Error deleting cloud FAQ"); }
    }
    return rows;
  }

  // ========== ABOUT US OPERATIONS ==========
  Future<String?> getAboutUsContent() async {
    final db = await database;
    final result = await db.query('about_us', limit: 1);
    return result.isNotEmpty ? result.first['content'] as String? : null;
  }

  Future<int> updateAboutUsContent(String content) async {
    final db = await database;
    int rows;
    
    // 1. Local Logic (Upsert)
    if (await db.query('about_us').then((res) => res.isEmpty)) {
      rows = await db.insert('about_us', {'id': 1, 'content': content});
    } else {
      rows = await db.update('about_us', {'content': content}, where: 'id = 1');
    }

    // 2. 🔥 Cloud Sync
    try {
      // We force ID 1 for About Us since there is only one
      await FirebaseDatabase.instance.ref("about_us/1").set({
        'id': 1,
        'content': content
      });
      print("🚀 About Us synced to Cloud");
    } catch (e) {
      print("⚠️ Offline: About Us saved locally only.");
    }

    return rows;
  }

  Future<void> _insertUnitConversions(Database db) async {
    // Basic conversions relative to grams/ml
    final conversions = [
      {'unit_name': 'kg', 'grams_per_unit': 1000.0},
      {'unit_name': 'g', 'grams_per_unit': 1.0},
      {'unit_name': 'mg', 'grams_per_unit': 0.001},
      {'unit_name': 'lb', 'grams_per_unit': 453.59},
      {'unit_name': 'oz', 'grams_per_unit': 28.35},
      {'unit_name': 'cup', 'grams_per_unit': 240.0}, // approx for water
      {'unit_name': 'tbsp', 'grams_per_unit': 15.0},
      {'unit_name': 'tsp', 'grams_per_unit': 5.0},
    ];

    for (var c in conversions) {
      await db.insert('unit_conversions', c);
    }
    print("✅ Unit conversions seeded.");
  }

  Map<String, dynamic> getPriceInfo(Map<String, dynamic> ingredient) {
    String ingredientName = ingredient['ingredientName']?.toString() ?? '';
    String category = ingredient['category']?.toString() ?? '';
    
    // Use the direct price and unit fields
    double price = (ingredient['price'] as num?)?.toDouble() ?? 0.0;
    String unit = ingredient['unit']?.toString().toLowerCase() ?? 'unit';
    
    // Densities (g/ml) by category
    Map<String, double> densities = {
      'dairy': 1.03,
      'pantry': 1.1,
      'vegetable': 1.0,
      'spice': 0.5,
      'legume': 1.0,
      'starch': 0.8,
      'condiment': 1.05,
      'seafood': 1.0,
      'protein, animal': 1.0,
      'protein, plant-based': 1.0,
      'herb': 0.3,
      'fruit': 1.0,
      'carbohydrate, grain': 0.85,
      'carbohydrate, noodle': 0.6,
    };
    double density = densities[category.toLowerCase()] ?? 1.0;

    // Unit to grams mapping
    Map<String, double> unitToGrams = {
      'kg': 1000,
      'g': 1,
      'l': 1000,
      'L': 1000,
      'ml': density,
      'piece': _getIngredientWeight(ingredientName, 'piece', category, 100),
      'pcs': _getIngredientWeight(ingredientName, 'pcs', category, 100),
      'bottle': _getIngredientWeight(ingredientName, 'bottle', category, 500),
      'can': _getIngredientWeight(ingredientName, 'can', category, 370),
      'tray': _getIngredientWeight(ingredientName, 'tray', category, 1800),
      'tie': _getIngredientWeight(ingredientName, 'tie', category, 250),
      'group': _getIngredientWeight(ingredientName, 'group', category, 500),
      'leaves': 1,
      'pack': _getIngredientWeight(ingredientName, 'pack', category, 500),
      'bundle': _getIngredientWeight(ingredientName, 'bundle', category, 50),
      'head': 500.0,
      'cube': 10.0,
      'tundan': _getIngredientWeight(ingredientName, 'piece', category, 100),
    };

    // Get grams per unit
    double gramsPerUnit = unitToGrams[unit] ?? 100;

    // Calculate price per 100g
    double pricePer100g = (gramsPerUnit > 0) ? (price / (gramsPerUnit / 100)) : 0;

    return {
      'price_per_100g': pricePer100g,
      'unit': unit,
      'price': price,
      'grams_per_unit': gramsPerUnit,
    };
  }

  Map<String, Map<String, double>> _getIngredientSpecificWeights() {
    return {
      // Eggs
      'egg': {'tray': 24 * 50, 'piece': 50, 'pack': 24 * 50, 'pcs': 50}, // 50g per egg average
      'pugo': {'pack': 12 * 10, 'piece': 10, 'pcs': 10}, // 10g per quail egg
      
      // Fruits - average weights in grams
      'apple': {'piece': 150, 'pcs': 150},
      'orange': {'piece': 130, 'pcs': 130},
      'lemon': {'piece': 60, 'pcs': 60},
      'calamansi': {'piece': 10, 'pcs': 10},
      'sayote': {'piece': 250, 'pcs': 250},
      'watermelon': {'piece': 2000, 'pcs': 2000},
      'mango': {'piece': 200, 'pcs': 200},
      'banana': {'piece': 120, 'pcs': 120},
      'saba': {'piece': 150, 'pcs': 150},
      'lakatan': {'piece': 120, 'pcs': 120},
      'latundan': {'piece': 100, 'pcs': 100},
      
      // Vegetables
      'celery': {'pack': 250, 'kg': 1000},
      'cilantro': {'pack': 50, 'kg': 1000},
      'parsley': {'pack': 50, 'kg': 1000},
      'kangkong': {'tie': 200, 'kg': 1000},
      'malunggay': {'bundle': 100, 'kg': 1000},
      'pechay': {'tie': 300, 'kg': 1000},
      'mustasa': {'tie': 200, 'kg': 1000},
      'broccoli': {'piece': 300, 'kg': 1000},
      'cabbage': {'piece': 800, 'kg': 1000},
      'potato': {'piece': 150, 'kg': 1000},
      
      // Proteins
      'tofu': {'pack': 350, 'kg': 1000},
      'tokwa': {'pack': 350, 'kg': 1000},
      'chicken': {'kg': 1000, 'pack': 1000},
      'pork': {'kg': 1000, 'pack': 1000},
      'beef': {'kg': 1000, 'pack': 1000},
      
      // Legumes and beans
      'kidney beans': {'pack': 400, 'kg': 1000},
      'mungbeans': {'pack': 400, 'kg': 1000},
      'peanuts': {'pack': 500, 'kg': 1000},
      
      // Liquids
      'vinegar': {'bottle': 350, '350ml bottle': 350, 'ml': 1},
      'soy sauce': {'bottle': 350, '350ml bottle': 350, 'ml': 1},
      'patis': {'bottle': 350, '350ml bottle': 350, 'ml': 1},
      'cooking oil': {'500ml': 500, 'bottle': 500, 'ml': 1},
      'coconut milk': {'250ml pack': 250, 'pack': 250, 'ml': 1},
      'coconut cream': {'250ml pack': 250, 'pack': 250, 'ml': 1},
      'evaporated milk': {'370ml can': 370, 'can': 370, 'ml': 1},
      
      // Packaged goods
      'lumpia wrapper': {'piece': 8, 'pcs': 8, 'pack': 100 * 8}, // 100 pieces
      'pancit bihon': {'pack': 400, 'kg': 1000},
      'sotanghon': {'piece': 100, 'kg': 1000},
      'miswa': {'piece': 50, 'kg': 1000},
      'odong': {'piece': 100, 'kg': 1000},
      'rice': {'kg': 1000, 'pack': 1000},
      
      // Spices and condiments
      'atsuete': {'pack': 10, 'kg': 1000},
      'cinnamon': {'pack': 50, 'kg': 1000},
      'paprika': {'pack': 50, 'kg': 1000},
      'salt': {'kg': 1000, 'pack': 1000},
      'sugar': {'kg': 1000, 'pack': 1000},
    };
  }

  double _getIngredientWeight(String ingredientName, String unit, String category, double defaultWeight) {
    final specificWeights = _getIngredientSpecificWeights();
    
    // Look for exact match first, then partial match
    for (var key in specificWeights.keys) {
      if (ingredientName.toLowerCase().contains(key)) {
        return specificWeights[key]?[unit] ?? defaultWeight;
      }
    }
    
    // Fallback to category-based defaults
    switch (unit) {
      case 'piece':
      case 'pcs':
        if (category.toLowerCase().contains('fruit')) return 150;
        if (category.toLowerCase().contains('vegetable')) return 200;
        return 100;
      case 'pack':
        if (category.toLowerCase().contains('vegetable')) return 250;
        if (category.toLowerCase().contains('spice')) return 50;
        if (category.toLowerCase().contains('herb')) return 50;
        return 500;
      case 'bundle':
        return category.toLowerCase().contains('leafy') ? 100.0 : 50.0;
      case 'tie':
        return category.toLowerCase().contains('vegetable') ? 250.0 : 200.0;
      case 'bottle':
      case 'can':
        return 500.0;
      case 'tray':
        return 1800.0;
      case 'group':
        return 500.0;
      default:
        return defaultWeight;
    }
  }

  // ========== UNIT CONVERSION METHOD ==========
  // Enhanced unit conversion with more comprehensive support
double convertToGrams(double quantity, String unit, Map<String, dynamic> ingredient) {
  unit = unit.toLowerCase().trim();
  String ingredientName = ingredient['ingredientName']?.toString().toLowerCase() ?? '';
  String category = ingredient['category']?.toString() ?? '';

    if (unit == 'cloves') unit = 'clove';
    if (unit == 'thumbs') unit = 'thumb';
    if (unit == 'pieces') unit = 'piece'; // Good practice to add this too

    // Add Thumb Unit logic
    if (unit.contains('thumb')) {
      // "Small thumb" is often used for ginger.
      // If "small" is present, the size logic below will multiply by 0.7.
      // Base weight for a thumb of ginger is approx 15g.
      unit = 'thumb'; // Standardize to just 'thumb' so it falls through or we handle it here
      // We can actually return here, or let it flow if we want size modifiers.
      // Let's handle the specific calculation here to be safe, but apply size modifiers first.
       if (unit.contains('small')) {
          quantity *= 0.7;
       } else if (unit.contains('large')) {
          quantity *= 1.3;
       }
       return quantity * 15.0; // Average weight of a ginger thumb
    }
  
  // Handle size descriptors first
  if (unit.contains('small')) {
    quantity *= 0.7; // small is 70% of standard
    unit = 'piece';   //unit.replaceAll('small', '').trim();
  } else if (unit.contains('large')) {
    quantity *= 1.3; // large is 130% of standard  
    unit = 'piece';   //unit.replaceAll('large', '').trim();
  } else if (unit.contains('medium')) {
    quantity *= 1.0; // medium is standard
    unit = 'piece';   //unit.replaceAll('medium', '').trim();
  }

  switch (unit) {
    // Standard weight/volume units
    case 'kg': return quantity * 1000;
    case 'g': return quantity;
    case 'mg': return quantity / 1000;
    case 'oz': return quantity * 28.35;
    case 'lb': return quantity * 453.6;
    
    // Volume units with density
    case 'tbsp': return quantity * (ingredient['unit_density_tbsp'] as double? ?? 15.0);
    case 'tsp': return quantity * (ingredient['unit_density_tsp'] as double? ?? 5.0);
    case 'cup': return quantity * (ingredient['unit_density_cup'] as double? ?? 240.0);
    case 'l':
    case 'liter':
      double d = (ingredient['unit_density_cup'] as double? ?? 240.0) / 240.0;
      return quantity * 1000 ;
    
    // Countable items with specific weights
    case 'piece': 
    case 'pcs':
    case 'pc': 
      return quantity * _getPieceWeight(ingredientName, category);
    
    case 'clove':
      if (ingredientName.contains('garlic')) return quantity * 5.0;
      return quantity * 2.0; // default for other cloves
    
    case 'head':
      if (ingredientName.contains('garlic')) return quantity * 50.0;
      if (ingredientName.contains('cabbage')) return quantity * 800.0;
      return quantity * 500.0; // default head weight
    
    case 'bulb':
      if (ingredientName.contains('onion')) return quantity * 70.0;
      return quantity * 100.0;
    
    // Packaging units
    case 'pack': 
    case 'package': 
      return quantity * _getIngredientWeight(ingredientName, 'pack', category, 500.0);
    
    case 'bottle': 
      return quantity * _getIngredientWeight(ingredientName, 'bottle', category, 500.0);
    
    case 'can': 
      return quantity * _getIngredientWeight(ingredientName, 'can', category, 370.0);
    
    // Produce units  
    case 'bunch':
      if (ingredientName.contains('parsley') || ingredientName.contains('cilantro')) return quantity * 50.0;
      if (ingredientName.contains('green onion')) return quantity * 100.0;
      return quantity * 200.0; // default bunch
    
    case 'stalk':
      if (ingredientName.contains('celery')) return quantity * 40.0;
      if (ingredientName.contains('rhubarb')) return quantity * 150.0;
      return quantity * 50.0;
    
    case 'slice':
      if (ingredientName.contains('bread')) return quantity * 30.0;
      if (ingredientName.contains('cheese')) return quantity * 20.0;
      return quantity * 25.0;
    
    case 'wedge':
      if (ingredientName.contains('lemon') || ingredientName.contains('lime')) return quantity * 10.0;
      return quantity * 50.0;
    
    // Bulk units
    case 'pinch': return quantity * 0.3;
    case 'dash': return quantity * 0.6;
    case 'handful': return quantity * 30.0;
    
    // Default fallback
    default: 
      return quantity * _getIngredientWeight(ingredientName, unit, category, 100.0);
  }
}

// Enhanced piece weight helper
double _getPieceWeight(String ingredientName, String category, [String size = 'standard']) {
  ingredientName = ingredientName.toLowerCase();
  double baseWeight;
  
  // Fruits
  if (ingredientName.contains('apple')) return 150.0;
  else if (ingredientName.contains('banana')) return 120.0;
  else if (ingredientName.contains('orange')) return 130.0;
  else if (ingredientName.contains('lemon')) return 60.0;
  else if (ingredientName.contains('lime')) return 50.0;
  else if (ingredientName.contains('tomato')) return 80.0;
  else if (ingredientName.contains('potato')) return 150.0;
  else if (ingredientName.contains('onion')) return 70.0;
  else if (ingredientName.contains('sayote')) return 250.0;
  
  // Vegetables
  else if (ingredientName.contains('carrot')) return 60.0;
  else if (ingredientName.contains('bell pepper')) return 120.0;
  else if (ingredientName.contains('eggplant')) return 250.0;
  else if (ingredientName.contains('cucumber')) return 200.0;
  
  // Eggs
  if (ingredientName.contains('egg')) return 50.0;
  if (ingredientName.contains('pugo')) return 10.0;
  
  // Category-based defaults
  else if (category.toLowerCase().contains('fruit')) return 120.0;
  else if (category.toLowerCase().contains('vegetable')) return 100.0;
  else if (category.toLowerCase().contains('protein')) return 150.0;
  
  return 100.0; // general default
}

  double _parseQuantity(String quantityStr) {
    if (quantityStr.trim().isEmpty) return 0.0;
    
    if (double.tryParse(quantityStr) != null) {
      return double.parse(quantityStr);
    }
    
    final fractionMap = {
      '⅛': 0.125, '¼': 0.25, '⅓': 0.333, '⅜': 0.375,
      '½': 0.5, '⅝': 0.625, '⅔': 0.666, '¾': 0.75, '⅞': 0.875
    };
    
    String cleanStr = quantityStr.trim();
    
    // Check for single fraction characters
    if (fractionMap.containsKey(cleanStr)) {
      return fractionMap[cleanStr]!;
    }
    
    // Handle text fractions like "1/2"
    if (cleanStr.contains('/')) {
      List<String> parts = cleanStr.split('/');
      if (parts.length == 2) {
        double numerator = double.tryParse(parts[0].trim()) ?? 1.0;
        double denominator = double.tryParse(parts[1].trim()) ?? 1.0;
        if (denominator != 0) return numerator / denominator;
      }
    }
    
    // Fallback: try to extract the first number found
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(cleanStr);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 0.0;
    }

    return 0.0;
  }

  // --- Main Function: Recalculate and Save All Meal Prices ---
  Future<void> updateAllMealPrices() async {
    final db = await database;
    
    // 1. Get all meals
    final meals = await getAllMeals();
    print('Starting price update for ${meals.length} meals...');

    int updatedCount = 0;

    for (var meal in meals) {
      int mealId = meal['mealID'];
      double totalCost = 0.0;

      // 2. Get ingredients for this meal (joins with ingredients table)
      final ingredients = await getMealIngredients(mealId);

      // 3. Calculate total cost based on ingredients
      for (var ing in ingredients) {
        // Get price per base unit from ingredients table
        double basePrice = ing['price'] as double? ?? 0.0;
        
        // Parse the recipe quantity (e.g., "1/2" -> 0.5)
        double qty = _parseQuantity(ing['quantity']?.toString() ?? '0');
        String recipeUnit = ing['unit']?.toString() ?? 'piece';
        
        // Determine the base unit for the price (e.g., price is per 'kg')
        String baseUnit = ing['base_unit']?.toString() ?? recipeUnit;

        // Convert both to grams to compare apples-to-apples
        double recipeGrams = convertToGrams(qty, recipeUnit, ing);
        double baseUnitGrams = convertToGrams(1.0, baseUnit, ing);

        // Calculate proportional cost: (Recipe Weight / Base Weight) * Base Price
        if (baseUnitGrams > 0) {
          totalCost += (recipeGrams * basePrice) / baseUnitGrams;
        }
      }

      // 4. Update the meal record with the new computed price
      // Only update if we calculated a valid cost > 0 to avoid zeroing out data accidentally
      if (totalCost > 0) {
        await db.update(
          'meals',
          {'price': double.parse(totalCost.toStringAsFixed(2))}, // Round to 2 decimals
          where: 'mealID = ?',
          whereArgs: [mealId],
        );
        updatedCount++;
      }
    }
    
    print('Successfully updated prices for $updatedCount meals.');
  }

  Future<void> _insertCompleteSubstitutionData(Database db) async {
    print("Seeding Substitution Data...");
    
    // We need to find IDs first to avoid Foreign Key errors. 
    // This is a safe way to insert sample substitutions.
    
    try {
      // Example: 1. Chicken -> Tofu (For Vegetarians)
      // We look up the IDs dynamically
      final chicken = await db.query('ingredients', where: 'ingredientName LIKE ?', whereArgs: ['%Chicken%'], limit: 1);
      final tofu = await db.query('ingredients', where: 'ingredientName LIKE ?', whereArgs: ['%Tofu%'], limit: 1);

      if (chicken.isNotEmpty && tofu.isNotEmpty) {
        await db.insert('substitutions', {
          'original_ingredient_id': chicken.first['ingredientID'],
          'substitute_ingredient_id': tofu.first['ingredientID'],
          'equivalence_ratio': 1.0,
          'flavor_similarity': 0.6,
          'notes': 'Good vegetarian alternative',
          'confidence': 'high'
        });
      }

      // Example 2: Pork -> Chicken (For Halal)
      final pork = await db.query('ingredients', where: 'ingredientName LIKE ?', whereArgs: ['%Pork%'], limit: 1);
      
      if (pork.isNotEmpty && chicken.isNotEmpty) {
        await db.insert('substitutions', {
          'original_ingredient_id': pork.first['ingredientID'],
          'substitute_ingredient_id': chicken.first['ingredientID'],
          'equivalence_ratio': 1.0,
          'flavor_similarity': 0.8,
          'notes': 'Halal alternative',
          'confidence': 'high'
        });
      }
      
      print("✅ Substitutions table seeded successfully.");
    } catch (e) {
      print("⚠️ Error seeding substitutions: $e");
    }
  }

  // ========== CUSTOMIZED MEALS OPERATIONS ==========

  Future<int> saveCustomizedMeal({
    required int originalMealId,
    required int userId,
    required Map<String, String> originalIngredients,
    required Map<String, Map<String, dynamic>> substitutedIngredients,
    String? customizedName,
  }) async {
    final db = await database;
    
    // Deactivate locally
    await db.update(
      'customized_meals',
      {'is_active': 0},
      where: 'original_meal_id = ? AND user_id = ? AND is_active = 1',
      whereArgs: [originalMealId, userId],
    );

    // Save New Locally
    int id = await db.insert('customized_meals', {
      'original_meal_id': originalMealId,
      'user_id': userId,
      'customized_name': customizedName,
      'original_ingredients': jsonEncode(originalIngredients),
      'substituted_ingredients': jsonEncode(substitutedIngredients),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_active': 1,
    });

    try {
      Map<String, dynamic> cloudData = {
        'local_id': id,
        'original_meal_id': originalMealId,
        'user_id': userId,
        'customized_name': customizedName,
        'original_ingredients': jsonEncode(originalIngredients),
        'substituted_ingredients': jsonEncode(substitutedIngredients),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': 1,
      };

      // 1. Deactivate old cloud records for this user/meal
      // (This is tricky with Push IDs, so we query first)
      final oldRecords = await FirebaseDatabase.instance.ref("customized_meals")
          .orderByChild("user_id")
          .equalTo(userId)
          .get();
          
      if (oldRecords.exists) {
        for (var child in oldRecords.children) {
          final val = child.value as Map;
          if (val['original_meal_id'] == originalMealId && val['is_active'] == 1) {
            await child.ref.update({'is_active': 0});
          }
        }
      }

      // 2. Save New Record with Push ID
      await FirebaseDatabase.instance.ref("customized_meals").push().set(cloudData);
      print("🚀 Customized Meal synced safely");
    } catch (e) {
      print("⚠️ Offline: Customized Meal saved locally only.");
    }

    return id;
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
  
  // ========== INGREDIENT VARIATIONS EXPANSION ==========
  final Map<String, List<String>> _ingredientVariations = {
    'Chicken': [
      'Chicken (neck/wings)', 'Chicken neck', 'Chicken breast', 'Chicken wings', 
      'Chicken leg', 'Chicken feet', 'Chicken thigh', 'Chicken leg quarter',
      'Ground Chicken', 'Chicken'
    ],
    'Pork': [
      'Pork shoulder', 'Pork trotter', 'Pork tenderloin', 'Pork belly', 
      'Pork ribs', 'Ground Pork', 'Pork'
    ],
    'Beef': [
      'Beef chuck rib', 'Beef tender chuck', 'Beef brisket', 'Beef blade clod',
      'Beef short ribs', 'Beef sirloin', 'Beef tenderloin', 'Beef flank steak',
      'Ground Beef', 'Beef'
    ],
    'Fish': [
      'Fish', 'Bangus', 'Tilapia', 'Salmon', 'Tuna', 
      'Alumahan', 'Yellow Fin Tuna', 'Culisi', 'Galunggong', 'Gulyasan', 
      'Kubal-kubal', 'Lapu-Lapu', 'Malumbok', 'Matangbaka', 'Maya-maya', 
      'Mulmul', 'Samaral', 'Talakitok', 'Tamban', 'Tanigue', 'Tulingan', 
      'Sulig', 'Sapsap', 'Dilis', 'Dalagang bukid', 'Bisugo', 'Shark meat',
      'Sting ray'
    ],
    'Seafood': [
      'Fish', 'Bangus', 'Tilapia', 'Squid', 'Shrimp', 'Prawn', 'Crab',
      'Alumahan', 'Galunggong', 'Lapu-Lapu', 'Tanigue', 'Blue crab', 
      'Mud crab', 'Curacha', 'Shell', 'Oyster', 'Clams', 'Mussels'
    ],
    'Crab': [
      'Blue crab', 'Mud crab', 'Curacha', 'Crab'
    ],
    'Mungbeans': [
      'Mungbeans', 'Munggo', 'Mongo', 'Green mung bean'
    ],
    
  };

  // Method to expand general ingredients to specific variations
  Future<List<String>> expandIngredientVariations(List<String> detectedIngredients) async {
    List<String> expandedIngredients = [];
    
    for (var ingredient in detectedIngredients) {
      // Add the original detected ingredient
      expandedIngredients.add(ingredient);
      
      // Check if this ingredient has variations (case-insensitive)
      final normalizedIngredient = ingredient.toLowerCase();
      final matchingKey = _ingredientVariations.keys.firstWhere(
        (key) => key.toLowerCase() == normalizedIngredient,
        orElse: () => '',
      );
      
      if (matchingKey.isNotEmpty) {
        // Add all variations for this ingredient
        expandedIngredients.addAll(_ingredientVariations[matchingKey]!);
        print('Expanded $ingredient to: ${_ingredientVariations[matchingKey]}');
      }
    }
    
    // Remove duplicates and return
    return expandedIngredients.toSet().toList();
  }

  // Enhanced matching method
  bool _isIngredientMatch(String scannedIngredient, String recipeIngredient) {
    final scanned = scannedIngredient.toLowerCase().trim();
    final recipe = recipeIngredient.toLowerCase().trim();
    
    // Exact match
    if (scanned == recipe) return true;
    
    // Direct variation match using our mapping
    for (var variations in _ingredientVariations.values) {
      if (variations.any((v) => v.toLowerCase() == scanned) &&
          variations.any((v) => v.toLowerCase() == recipe)) {
        return true;
      }
    }
    
    // Contains match for general categories
    if ((scanned == 'chicken' && recipe.contains('chicken')) ||
        (scanned == 'pork' && recipe.contains('pork')) ||
        (scanned == 'beef' && recipe.contains('beef')) ||
        (scanned == 'fish' && recipe.contains('fish'))) {
      return true;
    }
    
    return false;
  }

  // ==========================================
  // 🔥 FIREBASE SYNC FUNCTIONS (WITH PLACEHOLDER FIX)
  // ==========================================

  Future<void> forceUploadToFirebase() async {
    final db = await database;
    print("🔥 Starting COMPLETE Cloud Sync...");

    // Helper to upload data OR create a placeholder if empty
    Future<void> uploadTable(String tableName, String firebaseNode) async {
      try {
        final data = await db.query(tableName);
        
        if (data.isNotEmpty) {
          // CASE 1: Data exists - Upload it normally
          for (var row in data) {
            dynamic key = row['id'] ?? row['mealID'] ?? row['userID'] ?? row['ingredientID'];
            if (key != null) {
              await FirebaseDatabase.instance.ref("$firebaseNode/$key").set(row);
            }
          }
          print("✅ $tableName uploaded (${data.length} items)");
        } else {
          // CASE 2: Table is empty - FORCE a placeholder so it appears in Firebase
          print("⚠️ $tableName is EMPTY. Creating placeholder...");
          
          await FirebaseDatabase.instance.ref("$firebaseNode/empty_placeholder").set({
            "status": "No data yet",
            "last_checked": DateTime.now().toIso8601String(),
            "note": "This record exists to keep the folder visible."
          });
        }
      } catch (e) {
        print("❌ Error uploading $tableName: $e");
      }
    }

    // --- 1. Core Data ---
    await uploadTable('users', 'users');
    await uploadTable('ingredients', 'ingredients');
    await uploadTable('meals', 'meals');
    await uploadTable('meal_ingredients', 'meal_ingredients');

    // --- 2. Information ---
    await uploadTable('faqs', 'faqs');
    await uploadTable('about_us', 'about_us');

    // --- 3. Substitution Engine ---
    await uploadTable('substitutions', 'substitutions');
    
    // We actually want REAL data for unit_conversions, see Step 2 below
    await uploadTable('unit_conversions', 'unit_conversions');

    // --- 4. User Logs ---
    await uploadTable('meal_substitution_log', 'meal_substitution_log');
    await uploadTable('customized_meals', 'customized_meals');

    print("🏁 FULL FIREBASE SYNC COMPLETE!");
  }

}