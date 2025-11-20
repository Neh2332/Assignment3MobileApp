import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import '../models/menu_item.dart';

/// A screen that allows users to plan their meals based on a budget.
///
/// Users can select a date, set a budget, and choose from a list of menu items.
/// The screen displays the total cost of selected items and prevents exceeding the budget.
/// Users can also add custom items to their plan.
class PlannerScreen extends StatefulWidget {
  /// An optional initial plan to load for editing.
  final Map<String, dynamic>? initialPlan;

  const PlannerScreen({super.key, this.initialPlan});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _budgetController = TextEditingController();
  double _targetBudget = 0.0;
  double _currentTotal = 0.0;

  List<MenuItem> _menuItems = [];
  List<MenuItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
    _budgetController.addListener(() {
      setState(() {
        _targetBudget = double.tryParse(_budgetController.text) ?? 0.0;
      });
    });

    // Use a post-frame callback to safely access ModalRoute for initial plan data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPlan != null) {
        _loadInitialPlan();
      } else {
        final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
        if (arguments?['date'] != null) {
          setState(() {
            _selectedDate = arguments!['date'];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  /// Loads the initial plan data if provided, populating the form for editing.
  void _loadInitialPlan() {
    final order = widget.initialPlan!['order'] as Map<String, dynamic>;
    final items = widget.initialPlan!['items'] as List<MenuItem>;

    _selectedDate = DateFormat.yMMMd().parse(order['date']);
    _targetBudget = order['target_cost'];
    _budgetController.text = _targetBudget.toStringAsFixed(2);
    _selectedItems = List<MenuItem>.from(items);
    _currentTotal = _selectedItems.fold(0.0, (sum, item) => sum + item.cost);

    setState(() {});
  }

  /// Loads menu items from the database.
  Future<void> _loadMenuItems() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Database db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query('menu_items');
      setState(() {
        _menuItems = List.generate(maps.length, (i) {
          return MenuItem.fromMap(maps[i]);
        });
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading menu items: $e');
      Fluttertoast.showToast(msg: 'Error loading menu.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Shows a date picker to allow the user to select a date for the plan.
  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Adds a menu item to the current plan, checking against the budget.
  void _addItem(MenuItem item) {
    if (_targetBudget <= 0) {
      Fluttertoast.showToast(msg: "Please set a budget first.");
      return;
    }
    if (_currentTotal + item.cost > _targetBudget) {
      Fluttertoast.showToast(msg: "This exceeds your budget.");
    } else {
      setState(() {
        _selectedItems.add(item);
        _currentTotal += item.cost;
      });
    }
  }

  /// Saves the current plan to the database.
  void _savePlan() async {
    if (_selectedItems.isEmpty) {
      Fluttertoast.showToast(msg: "Please select at least one item.");
      return;
    }

    final date = DateFormat.yMMMd().format(_selectedDate);
    await DatabaseHelper().createOrder(date, _targetBudget, _selectedItems);

    Fluttertoast.showToast(
      msg: "Plan for $date saved!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    setState(() {
      _selectedItems.clear();
      _currentTotal = 0;
    });

    if (widget.initialPlan != null) {
      Navigator.of(context).pop();
    }
  }

  /// Shows a dialog to add a custom item to the menu.
  Future<void> _showAddCustomItemDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final costController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add Custom Item'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: costController,
                  decoration: const InputDecoration(labelText: 'Cost'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Please enter a valid cost' : null,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addItem(MenuItem(
                    id: -1, // Custom items have a temporary ID
                    name: nameController.text,
                    cost: double.parse(costController.text),
                  ));
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Returns an appropriate icon for a given menu item category.
  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Sushi':
        return Icons.set_meal_outlined;
      case 'Vegan':
        return Icons.eco_outlined;
      case 'Fast Food':
        return Icons.fastfood_outlined;
      case 'Italian':
        return Icons.local_pizza_outlined;
      case 'Salad':
        return Icons.grass_outlined;
      case 'Mexican':
        return Icons.tapas_outlined;
      case 'Thai':
        return Icons.ramen_dining_outlined;
      case 'Japanese':
        return Icons.rice_bowl_outlined;
      case 'Seafood':
        return Icons.restaurant_menu_outlined;
      case 'Breakfast':
        return Icons.egg_alt_outlined;
      case 'Soup':
        return Icons.soup_kitchen_outlined;
      case 'American':
        return Icons.lunch_dining_outlined;
      case 'British':
        return Icons.dinner_dining_outlined;
      case 'French':
        return Icons.bakery_dining_outlined;
      case 'Dessert':
        return Icons.cake_outlined;
      default:
        return Icons.restaurant_menu_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.initialPlan == null ? 'Order Planner' : 'Edit Plan'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialPlan == null ? 'Order Planner' : 'Edit Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add Custom Item',
            onPressed: () => _showAddCustomItemDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savePlan,
        label: Text(widget.initialPlan == null ? 'Save Plan' : 'Update Plan'),
        icon: const Icon(Icons.save),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Budget selection row
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat.yMMMd().format(_selectedDate)),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Budget', prefixIcon: Icon(Icons.attach_money)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Total cost and budget progress bar
            Text(
              'Total: \$${_currentTotal.toStringAsFixed(2)} / \$${_targetBudget.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _targetBudget > 0 ? _currentTotal / _targetBudget : 0,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
            // Display selected items if any
            if (_selectedItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Your Plan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedItems.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final item = _selectedItems[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\$${item.cost.toStringAsFixed(2)}'),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () => setState(() {
                              _currentTotal -= item.cost;
                              _selectedItems.removeAt(index);
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Display the list of available menu items
            Text('Menu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final canAfford = _targetBudget > 0 && (_currentTotal + item.cost <= _targetBudget);
                return Opacity(
                  opacity: canAfford ? 1.0 : 0.4,
                  child: Card(
                    child: ListTile(
                      leading: Icon(_getCategoryIcon(item.category)),
                      title: Text(item.name),
                      subtitle: Text(item.category ?? ''),
                      trailing: Text('\$${item.cost.toStringAsFixed(2)}'),
                      onTap: () => canAfford ? _addItem(item) : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}