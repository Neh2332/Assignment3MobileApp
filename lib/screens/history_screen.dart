import 'package:assignment3mobileapplication/screens/planner_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/menu_item.dart';

/// A screen that displays a history of saved meal plans.
///
/// Users can view a list of past plans, see the details of each plan,
/// edit a plan, or delete it.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<String> _savedDates = [];
  String? _selectedDateStr;

  // State for viewing a single plan's details
  Map<String, dynamic>? _order;
  List<MenuItem> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _loadSavedDates();
  }

  /// Loads the dates of all saved orders from the database.
  Future<void> _loadSavedDates() async {
    setState(() {
      _isLoading = true;
    });
    final dates = await DatabaseHelper().getSavedOrderDates();
    setState(() {
      _savedDates = dates;
      _isLoading = false;
    });
  }

  /// Loads the details of a specific plan for a given date.
  Future<void> _loadPlanDetails(String dateStr) async {
    setState(() {
      _isLoading = true;
      _selectedDateStr = dateStr;
    });

    final dbHelper = DatabaseHelper();
    final orderData = await dbHelper.getOrderByDate(dateStr);

    if (orderData != null) {
      final items = await dbHelper.getOrderItems(orderData['id']);
      setState(() {
        _order = orderData;
        _orderItems = items;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Clears the currently viewed plan details and returns to the list of saved plans.
  void _clearPlanDetails() {
    setState(() {
      _selectedDateStr = null;
      _order = null;
      _orderItems.clear();
      // Refresh the list of dates in case one was deleted.
      _loadSavedDates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedDateStr == null ? 'Plan History' : 'Plan for $_selectedDateStr'),
        leading: _selectedDateStr != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _clearPlanDetails,
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedDates,
        color: Colors.black,
        child: _buildContent(),
      ),
    );
  }

  /// Builds the main content of the screen, either the list of saved plans or the details of a selected plan.
  Widget _buildContent() {
    if (_isLoading && _savedDates.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (_selectedDateStr != null) {
      return _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.black)) : _buildPlanDetails();
    }

    if (_savedDates.isEmpty) {
      return const Center(
        child: Text(
          'No saved plans yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _savedDates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dateStr = _savedDates[index];
        return Card(
          elevation: 1,
          child: ListTile(
            title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _loadPlanDetails(dateStr),
          ),
        );
      },
    );
  }

  /// Builds the detailed view of a selected plan.
  Widget _buildPlanDetails() {
    if (_order == null) {
      // This can happen if a plan was deleted.
      return const Center(child: Text('Plan not found.'));
    }
    double totalSpent = _orderItems.fold(0.0, (sum, item) => sum + item.cost);
    double budget = _order!['target_cost'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Summary', style: Theme.of(context).textTheme.titleLarge),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Edit Plan',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlannerScreen(
                                  initialPlan: {'order': _order, 'items': _orderItems},
                                ),
                              ),
                            );
                            // After returning from edit, refresh the view.
                            _loadPlanDetails(_selectedDateStr!);
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete Plan',
                          icon: Icon(Icons.delete_outline, color: Colors.red[800]),
                          onPressed: () => _confirmDelete(context, _order!['id']),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                // Display the summary of spending vs budget.
                Text.rich(
                  TextSpan(
                    text: 'Spent: ',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    children: <TextSpan>[
                      TextSpan(
                        text: '\$${totalSpent.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: totalSpent > budget ? Colors.red[800] : Colors.black),
                      ),
                      TextSpan(text: ' of \$${budget.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar for spending.
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: budget > 0 ? totalSpent / budget : 0,
                    minHeight: 10,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalSpent > budget ? Colors.red[800]! : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // List of items in the plan.
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderItems.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final item = _orderItems[index];
              return ListTile(
                title: Text(item.name),
                trailing: Text('\$${item.cost.toStringAsFixed(2)}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before deleting a plan.
  Future<void> _confirmDelete(BuildContext context, int orderId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Delete Plan'),
          content: const Text('Are you sure you want to permanently delete this plan?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red[800]),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                await DatabaseHelper().deleteOrder(orderId);
                _clearPlanDetails(); // Go back to the list and refresh
              },
            ),
          ],
        );
      },
    );
  }
}
