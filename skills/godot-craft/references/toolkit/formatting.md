# Code Formatting with gdformat

Maintain a uniform layout across the codebase using gdformat. Configure format settings and integrate them into editor save actions and CI checks to prevent formatting drift.

## 1. gdformatrc Configuration
- **Reason:** A shared configuration file guarantees code looks identical on all developers' machines. GDScript standard prefers tabs for indentation and a 100-character line limit to optimize code readability on smaller screens and side-by-side diffs.

```gdscript
# Good
# Indent with tabs, keep lines under 100 characters (.gdformatrc)


func setup_ui_layout() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Save Complete"
	dialog.dialog_text = "Your progress has been saved successfully to the slot."
	add_child(dialog)

# Bad
# Indented with spaces, uses excessive padding, or exceeds 100 characters on a single line
func setup_ui_layout() -> void:
    var dialog := AcceptDialog.new() # Space-indented and weird spacing around =
    dialog.title = "Save Complete"
    dialog.dialog_text = "Your progress has been saved successfully to the slot. Please do not turn off your console." # Exceeds 100 chars
```

## 2. Vendor Path Exclusion
- **Reason:** Re-formatting vendor files inside the `addons/` directory causes unnecessary diff noise, invalidates third-party git histories, and may break third-party logic. Since `gdformat` does not have a native exclude argument, scripts must filter path arguments before passing them.

```text
# Good
# In Unix systems (macOS/Linux), use find with -print0 and xargs -0:
find . -type f -name "*.gd" -not -path "*/addons/*" -print0 | xargs -0 gdformat --check

# Or using git ls-files if tracked by git, filtering out addons:
git ls-files -z "*.gd" | grep -vz "^addons/" | xargs -0 gdformat --check

# Bad
# Running formatting on the whole project workspace, including vendor files:
gdformat --check .
```

## 3. Format-On-Save Hooks
- **Reason:** Automating formatting on save eliminates manual style adjustments and ensures commits are always clean. Developers do not need to remember formatting commands.

```jsonc
// Good
// Inside VS Code .vscode/settings.json:
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "geongrins.gdscript-pack",
  "[gdscript]": {
    "editor.defaultFormatter": "geongrins.gdscript-pack",
    "editor.formatOnSave": true
  }
}

// Or using run-on-save extensions (like emeraldwalk.runonsave):
{
  "emeraldwalk.runonsave": {
    "commands": [
      {
        "match": "\\.gd$",
        "cmd": "gdformat ${file}"
      }
    ]
  }
}

// Bad
// Manually running gdformat CLI on every file edit or failing CI checks due to formatting drift.
```

## 4. CI Check-Only Mode
- **Reason:** In CI, files must never be silently reformatted and committed. Instead, formatting checks must fail the pipeline, signaling to the developer that they must run `gdformat` locally.

```text
# Good
# Run with --check flag to print changes and return non-zero exit code on formatting error:
gdformat --check src/

# Bad
# Running format without --check flag in CI, which modifies local runner files without warning:
gdformat src/
```
