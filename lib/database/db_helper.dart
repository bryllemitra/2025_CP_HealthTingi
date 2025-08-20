import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _currentVersion = 7; 

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
     if (oldVersion < 6) {
    // Add this block to ensure new meals are inserted during upgrade
    await _insertIngredients(db);
    await _insertMeals(db);
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
        recentlyViewed TEXT,
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

    // Add new ingredients for the new meals
  await db.insert('ingredients', {
    'ingredientName': 'Chicken thigh',
    'price': 35.0,
    'calories': 209,
    'nutritionalValue': 'Good source of protein, iron, and zinc.',
    'ingredientPicture': 'assets/chicken_thigh.jpg',
    'category': 'main dish'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Bay leaf',
    'price': 2.0,
    'calories': 5,
    'nutritionalValue': 'Adds flavor, contains vitamin A, vitamin C, iron, potassium, calcium, and magnesium.',
    'ingredientPicture': 'assets/bay_leaf.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Peppercorns',
    'price': 3.0,
    'calories': 6,
    'nutritionalValue': 'Contains piperine which may improve nutrient absorption.',
    'ingredientPicture': 'assets/peppercorns.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Vinegar',
    'price': 5.0,
    'calories': 3,
    'nutritionalValue': 'May help lower blood sugar levels and aid in weight loss.',
    'ingredientPicture': 'assets/vinegar.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Glutinous rice',
    'price': 15.0,
    'calories': 169,
    'nutritionalValue': 'High in carbohydrates, provides energy.',
    'ingredientPicture': 'assets/glutinous_rice.jpg',
    'category': 'grain'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Coconut milk',
    'price': 20.0,
    'calories': 230,
    'nutritionalValue': 'Rich in healthy fats, manganese, and copper.',
    'ingredientPicture': 'assets/coconut_milk.jpg',
    'category': 'dairy alternative'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Brown sugar',
    'price': 10.0,
    'calories': 380,
    'nutritionalValue': 'Contains molasses which provides some minerals like calcium, potassium, iron and magnesium.',
    'ingredientPicture': 'assets/brown_sugar.jpg',
    'category': 'sweetener'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Sweet potato',
    'price': 12.0,
    'calories': 86,
    'nutritionalValue': 'High in fiber, vitamin A, vitamin C, and manganese.',
    'ingredientPicture': 'assets/sweet_potato.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Taro (gabi)',
    'price': 15.0,
    'calories': 112,
    'nutritionalValue': 'Good source of fiber, potassium, magnesium, and vitamins C and E.',
    'ingredientPicture': 'assets/taro.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Purple yam (ube)',
    'price': 18.0,
    'calories': 140,
    'nutritionalValue': 'Rich in antioxidants, vitamin C, and potassium.',
    'ingredientPicture': 'assets/ube.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Saba banana',
    'price': 10.0,
    'calories': 120,
    'nutritionalValue': 'Good source of potassium, vitamin C, and dietary fiber.',
    'ingredientPicture': 'assets/saba_banana.jpg',
    'category': 'fruit'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Jackfruit',
    'price': 25.0,
    'calories': 95,
    'nutritionalValue': 'Rich in vitamin C, potassium, dietary fiber, and some B vitamins.',
    'ingredientPicture': 'assets/jackfruit.jpg',
    'category': 'fruit'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Tapioca pearls',
    'price': 12.0,
    'calories': 135,
    'nutritionalValue': 'Mainly carbohydrates, provides energy.',
    'ingredientPicture': 'assets/tapioca_pearls.jpg',
    'category': 'thickener'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Pork belly',
    'price': 50.0,
    'calories': 518,
    'nutritionalValue': 'High in protein and fat, contains B vitamins and minerals like zinc and selenium.',
    'ingredientPicture': 'assets/pork_belly.jpg',
    'category': 'meat'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Shrimp paste (bagoong alamang)',
    'price': 15.0,
    'calories': 80,
    'nutritionalValue': 'Fermented shrimp paste rich in protein and probiotics. High in sodium.',
    'ingredientPicture': 'assets/shrimp_paste.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Thai chilies (labuyo)',
    'price': 5.0,
    'calories': 18,
    'nutritionalValue': 'Contains capsaicin which may boost metabolism and reduce inflammation.',
    'ingredientPicture': 'assets/thai_chilies.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Pork shoulder',
    'price': 45.0,
    'calories': 242,
    'nutritionalValue': 'Good source of protein, thiamine, and selenium.',
    'ingredientPicture': 'assets/pork_shoulder.jpg',
    'category': 'meat'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Tamarind',
    'price': 10.0,
    'calories': 143,
    'nutritionalValue': 'Rich in magnesium, potassium, iron, and calcium.',
    'ingredientPicture': 'assets/tamarind.jpg',
    'category': 'fruit, seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Kangkong (water spinach)',
    'price': 8.0,
    'calories': 19,
    'nutritionalValue': 'Rich in iron, vitamin C, vitamin A, and calcium.',
    'ingredientPicture': 'assets/kangkong.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Radish',
    'price': 7.0,
    'calories': 16,
    'nutritionalValue': 'Good source of vitamin C, folate, and potassium.',
    'ingredientPicture': 'assets/radish.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Eggplant',
    'price': 10.0,
    'calories': 25,
    'nutritionalValue': 'Good source of fiber, vitamins B1 and B6, and potassium.',
    'ingredientPicture': 'assets/eggplant.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Fish sauce',
    'price': 12.0,
    'calories': 5,
    'nutritionalValue': 'Fermented fish sauce rich in protein and probiotics. High in sodium.',
    'ingredientPicture': 'assets/fish_sauce.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'String beans',
    'price': 8.0,
    'calories': 31,
    'nutritionalValue': 'Good source of fiber, vitamin C, and vitamin K.',
    'ingredientPicture': 'assets/string_beans.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Squash',
    'price': 12.0,
    'calories': 45,
    'nutritionalValue': 'Rich in vitamin A, vitamin C, and potassium.',
    'ingredientPicture': 'assets/squash.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Coconut cream',
    'price': 15.0,
    'calories': 330,
    'nutritionalValue': 'Rich in healthy fats, manganese, and copper.',
    'ingredientPicture': 'assets/coconut_cream.jpg',
    'category': 'dairy alternative'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Bangus (milkfish)',
    'price': 60.0,
    'calories': 208,
    'nutritionalValue': 'Rich in omega-3 fatty acids, protein, and vitamin B12.',
    'ingredientPicture': 'assets/bangus.jpg',
    'category': 'seafood'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Tilapia',
    'price': 50.0,
    'calories': 96,
    'nutritionalValue': 'Good source of protein, vitamin B12, and selenium.',
    'ingredientPicture': 'assets/tilapia.jpg',
    'category': 'seafood'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Shrimp (hipon)',
    'price': 75.0,
    'calories': 99,
    'nutritionalValue': 'Low in calories, rich in protein, selenium, and vitamin B12.',
    'ingredientPicture': 'assets/shrimp.jpg',
    'category': 'seafood'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Eggs',
    'price': 7.0,
    'calories': 68,
    'nutritionalValue': 'Excellent source of protein, vitamin B12, and choline.',
    'ingredientPicture': 'assets/eggs.jpg',
    'category': 'protein'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Flour',
    'price': 5.0,
    'calories': 364,
    'nutritionalValue': 'Mainly carbohydrates, provides energy.',
    'ingredientPicture': 'assets/flour.jpg',
    'category': 'baking'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Squid',
    'price': 80.0,
    'calories': 92,
    'nutritionalValue': 'Low in fat, rich in protein, vitamin B12, and selenium.',
    'ingredientPicture': 'assets/squid.jpg',
    'category': 'seafood'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Alimango (crab)',
    'price': 60.0,
    'calories': 97,
    'nutritionalValue': 'Excellent source of protein, vitamin B12, and zinc.',
    'ingredientPicture': 'assets/crab.jpg',
    'category': 'seafood'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Red chili',
    'price': 5.0,
    'calories': 18,
    'nutritionalValue': 'Contains capsaicin which may boost metabolism and reduce inflammation.',
    'ingredientPicture': 'assets/red_chili.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Upo (bottle gourd)',
    'price': 15.0,
    'calories': 14,
    'nutritionalValue': 'Low in calories, contains vitamin C and calcium.',
    'ingredientPicture': 'assets/upo.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Ground pork',
    'price': 40.0,
    'calories': 297,
    'nutritionalValue': 'Good source of protein, thiamine, and selenium.',
    'ingredientPicture': 'assets/ground_pork.jpg',
    'category': 'meat'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Evaporated milk',
    'price': 15.0,
    'calories': 134,
    'nutritionalValue': 'Good source of calcium and vitamin D.',
    'ingredientPicture': 'assets/evaporated_milk.jpg',
    'category': 'dairy'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Condensed milk',
    'price': 18.0,
    'calories': 321,
    'nutritionalValue': 'High in sugar, provides calcium and protein.',
    'ingredientPicture': 'assets/condensed_milk.jpg',
    'category': 'dairy'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Ube ice cream',
    'price': 25.0,
    'calories': 180,
    'nutritionalValue': 'Contains calcium, but high in sugar.',
    'ingredientPicture': 'assets/ube_ice_cream.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Leche flan',
    'price': 30.0,
    'calories': 320,
    'nutritionalValue': 'Rich in protein and calcium, but high in sugar.',
    'ingredientPicture': 'assets/leche_flan.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Sweetened beans (mungo)',
    'price': 15.0,
    'calories': 105,
    'nutritionalValue': 'Good source of plant-based protein and fiber.',
    'ingredientPicture': 'assets/sweetened_beans.jpg',
    'category': 'legume'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Nata de coco',
    'price': 12.0,
    'calories': 60,
    'nutritionalValue': 'Low in calories, provides some fiber.',
    'ingredientPicture': 'assets/nata_de_coco.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Kaong (palm fruit)',
    'price': 15.0,
    'calories': 50,
    'nutritionalValue': 'Low in calories, provides some fiber.',
    'ingredientPicture': 'assets/kaong.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Macapuno (coconut sport)',
    'price': 18.0,
    'calories': 140,
    'nutritionalValue': 'Contains healthy fats and some fiber.',
    'ingredientPicture': 'assets/macapuno.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Gulaman',
    'price': 10.0,
    'calories': 70,
    'nutritionalValue': 'Low in calories, provides some fiber.',
    'ingredientPicture': 'assets/gulaman.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Shaved ice',
    'price': 2.0,
    'calories': 0,
    'nutritionalValue': 'No nutritional value.',
    'ingredientPicture': 'assets/shaved_ice.jpg',
    'category': 'dessert'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Carrots',
    'price': 10.0,
    'calories': 41,
    'nutritionalValue': 'Rich in beta-carotene, fiber, vitamin K1, and potassium.',
    'ingredientPicture': 'assets/carrots.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Bell pepper',
    'price': 15.0,
    'calories': 31,
    'nutritionalValue': 'Excellent source of vitamin C and vitamin A.',
    'ingredientPicture': 'assets/bell_pepper.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Sugar',
    'price': 5.0,
    'calories': 387,
    'nutritionalValue': 'Provides quick energy, but high in calories.',
    'ingredientPicture': 'assets/sugar.jpg',
    'category': 'sweetener'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Cornstarch',
    'price': 8.0,
    'calories': 381,
    'nutritionalValue': 'Mainly carbohydrates, used as thickener.',
    'ingredientPicture': 'assets/cornstarch.jpg',
    'category': 'thickener'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Chicken broth',
    'price': 10.0,
    'calories': 15,
    'nutritionalValue': 'Low in calories, provides some minerals.',
    'ingredientPicture': 'assets/chicken_broth.jpg',
    'category': 'soup base'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Oyster sauce',
    'price': 12.0,
    'calories': 51,
    'nutritionalValue': 'Adds umami flavor, contains some minerals but high in sodium.',
    'ingredientPicture': 'assets/oyster_sauce.jpg',
    'category': 'seasoning'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Broccoli',
    'price': 20.0,
    'calories': 55,
    'nutritionalValue': 'Rich in vitamins C and K, fiber, and antioxidants.',
    'ingredientPicture': 'assets/broccoli.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Cauliflower',
    'price': 18.0,
    'calories': 25,
    'nutritionalValue': 'Good source of fiber, vitamin C, and vitamin K.',
    'ingredientPicture': 'assets/cauliflower.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Cabbage',
    'price': 12.0,
    'calories': 25,
    'nutritionalValue': 'Rich in vitamin K, vitamin C, and fiber.',
    'ingredientPicture': 'assets/cabbage.jpg',
    'category': 'vegetable'
  });

  await db.insert('ingredients', {
    'ingredientName': 'Mushrooms',
    'price': 25.0,
    'calories': 22,
    'nutritionalValue': 'Low in calories, good source of B vitamins and selenium.',
    'ingredientPicture': 'assets/mushrooms.jpg',
    'category': 'vegetable'
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
1. Sauté garlic in oil until golden.
2. Add chicken, brown lightly.
3. Pour in soy sauce, vinegar, water. Add bay leaf & peppercorns.
4. Simmer 25–30 min until chicken is tender.
5. Reduce sauce for a few more minutes.
''',
    'hasDietaryRestrictions': 'Hypertension, Halal if using halal-certified chicken',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 11, // Chicken thigh
    'quantity': '2 pieces (≈300g)'
  });
  await db.insert('meal_ingredients', {
    'mealID': adobongManokId,
    'ingredientID': 6, // Garlic
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
1. Rinse rice and cook in coconut milk + water over medium heat.
2. Stir constantly until nearly cooked.
3. Add brown sugar + salt, continue stirring until mixture thickens.
4. Transfer to pan, press flat, top with latik if desired.
5. Bake 20–30 min at 180 °C or cool before slicing.
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
1. Combine coconut milk & water in pot; bring to simmer.
2. Add glutinous rice; stir occasionally ~10–15 min.
3. Add sweet potato, taro, ube; cook ~15–20 min until tender.
4. Stir in banana, jackfruit, sago; cook 5 min more.
5. Add sugar & salt; simmer until thickened. Serve warm or chilled.
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
    'ingredientID': 18, // Sweet potato
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 19, // Taro (gabi)
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 20, // Purple yam (ube)
    'quantity': '1 cup'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 21, // Saba banana
    'quantity': '2 pieces'
  });
  await db.insert('meal_ingredients', {
    'mealID': binignitId,
    'ingredientID': 22, // Jackfruit
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
1. Layer sweet beans, nata de coco, kaong, banana, jackfruit, macapuno, gulaman in tall glass.
2. Fill glass with shaved ice.
3. Drizzle evaporated or condensed milk.
4. Top with flan and ice cream if desired. Mix before eating.
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
    'category': 'Main Dish, Vegetables',
    'content': 'Stir-fried mixed vegetables with chicken/shrimp in savory sauce.',
    'instructions': '''
1. Sauté onion & garlic in oil until fragrant.
2. Add chicken or shrimp, cook until opaque.
3. Stir in vegetables & mushrooms; cook ~3–5 min.
4. Pour in broth + sauces; mix well.
5. Stir in cornstarch slurry; cook until sauce thickens. Season and serve.
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
1. Heat oil, sauté garlic, onion, ginger until aromatic.
2. Add pork and shrimp paste; cook 2 min.
3. Pour in coconut milk and bring to simmer.
4. Add taro leaves; do NOT stir for first 15 min—push leaves down.
5. Simmer 40–45 min until leaves absorb liquid and soften.
6. Stir in coconut cream & chilies; simmer 10 more min until sauce thickens. Season and serve.
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
1. Boil pork with water, tomato, onion until meat is tender (~40 min).
2. Add gabi, cook until slightly soft.
3. Add tamarind mix; simmer until broth turns sour.
4. Add veggies: radish/eggplant, then kangkong last.
5. Season with fish sauce; serve hot with rice.
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
1. Heat oil in a pan. Sauté garlic, onion, and ginger.
2. Add vegetables and stir-fry for 2–3 minutes.
3. Pour in coconut milk and simmer for 10–15 minutes.
4. Add coconut cream and season with salt and pepper.
5. Simmer until veggies are soft and sauce thickens.
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
1. Sauté garlic, onion, and tomato in oil.
2. Add pork or shrimp (if using), cook until brown.
3. Add kalabasa and water/broth.
4. Cover and simmer until tender.
5. Season with salt and pepper.
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
1. In a pot, boil water, tomato, and onion.
2. Add tamarind paste and stir.
3. Add bangus or fish of choice; simmer for 5–7 minutes.
4. Add vegetables; cook until tender.
5. Add kangkong and chili last. Season and serve.
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
1. Boil water with tomato and onion.
2. Add tamarind paste and let it dissolve.
3. Add shrimp and simmer for 5 minutes.
4. Add radish, eggplant, and sitaw.
5. Add kangkong and green chili, season, and serve hot.
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
1. Squeeze excess water from grated sayote.
2. Mix sayote with eggs, garlic, onion, flour, salt & pepper.
3. Heat oil in pan and spoon in mixture like patties.
4. Fry each side until golden brown.
5. Serve hot with ketchup or vinegar dip.
''',
    'hasDietaryRestrictions': 'Vegetarian, Halal',
    'availableFrom': '11:00',
    'availableTo': '13:00'
  });

  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 2, // Sayote
    'quantity': '2 medium'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 38, // Eggs
    'quantity': '3'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 6, // Garlic
    'quantity': '2 cloves'
  });
  await db.insert('meal_ingredients', {
    'mealID': tortangSayoteId,
    'ingredientID': 5, // Onion
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
1. Sauté garlic and onion in oil.
2. Add squid and cook for 1–2 minutes.
3. Add soy sauce, vinegar, and pepper (no stirring yet).
4. Let it boil, then simmer for 10–15 minutes.
5. Remove from heat once sauce reduces.
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
1. In a pot, marinate pork in soy sauce, vinegar, garlic, pepper, and bay leaves (10–15 mins).
2. Add water and bring to boil.
3. Simmer over low heat until pork is tender (30–40 mins).
4. Add oil, adjust seasoning, and reduce sauce.
5. Serve hot with rice.
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
1. Sauté garlic, onion, and ginger in oil.
2. Add alimango and cook for 5 minutes.
3. Pour in coconut milk and simmer for 15 minutes.
4. Add squash and sitaw, simmer until tender.
5. Add coconut cream and chili. Simmer until thick and fragrant.
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
1. Roll banana slices in sugar.
2. Heat oil in pan.
3. Fry bananas until golden and caramelized.
4. Drain on paper towel and serve hot.
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
1. Fry fish until golden. Set aside.
2. Sauté garlic, onion, carrots, and bell pepper.
3. Add soy sauce, vinegar, and sugar.
4. Add cornstarch slurry to thicken.
5. Pour sauce over fried fish and serve.
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
1. Sauté onion and garlic in oil.
2. Add kalabasa and stir for 2 minutes.
3. Add coconut milk and simmer.
4. Add sitaw and shrimp. Cook until tender.
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
1. Sauté garlic, onion, tomato in oil.
2. Add pork/shrimp until cooked.
3. Add upo, season, and simmer until soft.
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
1. Beat eggs and mix with malunggay leaves.
2. Heat oil and pour egg mix.
3. Fry until cooked and serve with rice.
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
    final meals = await db.query('meals');
    
    Set<String> uniqueCategories = {};
    for (var meal in meals) {
      final categories = (meal['category'] as String?)?.split(', ') ?? [];
      uniqueCategories.addAll(categories);
    }
    
    return uniqueCategories.toList()..sort();
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
}