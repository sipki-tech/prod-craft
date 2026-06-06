# Continuous Integration

Continuous Integration (CI) automates the validation of every code change by running formatting checks, static analysis, and test suites. This ensures that the main branch remains stable and regressions are caught before reaching production.

**Run formatting, analysis, and tests in CI pipelines**
- **Reason:** Automating these checks ensures that no code is merged unless it passes the project's quality standards, preventing regressions and maintaining a healthy codebase.
```yaml
# Good
jobs:
  build:
    steps:
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
```
```yaml
# Bad
jobs:
  build:
    steps:
      - run: flutter build apk # Skipping tests and analysis
```

**Use strict analysis flags in CI**
- **Reason:** Running the analyzer with strict flags ensures that all type errors and lint violations are caught, preventing silent failures from entering the main branch.
```bash
# Good
flutter analyze --fatal-infos --fatal-warnings
```
```bash
# Bad
flutter analyze # Warnings might be ignored
```
