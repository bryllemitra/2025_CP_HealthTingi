import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _currentVersion = 4; // Updated version for picture additions

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'healthtingi.db');
    return await openDatabase(
      path,
      version: _currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDowngrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create tables in proper order considering foreign key dependencies
    await _createIngredientsTable(db);
    await _createMealsTable(db);
    await _createMealIngredientsTable(db);
    await _createUsersTable(db);
    await _insertInitialData(db);
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
        age INTEGER,
        gender TEXT,
        street TEXT,
        barangay TEXT,
        city TEXT,
        nationality TEXT,
        createdAt TEXT NOT NULL
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
        category TEXT
      )
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
        availableTo TEXT
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

  Future<void> _insertInitialData(Database db) async {
    // Insert ingredients
    await _insertIngredients(db);
    // Insert meals and their relationships
    await _insertMeals(db);
  }

  Future<void> _insertIngredients(Database db) async {
    // Chicken
    await db.insert('ingredients', {
      'ingredientName': 'Chicken (neck/wings)',
      'price': 30.0,
      'calories': 239,
      'nutritionalValue': 'Good source of protein, niacin, selenium, phosphorus, and vitamin B6.',
      'ingredientPicture': 'assets/chicken_neck_wings.jpg',
      'category': 'main dish'
    });

    // Sayote
    await db.insert('ingredients', {
      'ingredientName': 'Sayote',
      'price': 12.0,
      'calories': 19,
      'nutritionalValue': 'Rich in Vitamin C, Folate, Fiber, Potassium, Manganese.',
      'ingredientPicture': 'assets/sayote.jpg',
      'category': 'soup, main dish, appetizer'
    });

    // Malunggay
    await db.insert('ingredients', {
      'ingredientName': 'Malunggay',
      'price': 10.0,
      'calories': 64,
      'nutritionalValue': 'Rich in vitamins A, C, E, calcium, potassium, and protein. Boosts immunity and reduces inflammation.',
      'ingredientPicture': 'assets/malunggay.jpg',
      'category': 'soup, garnish'
    });

    // Ginger
    await db.insert('ingredients', {
      'ingredientName': 'Ginger',
      'price': 3.0,
      'calories': 80,
      'nutritionalValue': 'Contains gingerol with powerful anti-inflammatory and antioxidant effects. Aids digestion and nausea relief.',
      'ingredientPicture': 'assets/ginger.jpg',
      'category': 'spice, seasoning'
    });

    // Onion
    await db.insert('ingredients', {
      'ingredientName': 'Onion',
      'price': 5.0,
      'calories': 40,
      'nutritionalValue': 'Rich in vitamin C, B vitamins, and potassium. Contains antioxidants and compounds with anti-inflammatory effects.',
      'ingredientPicture': 'assets/onion.jpg',
      'category': 'seasoning, garnish'
    });

    // Garlic
    await db.insert('ingredients', {
      'ingredientName': 'Garlic',
      'price': 2.0,
      'calories': 149,
      'nutritionalValue': 'Contains allicin with medicinal properties. Boosts immune function and reduces blood pressure.',
      'ingredientPicture': 'assets/garlic.jpg',
      'category': 'seasoning'
    });

    // Cooking oil
    await db.insert('ingredients', {
      'ingredientName': 'Cooking oil',
      'price': 1.0,
      'calories': 884,
      'nutritionalValue': 'Source of healthy fats and vitamin E. Use in moderation.',
      'ingredientPicture': 'assets/cooking_oil.jpg',
      'category': 'cooking essential'
    });

    // Bagoong
    await db.insert('ingredients', {
      'ingredientName': 'Bagoong',
      'price': 10.0,
      'calories': 80,
      'nutritionalValue': 'Fermented fish paste rich in protein and probiotics. High in sodium.',
      'ingredientPicture': 'assets/bagoong.jpg',
      'category': 'seasoning'
    });

    // Tomato
    await db.insert('ingredients', {
      'ingredientName': 'Tomato',
      'price': 5.0,
      'calories': 18,
      'nutritionalValue': 'Rich in lycopene, vitamin C, potassium, and antioxidants. Supports heart health.',
      'ingredientPicture': 'assets/tomato.jpg',
      'category': 'vegetable, garnish'
    });

    // Soy Sauce
    await db.insert('ingredients', {
      'ingredientName': 'Soy Sauce',
      'price': 10.0,
      'calories': 53,
      'nutritionalValue': 'Contains antioxidants and may improve digestion. High in sodium.',
      'ingredientPicture': 'assets/soy_sauce.jpg',
      'category': 'seasoning'
    });
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
1. Prep the Ingredients
Peel and slice garlic, onion, and ginger.
Peel and slice sayote into wedges.
Wash and prepare greens (malunggay or pechay).

2. Sauté Aromatics
In a pot, heat 1 tbsp of oil.
Sauté garlic, onion, and ginger until fragrant.

3. Add the Chicken
Add chicken pieces. Sauté until slightly browned or no longer pink.
Season with a little salt or a splash of patis (optional).

4. Simmer
Pour in about 2–3 cups of water (just enough to cover the chicken).
Bring to a boil, then lower heat to simmer for 15–20 minutes until chicken is tender.

5. Add Sayote
Add sayote wedges and cook for another 5–7 minutes until tender.

6. Add Greens
Add malunggay or pechay, and simmer for another 1–2 minutes.
Adjust seasoning to taste.
''',
      'hasDietaryRestrictions': 'hypertension, chicken allergy',
      'availableFrom': '16:00',
      'availableTo': '19:00'
    });

    // Insert Tinolang Manok ingredients
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 1, // Chicken
      'quantity': '1/4 kg'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 2, // Sayote
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 4, // Ginger
      'quantity': '1 small thumb'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 5, // Onion
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 6, // Garlic
      'quantity': '2 cloves'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 7, // Cooking oil
      'quantity': '1 tbsp'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangId,
      'ingredientID': 3, // Malunggay
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

6. Taste and Adjust (Optional)
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
      'ingredientID': 2, // Sayote
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 8, // Bagoong
      'quantity': '1/4 tsp'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 5, // Onion
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 6, // Garlic
      'quantity': '4 cloves'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 9, // Tomato
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 7, // Cooking oil
      'quantity': '1/8 cup'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 10, // Soy Sauce
      'quantity': '1/4 cup'
    });
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
      SELECT i.*, mi.quantity 
      FROM ingredients i
      JOIN meal_ingredients mi ON i.ingredientID = mi.ingredientID
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
}