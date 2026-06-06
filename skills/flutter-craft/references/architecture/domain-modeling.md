# Domain Modeling

Design your data structures to reflect business logic effectively, ensuring safety, validation, and immutability.

**Use freezed for immutable Domain Models**
- **Reason:** `freezed` generates `copyWith`, `==`, and `hashCode` automatically, eliminating boilerplate and ensuring value-equality which is critical for predictable state comparisons.

```dart
// Good
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required int age,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// Bad
class User {
  String id;
  String name;
  int age;
  // Missing copyWith, ==, hashCode, making state management brittle
}
```

**Use Value Objects for primitive obsession**
- **Reason:** Wrapping primitives in Value Objects ensures validation logic is centralized and domain models are always guaranteed to be in a valid state when instantiated.

```dart
// Good
class EmailAddress {
  final String value;
  EmailAddress(this.value) {
    if (!value.contains('@')) throw ArgumentError('Invalid email');
  }
}
class User {
  final EmailAddress email;
  User(this.email);
}

// Bad
class User {
  final String email; // Any random string can be passed here, validation happens elsewhere
  User(this.email);
}
```

**Keep business logic inside domain models**
- **Reason:** Anemic domain models (data structures with only getters/setters) lead to business logic bleeding into Services or Blocs. The domain model should own its invariants.

```dart
// Good
@freezed
class Cart with _$Cart {
  const factory Cart({required List<Item> items}) = _Cart;
  
  // Model owns its own logic
  double get totalPrice => items.fold(0, (sum, item) => sum + item.price);
}

// Bad
class CartService {
  // Logic separated from the data it operates on
  double calculateTotal(Cart cart) {
    return cart.items.fold(0, (sum, item) => sum + item.price);
  }
}
```
