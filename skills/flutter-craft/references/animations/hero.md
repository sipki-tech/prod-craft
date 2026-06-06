# Hero Animations

Hero animations create seamless visual continuity across route transitions by physically "flying" a shared widget from the origin page to the destination page. They connect user context between completely different screens.

**Ensure Hero tags are strictly unique across the entire navigation stack.**
- **Reason:** Flutter matches Hero widgets between routes using their `tag`. If multiple widgets on the same page share a tag, Flutter throws a runtime exception because it cannot determine which widget should perform the flight.

```dart
// Good
// Using a unique domain identifier for the tag
Hero(
  tag: 'profile-avatar-${user.id}',
  child: Image.network(user.avatarUrl),
)

// Bad
// Using a generic tag in a list, resulting in duplicates on screen
ListView.builder(
  itemBuilder: (context, index) {
    return Hero(
      tag: 'profile-avatar', // Fails if more than one item is visible
      child: Image.network(users[index].avatarUrl),
    );
  },
)
```

**Use `flightShuttleBuilder` to gracefully handle shape and style transformations.**
- **Reason:** When a Hero flies between two widgets with dramatically different internal structures (e.g., text with different typography or a circular image to a square one), the default cross-fade can look broken. Providing a custom shuttle widget ensures visual polish during transit.

```dart
// Good
Hero(
  tag: 'title-${item.id}',
  flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
    return DefaultTextStyle(
      style: DefaultTextStyle.of(toHeroContext).style,
      child: toHeroContext.widget,
    );
  },
  child: Text('Item Title', style: destinationStyle),
)

// Bad
// Letting Flutter default-cross-fade complex widgets (like Text or Material) which often causes yellow underline errors or ugly rendering artifacts during the flight.
Hero(
  tag: 'title-${item.id}',
  child: Text('Item Title', style: destinationStyle),
)
```

**Wrap Hero children in `Material` widgets when flying Material design components.**
- **Reason:** Hero flight occurs in the `Overlay`, completely outside the standard page's `Material` tree. If the flying widget expects a Material ancestor (e.g., `InkWell`, `Text`), it will render incorrectly (e.g., with a yellow double-underline) unless explicitly wrapped.

```dart
// Good
Hero(
  tag: 'card-${item.id}',
  child: Material(
    color: Colors.transparent,
    child: Card(child: Text(item.name)),
  ),
)

// Bad
Hero(
  tag: 'card-${item.id}',
  child: Card(child: Text(item.name)), // May throw or show red/yellow warnings in transit due to missing Material scope
)
```
