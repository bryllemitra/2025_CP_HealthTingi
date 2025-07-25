import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('healthtingi.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Incremented version number
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        middleInitial TEXT,
        lastName TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        hasDietaryRestrictions INTEGER NOT NULL,
        dietaryRestriction TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create ingredients table
    await db.execute('''
      CREATE TABLE ingredients (
        ingredientID INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredientName TEXT NOT NULL UNIQUE,
        price REAL NOT NULL,
        calories INTEGER NOT NULL,
        nutritionalValue TEXT NOT NULL,
        ingredientPicture TEXT
      )
    ''');

    // Create meals table
    await db.execute('''
      CREATE TABLE meals (
        mealID INTEGER PRIMARY KEY AUTOINCREMENT,
        mealName TEXT NOT NULL UNIQUE,
        price REAL NOT NULL,
        calories INTEGER NOT NULL,
        servings TEXT NOT NULL,
        cookingTime TEXT NOT NULL,
        ingredientPrice REAL NOT NULL,
        hasDietaryRestrictions INTEGER NOT NULL,
        mealPicture TEXT,
        instructions TEXT NOT NULL
      )
    ''');

    // Create junction table for meal-ingredient relationships
    await db.execute('''
      CREATE TABLE meal_ingredients (
        mealID INTEGER,
        ingredientID INTEGER,
        quantity TEXT,
        PRIMARY KEY (mealID, ingredientID),
        FOREIGN KEY (mealID) REFERENCES meals (mealID) ON DELETE CASCADE,
        FOREIGN KEY (ingredientID) REFERENCES ingredients (ingredientID) ON DELETE CASCADE
      )
    ''');

    // Insert initial data
    await _insertInitialData(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE ingredients (
          ingredientID INTEGER PRIMARY KEY AUTOINCREMENT,
          ingredientName TEXT NOT NULL UNIQUE,
          price REAL NOT NULL,
          calories INTEGER NOT NULL,
          nutritionalValue TEXT NOT NULL,
          ingredientPicture TEXT
        )
      ''');
      
      await db.execute('''
        CREATE TABLE meals (
          mealID INTEGER PRIMARY KEY AUTOINCREMENT,
          mealName TEXT NOT NULL UNIQUE,
          price REAL NOT NULL,
          calories INTEGER NOT NULL,
          servings TEXT NOT NULL,
          cookingTime TEXT NOT NULL,
          ingredientPrice REAL NOT NULL,
          hasDietaryRestrictions INTEGER NOT NULL,
          mealPicture TEXT,
          instructions TEXT NOT NULL
        )
      ''');
      
      await db.execute('''
        CREATE TABLE meal_ingredients (
          mealID INTEGER,
          ingredientID INTEGER,
          quantity TEXT,
          PRIMARY KEY (mealID, ingredientID),
          FOREIGN KEY (mealID) REFERENCES meals (mealID) ON DELETE CASCADE,
          FOREIGN KEY (ingredientID) REFERENCES ingredients (ingredientID) ON DELETE CASCADE
        )
      ''');
      
      await _insertInitialData(db);
    }
  }

  Future _insertInitialData(Database db) async {
    // Insert ingredients
    final sayoteId = await db.insert('ingredients', {
      'ingredientName': 'Sayote',
      'price': 12.0,
      'calories': 19,
      'nutritionalValue': 'Rich in Vitamin C – boosts immune system and helps wound healing. Contains Folate (Vitamin B9) – important for cell growth and pregnancy. Low in Calories – good for weight management. High in Fiber – supports digestion and helps prevent constipation. Good source of Potassium – helps regulate blood pressure. Contains Manganese – supports metabolism and bone health. Mild Diuretic Effect – helps flush excess fluids. Supports Heart Health – due to its low sodium and fat content. May Help Control Blood Sugar – low glycemic index, good for diabetics.',
      'ingredientPicture': 'assets/ingredients/sayote.jpg'
    });

    final chickenId = await db.insert('ingredients', {
      'ingredientName': 'Chicken (neck/wings)',
      'price': 30.0,
      'calories': 239,
      'nutritionalValue': 'High in protein, contains B vitamins, particularly niacin and B6, which are important for energy production and brain health. Also provides selenium, which supports immune function.',
      'ingredientPicture': 'assets/ingredients/chicken.jpg'
    });

    final malunggayId = await db.insert('ingredients', {
      'ingredientName': 'Malunggay',
      'price': 10.0,
      'calories': 64,
      'nutritionalValue': 'Extremely rich in vitamins A, C, and E, calcium, potassium, and protein. Contains powerful antioxidants and has anti-inflammatory properties.',
      'ingredientPicture': 'assets/ingredients/malunggay.jpg'
    });

    final gingerId = await db.insert('ingredients', {
      'ingredientName': 'Ginger',
      'price': 3.0,
      'calories': 80,
      'nutritionalValue': 'Contains gingerol, a substance with powerful anti-inflammatory and antioxidant properties. May help reduce nausea, muscle pain, and lower blood sugar levels.',
      'ingredientPicture': 'assets/ingredients/ginger.jpg'
    });

    final onionId = await db.insert('ingredients', {
      'ingredientName': 'Onion',
      'price': 5.0,
      'calories': 40,
      'nutritionalValue': 'Rich in vitamin C, B vitamins, and potassium. Contains antioxidants and compounds that fight inflammation, reduce cholesterol, and may help lower blood sugar levels.',
      'ingredientPicture': 'assets/ingredients/onion.jpg'
    });

    final garlicId = await db.insert('ingredients', {
      'ingredientName': 'Garlic',
      'price': 2.0,
      'calories': 149,
      'nutritionalValue': 'Contains compounds with potent medicinal properties, including allicin. May help boost immune function, reduce blood pressure, and improve cholesterol levels.',
      'ingredientPicture': 'assets/ingredients/garlic.jpg'
    });

    final oilId = await db.insert('ingredients', {
      'ingredientName': 'Cooking oil',
      'price': 1.0,
      'calories': 120,
      'nutritionalValue': 'Provides essential fatty acids and helps with absorption of fat-soluble vitamins. Should be consumed in moderation.',
      'ingredientPicture': 'assets/ingredients/oil.jpg'
    });

    final bagoongId = await db.insert('ingredients', {
      'ingredientName': 'Bagoong',
      'price': 10.0,
      'calories': 80,
      'nutritionalValue': 'Fermented fish or shrimp paste that adds umami flavor. High in sodium but provides some protein and minerals.',
      'ingredientPicture': 'assets/ingredients/bagoong.jpg'
    });

    final tomatoId = await db.insert('ingredients', {
      'ingredientName': 'Tomato',
      'price': 5.0,
      'calories': 18,
      'nutritionalValue': 'Excellent source of vitamin C, potassium, folate, and vitamin K. Contains lycopene, a powerful antioxidant.',
      'ingredientPicture': 'assets/ingredients/tomato.jpg'
    });

    final soySauceId = await db.insert('ingredients', {
      'ingredientName': 'Soy Sauce',
      'price': 10.0,
      'calories': 10,
      'nutritionalValue': 'Contains small amounts of protein and minerals but is high in sodium. Provides umami flavor to dishes.',
      'ingredientPicture': 'assets/ingredients/soy_sauce.jpg'
    });

    // Insert meals
    final tinolangManokId = await db.insert('meals', {
      'mealName': 'Tinolang Manok',
      'price': 65.0,
      'calories': 350,
      'servings': '1-2 serving',
      'cookingTime': '15-20 minutes',
      'ingredientPrice': 65.0,
      'hasDietaryRestrictions': 0,
      'mealPicture': 'assets/tinolang_manok.jpg',
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
'''
    });

    final ginisangSayoteId = await db.insert('meals', {
      'mealName': 'Ginisang Sayote',
      'price': 57.0,
      'calories': 250,
      'servings': '1-2 serving',
      'cookingTime': '10-15 minutes',
      'ingredientPrice': 57.0,
      'hasDietaryRestrictions': 0,
      'mealPicture': 'assets/ginisang_sayote.jpg',
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
'''
    });

    // Insert meal-ingredient relationships for Tinolang Manok
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': chickenId,
      'quantity': '1/4 kg'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': sayoteId,
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': malunggayId,
      'quantity': '1 small bundle'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': gingerId,
      'quantity': '1 small thumb'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': onionId,
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': garlicId,
      'quantity': '2 cloves'
    });
    await db.insert('meal_ingredients', {
      'mealID': tinolangManokId,
      'ingredientID': oilId,
      'quantity': '1 tbsp'
    });

    // Insert meal-ingredient relationships for Ginisang Sayote
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': sayoteId,
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': bagoongId,
      'quantity': '1/4 tsp'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': onionId,
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': garlicId,
      'quantity': '4 cloves'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': tomatoId,
      'quantity': '1 small'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': oilId,
      'quantity': '1/8 cup'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangSayoteId,
      'ingredientID': soySauceId,
      'quantity': '1/4 cup'
    });
  }

  // User operations (existing)
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.insert('users', user);
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Meal operations
  Future<List<Map<String, dynamic>>> getAllMeals() async {
    final db = await instance.database;
    return await db.query('meals');
  }

  Future<Map<String, dynamic>?> getMealById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'meals',
      where: 'mealID = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getMealIngredients(int mealId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT i.*, mi.quantity 
      FROM ingredients i
      JOIN meal_ingredients mi ON i.ingredientID = mi.ingredientID
      WHERE mi.mealID = ?
    ''', [mealId]);
  }

  // Ingredient operations
  Future<List<Map<String, dynamic>>> getAllIngredients() async {
    final db = await instance.database;
    return await db.query('ingredients');
  }

  Future<Map<String, dynamic>?> getIngredientById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'ingredients',
      where: 'ingredientID = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}