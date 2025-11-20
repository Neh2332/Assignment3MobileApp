/// A model class representing a menu item.
class MenuItem {
  final int id;
  final String name;
  final double cost;
  final String? category;
  final int? calories;

  MenuItem({
    required this.id,
    required this.name,
    required this.cost,
    this.category,
    this.calories,
  });

  /// Creates a [MenuItem] from a map.
  ///
  /// This factory constructor is used to deserialize a map (e.g., from a
  /// database query) into a [MenuItem] object.
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'],
      name: map['name'],
      cost: map['cost'],
      category: map['category'],
      calories: map['calories'],
    );
  }

  /// Converts a [MenuItem] to a map.
  ///
  /// This method is used to serialize a [MenuItem] object into a map
  /// (e.g., for inserting into a database).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cost': cost,
      'category': category,
      'calories': calories,
    };
  }
}