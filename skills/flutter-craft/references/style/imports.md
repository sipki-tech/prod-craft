# Imports

Import directives define your file's dependencies. Strict import hygiene prevents namespace pollution, avoids naming collisions, and clarifies module boundaries.

**Use relative paths for files within the same sub-module.**
- **Reason:** Relative imports (`../` or `./`) make local file reorganizations easier and keep the package internally decoupled from its own pubspec name.
```dart
// Good (Inside lib/src/widgets/button.dart importing lib/src/widgets/theme.dart)
import 'theme.dart';
import '../utils/colors.dart';

// Bad
import 'package:my_app/src/widgets/theme.dart';
```

**Use `package:` imports when crossing major module boundaries or in `test/`.**
- **Reason:** `package:` imports act as absolute paths. Using them to cross high-level boundaries (e.g., from `test/` to `lib/`) prevents complex, brittle `../../../../` relative traversal.
```dart
// Good (Inside test/widgets/button_test.dart)
import 'package:my_app/widgets/button.dart';

// Bad
import '../../lib/widgets/button.dart';
```

**Group and alphabetize import directives.**
- **Reason:** Grouping dependencies conceptually separates framework code, third-party libraries, and internal logic. Let `dart format` handle this automatically.
```dart
// Good
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

// Bad (Mixed)
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user.dart';
```

**Use `show` or `hide` to restrict broad library imports.**
- **Reason:** Importing massive libraries dumps hundreds of symbols into your file's namespace, risking collisions. Be explicit about what you're consuming.
```dart
// Good
import 'package:path/path.dart' show join, basename;
import 'package:test/test.dart' hide Timeout;

// Bad
import 'package:path/path.dart'; // Imports everything
```

**Use `as` to prefix imports that cause naming collisions.**
- **Reason:** When multiple packages define the same class (like `Client`, `Response`, or `State`), prefixing keeps the usage explicit and disambiguates the source at the call site.
```dart
// Good
import 'package:http/http.dart' as http;

void fetchData() {
  final client = http.Client();
}

// Bad
import 'package:http/http.dart';

void fetchData() {
  // Ambiguous: Is this HTTP's Client or an internal Client?
  final client = Client();
}
```
