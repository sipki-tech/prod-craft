# Recommended `project.godot` Settings for Strict Quality

To enforce the static typing non-negotiable and catch fragile runtime errors early during compilation, add or update the following sections in your `project.godot` file at the root of the project:

```ini
[debug/gdscript/warnings]

# 1. Mandatory Declarations
untyped_declaration=2 # 0: Ignore, 1: Warn, 2: Error. Forces explicit types or static inference.

# 2. Unsafe Operations (Static typing bypass)
unsafe_property_access=2 # Error. Catches unsafe accesses on untyped objects.
unsafe_method_access=2   # Error. Disallows calling methods dynamically on untyped objects.
unsafe_cast=1            # Warning. Alert when casting cannot be statically verified.
unsafe_call_argument=1   # Warning. Alert when arguments passed to typed methods cannot be verified.

# 3. Code Cleanliness & Logic Errors
integer_division=1       # Warning. Helps prevent division errors like `3 / 2` returning `1`.
narrowing_conversion=1   # Warning. Alert when casting down (e.g., float to int) loses precision.
unused_parameter=1       # Warning. Flag variables/parameters that are declared but never read.
unused_signal=1          # Warning. Flag declared signals that have no connections or emits.
shadowed_variable=1      # Warning. Flag local variables shadowing parent scopes.
```
