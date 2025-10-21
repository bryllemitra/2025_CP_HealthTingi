import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _currentVersion = 13; 

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
    await _insertAdminUser(db);
    await _insertInitialData(db);
    await _insertInitialFaqs(db);
    await _insertInitialAboutUs(db);
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
      final adminPassword = _hashPassword('admin123'); // Default admin password
      
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
        'isAdmin': 1, // Mark as admin
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
        additionalPictures TEXT
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
        'answer': 'HealthTingi is an Android app that helps you scan ingredients using your phone’s camera and suggests budget-friendly recipes you can cook with them—even without an internet connection.',
        'order_num': 1
      },
      {
        'question': '2. Who is the app for?',
        'answer': 'It’s specially designed for low-income Filipino households, but anyone looking for affordable and nutritious meals can use it.',
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
        'question': '5. Can I still get recipe suggestions if I don’t have a complete ingredient list?',
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
        'answer': 'Yes, you can suggest recipes or feedback through the app’s “Contact Us” feature (if included), or by email.',
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
          'By combining real-time ingredient recognition, a local price-aware recipe engine, and offline access, HealthTingi empowers families to make the most of what’s available—whether in urban or rural communities. Our mission is to use simple technology to address food insecurity, improve nutrition, and support smarter meal planning across the Philippines.'
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
      
      for (var ingredient in data['ingredients']) {
        await db.insert('ingredients', ingredient);
      }
      print('Ingredients loaded successfully from JSON');
    } catch (e) {
      print('Error loading ingredients from JSON: $e');
      // Fallback to hardcoded ingredients if JSON fails
      await _insertIngredients(db);
    }
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
      'ingredientID': 7, // Cooking oil
      'quantity': '1/8 cup'
    });
    await db.insert('meal_ingredients', {
      'mealID': ginisangId,
      'ingredientID': 10, // Soy Sauce
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
    'ingredientID': 12, // Bay leaf
    'quantity': '1 leaf'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 13, // Peppercorns
    'quantity': '½ tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 10, // Soy sauce
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 14, // Vinegar
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 15, // Glutinous rice
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': bikoId,
    'ingredientID': 16, // Coconut milk
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': bikoId,
    'ingredientID': 17, // Brown sugar
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
    'ingredientID': 15, // Glutinous rice
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
    'ingredientID': 23, // Tapioca pearls
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 16, // Coconut milk
    'quantity': '4 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 17, // Brown sugar
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
    'ingredientID': 57, // Sweetened beans (mungo)
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
    'ingredientID': 21, // Saba banana
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': haloHaloId,
    'ingredientID': 22, // Jackfruit
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
    'ingredientID': 55, // Evaporated milk
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
    'ingredientID': 11, // Chicken thigh
    'quantity': '100g'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 52, // Carrots
    'quantity': '⅓ piece'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 53, // Broccoli
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 54, // Cauliflower
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 55, // Bell pepper
    'quantity': '½ small'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 56, // Cabbage
    'quantity': '½ small'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 57, // Mushrooms
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 5, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 10, // Soy sauce
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 58, // Oyster sauce
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 59, // Cornstarch
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 60, // Chicken broth
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': chopsueyId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 7, // Cooking oil
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 6, // Garlic
    'quantity': '4 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 5, // Onion
    'quantity': '1 medium'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 4, // Ginger
    'quantity': '1 thumb'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 24, // Pork belly
    'quantity': '100g'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 25, // Shrimp paste
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 16, // Coconut milk
    'quantity': '3 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 26, // Coconut cream
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': laingId,
    'ingredientID': 27, // Thai chilies
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
    'ingredientID': 24, // Pork belly
    'quantity': '300g'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 9, // Tomato
    'quantity': '1 medium'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 5, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 28, // Tamarind
    'quantity': '2 tbsp mix or fresh'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 29, // Kangkong
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 19, // Gabi (taro)
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 30, // Radish
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 31, // Eggplant
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangBaboyId,
    'ingredientID': 32, // Fish sauce
    'quantity': 'To taste'
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
    'ingredientID': 33, // String beans
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 34, // Squash
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 31, // Eggplant
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 16, // Coconut milk
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 26, // Coconut cream
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 5, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 4, // Ginger
    'quantity': '1 thumb'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangGulayId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 34, // Kalabasa (squash)
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 9, // Tomato
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 5, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 7, // Cooking oil
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangKalabasaId,
    'ingredientID': 35, // Ground pork or shrimp
    'quantity': '½ cup (optional)'
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
    'ingredientID': 36, // Bangus or tilapia
    'quantity': '2 medium slices'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 9, // Tomato
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 5, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 28, // Tamarind paste
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 29, // Kangkong
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 30, // Radish
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 31, // Eggplant
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 27, // Green chili
    'quantity': '1 (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangIsdaId,
    'ingredientID': 32, // Fish sauce
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
    'ingredientID': 37, // Shrimp
    'quantity': '250g'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 9, // Tomato
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 5, // Onion
    'quantity': '½'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 29, // Kangkong
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 33, // Sitaw
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 30, // Radish
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 31, // Eggplant
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 28, // Tamarind paste
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 27, // Green chili
    'quantity': '1 (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': sinigangHiponId,
    'ingredientID': 32, // Fish sauce
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
Place a non-stick pan over medium heat and add enough cooking oil to coat the surface.
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
    'ingredientID': 177, // Eggs
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
    'ingredientID': 39, // Flour
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 40, // Squid
    'quantity': '300g'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 5, // Onion
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 10, // Soy sauce
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 14, // Vinegar
    'quantity': '2 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 13, // Black pepper
    'quantity': '½ tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 9, // Tomato
    'quantity': '1 small (optional)'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongPusitId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 24, // Pork belly
    'quantity': '500g'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 10, // Soy sauce
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 14, // Vinegar
    'quantity': '3 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 12, // Bay leaves
    'quantity': '2'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 13, // Peppercorns
    'quantity': '1 tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongBaboyId,
    'ingredientID': 7, // Cooking oil
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
Pour in the coconut milk and bring to a gentle boil.
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
    'ingredientID': 41, // Alimango/crab
    'quantity': '2 pcs'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 16, // Coconut milk
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 26, // Coconut cream
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 34, // Squash
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 33, // Sitaw
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 42, // Red chili
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 5, // Onion
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 4, // Ginger
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangAlimangoId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 21, // Saba banana
    'quantity': '4 pcs'
  });
  await db.insert('meal_ingredients', {
    'mealID': sagingPritoId,
    'ingredientID': 17, // Brown sugar
    'quantity': '3 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': sagingPritoId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 36, // Tilapia or bangus
    'quantity': '2 pcs'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 52, // Carrots
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 55, // Bell pepper
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 5, // Onion
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 6, // Garlic
    'quantity': '3 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 14, // Vinegar
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 10, // Soy sauce
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 43, // Sugar
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 59, // Cornstarch
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': escabecheId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 34, // Kalabasa
    'quantity': '1½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 33, // Sitaw
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 16, // Coconut milk
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 5, // Onion
    'quantity': '1'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 6, // Garlic
    'quantity': '2 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 7, // Cooking oil
    'quantity': '1 tbsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginataangKalabasaId,
    'ingredientID': 37, // Shrimp
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
    'ingredientID': 44, // Upo
    'quantity': '2 cups'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 9, // Tomato
    'quantity': '1 small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 6, // Garlic
    'quantity': '2 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 5, // Onion
    'quantity': '½ small'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 35, // Ground pork or shrimp
    'quantity': '½ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': ginisangUpoId,
    'ingredientID': 7, // Cooking oil
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
    'ingredientID': 3, // Malunggay
    'quantity': '¼ cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': friedEggMalunggayId,
    'ingredientID': 7, // Cooking oil
    'quantity': '1 tsp'
  });
  await db.insert('meal_ingredients', {
    'mealID': friedEggMalunggayId,
    'ingredientID': 6, // Garlic bits (optional)
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

}