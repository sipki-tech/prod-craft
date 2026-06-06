# Linting

Linting enforces a consistent code style and catches potential errors before runtime through static analysis. A strict analysis configuration ensures that the entire team adheres to the same quality standards and architectural boundaries.

**Use strict linting rules like `very_good_analysis`**
- **Reason:** Strict linting enforces a consistent code style across the entire project, prevents common bugs, and reduces code review time by catching formatting and style issues automatically.
```yaml
# Good
include: package:very_good_analysis/analysis_options.10.3.0.yaml
```
```yaml
# Bad
# No analysis_options.yaml or using weak default lints
include: package:flutter_lints/flutter.yaml
```

**Configure custom lint rules in `analysis_options.yaml`**
- **Reason:** While pre-packaged lints are a good starting point, some projects may require custom exclusions (like generated code) or enabling specific rules that match the team's coding standards.
```yaml
# Good
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```
```yaml
# Bad
analyzer:
  exclude: [] # Forcing lints on generated code
```
