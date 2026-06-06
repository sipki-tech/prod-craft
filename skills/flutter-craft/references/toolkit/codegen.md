# Code Generation

Code generation automates the creation of boilerplate for data classes, routing, and dependency injection. It relies on tools like `build_runner` to produce deterministic, optimized output from annotations, significantly reducing human error.

**Exclude generated files from linting**
- **Reason:** Generated files (like `.g.dart` or `.freezed.dart`) often contain code that violates strict linting rules, but they are not meant to be read or modified by humans. Linting them creates unnecessary noise.
```yaml
# Good
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```
```yaml
# Bad
# Linting generated files
analyzer:
  exclude: []
```

**Use `build_runner` with delete-conflicting-outputs**
- **Reason:** When generating code, stale output files can cause unexpected errors or conflicts. Always use the `--delete-conflicting-outputs` flag to ensure a clean build state.
```bash
# Good
dart run build_runner build --delete-conflicting-outputs
```
```bash
# Bad
dart run build_runner build
```

**Commit generated code to version control**
- **Reason:** Committing generated files ensures that CI systems and other developers can build the project immediately without needing to run code generation steps, speeding up the workflow and ensuring determinism.
```yaml
# Good
# Keep generated files in the repository
```
```gitignore
# Bad
# Adding to .gitignore
*.g.dart
*.freezed.dart
```
