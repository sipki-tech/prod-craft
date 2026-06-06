# Accessibility & Semantics
Define clear, robust accessibility experiences using Semantics widgets, proper touch targets, and contrast ratios.

**Use descriptive labels without including widget type**
- **Reason:** Screen readers (like VoiceOver or TalkBack) automatically announce the type of the element (e.g., "button"). Including it in the label leads to redundant announcements.
```dart
// Good
Semantics(
  button: true,
  label: 'Submit form',
  child: const Icon(Icons.send),
)

// Bad
Semantics(
  button: true,
  label: 'Submit form button',
  child: const Icon(Icons.send),
)
```

**Distinguish between `label` and `hint` for interactive elements**
- **Reason:** The `label` identifies what the element *is*, while the `hint` describes what action will happen when interacted with. Separating these allows screen readers to pause between the identity and the instruction, giving users control over verbosity.
```dart
// Good
Semantics(
  button: true,
  label: 'Delete message',
  hint: 'Permanently removes the message from your inbox',
  child: const Icon(Icons.delete),
)

// Bad
Semantics(
  button: true,
  label: 'Delete message. Permanently removes the message from your inbox',
  child: const Icon(Icons.delete),
)
```

**Merge semantics for complex interactive widgets**
- **Reason:** When a single logical component (like a list tile or a card) consists of multiple elements, `MergeSemantics` prevents the screen reader from navigating them individually and instead presents them as one cohesive, actionable element.
```dart
// Good
MergeSemantics(
  child: Row(
    children: [
      Checkbox(value: isChecked, onChanged: toggle),
      const Text('Accept Terms and Conditions'),
    ],
  ),
)

// Bad
Row(
  children: [
    Checkbox(value: isChecked, onChanged: toggle), // Focuses separately
    const Text('Accept Terms and Conditions'), // Focuses separately
  ],
)
```

**Ensure minimum touch target size of 48x48 logical pixels**
- **Reason:** Elements smaller than 48x48 pixels are difficult to tap for users with motor impairments. Wrapping small icons or buttons in widgets that expand their hit test area (or using built-in padding) ensures compliance with accessibility guidelines.
```dart
// Good
IconButton(
  icon: const Icon(Icons.info),
  onPressed: showInfo,
  padding: const EdgeInsets.all(12),
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
)

// Bad
GestureDetector(
  onTap: showInfo,
  child: const Icon(Icons.info, size: 24), // Touch area is only 24x24
)
```

**Exclude decorative elements from semantic trees**
- **Reason:** Background images, decorative icons, and layout spacers create noise for screen reader users. Use `ExcludeSemantics` or set semantic properties to null/empty to hide them.
```dart
// Good
ExcludeSemantics(
  child: Image.asset('assets/decorative_swirl.png'),
)

// Bad
Image.asset(
  'assets/decorative_swirl.png',
  semanticLabel: 'A decorative swirl background', // Clutters screen reader output
)
```

**Provide adequate color contrast for text and icons**
- **Reason:** Text and essential icons must have a contrast ratio of at least 4.5:1 against their background (or 3:1 for large text) to be readable by users with low vision. Avoid relying solely on color to convey information.
```dart
// Good
Container(
  color: Colors.blue[900], // Dark background
  child: const Text(
    'Warning',
    style: TextStyle(color: Colors.white), // High contrast
  ),
)

// Bad
Container(
  color: Colors.blue[900], 
  child: Text(
    'Warning',
    style: TextStyle(color: Colors.blue[800]), // Fails contrast ratio checks
  ),
)
```

**Announce critical state changes using `SemanticsService.announce`**
- **Reason:** When the UI changes dynamically without user focus moving (e.g., a success message appears or a timer finishes), explicitly announcing the change ensures screen reader users are aware of the update.
```dart
// Good
void onTaskCompleted(BuildContext context) {
  setState(() => isDone = true);
  SemanticsService.announce(
    'Task completed successfully',
    Directionality.of(context),
  );
}

// Bad
void onTaskCompleted() {
  setState(() => isDone = true);
  // Visually changes UI, but screen reader users receive no feedback
}
```

**Manage semantic focus for custom dialogs and overlays**
- **Reason:** When opening a modal or custom overlay, use `Semantics(scopesRoute: true, explicitChildNodes: true)` or standard Flutter route mechanics to trap focus inside the dialog, preventing screen readers from navigating the obscured background.
```dart
// Good
Semantics(
  scopesRoute: true,
  explicitChildNodes: true,
  child: const MyCustomDialogWidget(),
)

// Bad
Stack(
  children: [
    const BackgroundUI(), // Screen reader can still access this!
    const MyCustomDialogWidget(),
  ],
)
```
