import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/menu_item.dart';

/// A helper class to manage the SQLite database.
///
/// This class follows the singleton pattern to ensure only one instance of the
/// database helper is used throughout the application. It handles database
/// creation, seeding, and provides methods for CRUD operations on the
/// `menu_items`, `user_orders`, and `user_order_items` tables.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// Returns the singleton instance of the database.
  ///
  /// If the database has not been initialized, this method will call
  /// `_initDatabase` to create it.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database.
  ///
  /// This method gets the path to the database and opens it. It also sets up
  /// the `onCreate` and `onUpgrade` callbacks.
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'meal_planner.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Handles database upgrades.
  ///
  /// This method drops all existing tables and recreates them. This is a simple
  /// migration strategy suitable for development, but a more robust solution
  /// would be needed for a production application.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS user_order_items');
    await db.execute('DROP TABLE IF EXISTS user_orders');
    await db.execute('DROP TABLE IF EXISTS menu_items');
    await _onCreate(db, newVersion);
  }

  /// Creates the database tables.
  ///
  /// This method is called when the database is first created. It defines the
  /// schema for the `menu_items`, `user_orders`, and `user_order_items` tables.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE menu_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cost REAL NOT NULL,
        category TEXT,
        calories INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE user_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        target_cost REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        menu_item_id INTEGER,
        custom_name TEXT,
        custom_cost REAL,
        FOREIGN KEY (order_id) REFERENCES user_orders (id),
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id)
      )
    ''');

    await _seedDatabase(db);
  }

  
  /// This method populates the `menu_items` table with a predefined list of menu items.
  Future<void> _seedDatabase(Database db) async {
    List<Map<String, dynamic>> menuItems = [
      {'name': 'Spicy Tuna Roll', 'cost': 8.50, 'category': 'Sushi', 'calories': 300},
      {'name': 'Quinoa Power Bowl', 'cost': 12.00, 'category': 'Vegan', 'calories': 450},
      {'name': 'Artisan Cheeseburger', 'cost': 10.50, 'category': 'Fast Food', 'calories': 600},
      {'name': 'Margherita Pizza', 'cost': 14.00, 'category': 'Italian', 'calories': 800},
      {'name': 'Chicken Caesar Salad', 'cost': 9.75, 'category': 'Salad', 'calories': 350},
      {'name': 'Beef Tacos (3)', 'cost': 7.50, 'category': 'Mexican', 'calories': 480},
      {'name': 'Pad Thai', 'cost': 11.25, 'category': 'Thai', 'calories': 550},
      {'name': 'Miso Soup', 'cost': 3.50, 'category': 'Japanese', 'calories': 80},
      {'name': 'Falafel Wrap', 'cost': 8.00, 'category': 'Vegan', 'calories': 400},
      {'name': 'Grilled Salmon', 'cost': 15.50, 'category': 'Seafood', 'calories': 500},
      {'name': 'Avocado Toast', 'cost': 6.75, 'category': 'Breakfast', 'calories': 250},
      {'name': 'Clam Chowder', 'cost': 5.50, 'category': 'Soup', 'calories': 320},
      {'name': 'BBQ Ribs', 'cost': 18.00, 'category': 'American', 'calories': 900},
      {'name': 'Veggie Burger', 'cost': 9.00, 'category': 'Vegan', 'calories': 420},
      {'name': 'Fish and Chips', 'cost': 13.25, 'category': 'British', 'calories': 750},
      {'name': 'Sashimi Platter', 'cost': 16.50, 'category': 'Sushi', 'calories': 400},
      {'name': 'French Onion Soup', 'cost': 6.00, 'category': 'French', 'calories': 380},
      {'name': 'Steak Frites', 'cost': 22.00, 'category': 'French', 'calories': 850},
      {'name': 'Mushroom Risotto', 'cost': 12.50, 'category': 'Italian', 'calories': 600},
      {'name': 'Chocolate Lava Cake', 'cost': 7.00, 'category': 'Dessert', 'calories': 450}
    ];

    for (var item in menuItems) {
      await db.insert('menu_items', item);
    }
  }

  /// Clears all orders for a given date.
  ///
  /// This method is used to ensure that there is only one order per day.
  Future<void> clearTodaysOrders(String date) async {
    final db = await database;
    final orders = await db.query('user_orders', where: 'date = ?', whereArgs: [date]);
    if (orders.isNotEmpty) {
      for (var order in orders) {
        final orderId = order['id'] as int;
        await db.delete('user_order_items', where: 'order_id = ?', whereArgs: [orderId]);
      }
      await db.delete('user_orders', where: 'id = ?', whereArgs: [orders.first['id']]);
    }
  }

  /// Creates a new order.
  ///
  /// This method first clears any existing orders for the given date, then
  /// creates a new order and inserts the associated menu items.
  Future<int> createOrder(String date, double targetCost, List<MenuItem> items) async {
    final db = await database;
    await clearTodaysOrders(date);

    final orderId = await db.insert('user_orders', {
      'date': date,
      'target_cost': targetCost,
    });

    for (var item in items) {
      if (item.id == -1) { // Custom item
        await db.insert('user_order_items', {
          'order_id': orderId,
          'custom_name': item.name,
          'custom_cost': item.cost,
        });
      } else { // Regular item from the menu
        await db.insert('user_order_items', {
          'order_id': orderId,
          'menu_item_id': item.id,
        });
      }
    }
    return orderId;
  }

  /// Retrieves an order by its date.
  Future<Map<String, dynamic>?> getOrderByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> orders = await db.query(
      'user_orders',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (orders.isNotEmpty) {
      return orders.first;
    }
    return null;
  }

  /// Retrieves all items for a given order.
  Future<List<MenuItem>> getOrderItems(int orderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT mi.id, mi.name, mi.cost, mi.category, mi.calories, uoi.custom_name, uoi.custom_cost
      FROM user_order_items uoi
      LEFT JOIN menu_items mi ON mi.id = uoi.menu_item_id
      WHERE uoi.order_id = ?
    ''', [orderId]);

    return List.generate(maps.length, (i) {
      return MenuItem.fromMap(maps[i]);
    });
  }

  /// Retrieves a list of all dates with saved orders.
  Future<List<String>> getSavedOrderDates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_orders',
      columns: ['date'],
      distinct: true,
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => maps[i]['date'] as String);
  }

  /// Deletes an order and its associated items.
  Future<void> deleteOrder(int orderId) async {
    final db = await database;
    await db.delete('user_order_items', where: 'order_id = ?', whereArgs: [orderId]);
    await db.delete('user_orders', where: 'id = ?', whereArgs: [orderId]);
  }
}