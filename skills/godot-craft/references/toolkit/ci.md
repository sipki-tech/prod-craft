# Continuous Integration Pipeline

Automate the validation of GDScript code through linting, formatting, testing, and export checks. Use caching and standard containerized environments to ensure fast and reproducible CI/CD execution.

## 1. Pipeline Stage Ordering
- **Reason:** Linting and formatting checks run in seconds and fail fast. Putting them at the start of the pipeline prevents longer-running unit tests (minutes) or multi-platform builds (5-10 minutes) from executing on invalid code, optimizing resource usage.

```yaml
# Good
# Pipeline sequence in .github/workflows/ci-godot.yml:
jobs:
  lint-and-format:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
      # Linting steps...

  run-tests:
    name: Headless Testing
    runs-on: ubuntu-latest
    needs: lint-and-format # Executes only if lint/format passes
    # Test steps...

  export-project:
    name: Export Build
    runs-on: ubuntu-latest
    needs: run-tests # Executes only if tests pass
    # Export steps...

# Bad
# Running export before testing, or running all steps in parallel without dependencies:
jobs:
  export:
    runs-on: ubuntu-latest # No dependency check, fails late
```

## 2. Godot CI Docker Image
- **Reason:** Testing and exporting in an environment matching the local editor version prevents platform-specific discrepancies, compile issues, and engine compatibility bugs. Godot 4.x commands require the `--headless` flag.

```yaml
# Good
env:
  GODOT_VERSION: "4.2.1"

jobs:
  run-tests:
    name: Headless Testing
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.2.1-stable
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
      - name: Run Tests Headlessly
        run: |
          godot --headless --path . -s addons/gut/gut_cmdline.gd -gdir=res://tests -gexit

# Bad
# Using mismatched Godot runner versions or standard Ubuntu runners:
run-tests:
  runs-on: ubuntu-latest
  # Missing barichello/godot-ci container, causing execution to fail if Godot is not installed
```

## 3. CI Cache Strategy
- **Reason:** Godot project startup requires re-importing assets (textures, audio, scenes) and downloading export templates, which can take several minutes. Caching these folders reduces CI runtimes by up to 80%.

```yaml
# Good
# Caching imports, templates, and pip packages:
- name: Cache Pip Packages
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-

- name: Cache Godot Import and Export Templates
  uses: actions/cache@v4
  with:
    path: |
      .godot/
      ~/.local/share/godot/export_templates/
    key: ${{ runner.os }}-godot-${{ hashFiles('project.godot') }}
    restore-keys: |
      ${{ runner.os }}-godot-

# Bad
# Downloading export templates and re-importing all assets on every pipeline run.
```

## 4. Conditional Artifact Upload
- **Reason:** Uploading artifacts for failing builds wastes storage and runs the risk of deploying broken code. Filtering builds by target branch (e.g. `main` or `release/*`) ensures release channels only get clean versions.

```yaml
# Good
# Only upload builds after tests pass and only on main/release branches:
- name: Upload Build Artifacts
  uses: actions/upload-artifact@v4
  if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/heads/release/')
  with:
    name: game-builds
    path: build/

# Bad
# Uploading artifacts for PRs or failed runs, which wastes storage and risks publishing broken code.
```

## 5. COOP/COEP Web Headers
- **Reason:** Godot 4.x Web exports rely on `SharedArrayBuffer` for multi-threading. Browsers require COOP and COEP security headers to enable this API. Configuring these headers prevents web build load failures.

```text
# Good
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
<script src="coi-serviceworker.min.js"></script>

# Bad
Content-Type: text/html
# (Missing COOP/COEP headers and service worker script, which will cause SharedArrayBuffer is not defined errors)
```


## 6. Programmatic Linter Script
- **Reason:** Custom linter scripts verify that repository files conform to standardized formatting and naming structures, running within pre-commit or CI pipeline hooks to catch errors before code reviews. Relying only on basic tools doesn't check directory recursion rules or catch empty/corrupted class structures. A custom `EditorScript` using `DirAccess` ensures all assets and code modules comply with custom design guidelines.

```gdscript
# Good
extends EditorScript

const TARGET_DIRECTORY: String = "res://"

var linter_failed: bool = false


func _run() -> void:
	var dir: DirAccess = DirAccess.open(TARGET_DIRECTORY)
	
	if dir:
		scan_directory(dir, TARGET_DIRECTORY)
	else:
		printerr("Linter Error: Unable to open project directory.")
		linter_failed = true
	
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	
	if linter_failed:
		scene_tree.quit(1)
	else:
		scene_tree.quit(0)


func scan_directory(dir: DirAccess, path: String) -> void:
	var err: Error = dir.list_dir_begin()
	
	if err != OK:
		printerr("Linter Error: Cannot read directory contents.")
		linter_failed = true
		return
	
	var item_name: String = dir.get_next()
	
	while item_name != "":
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue
		
		var full_path: String = path.path_join(item_name)
		
		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(full_path)
			
			if sub_dir:
				scan_directory(sub_dir, full_path)
		else:
			validate_file(item_name, full_path)
		
		item_name = dir.get_next()
	
	dir.list_dir_end()


func validate_file(file_name: String, full_path: String) -> void:
	if file_name.ends_with(".gd"):
		var regex: RegEx = RegEx.new()
		var regex_err: Error = regex.compile("^[a-z0-9_]+\\.gd$")
		
		if regex_err != OK:
			printerr("Linter Error: Regex compilation failed.")
			linter_failed = true
			return
		
		if not regex.search(file_name):
			printerr("Linter Error: Script name '%s' is not snake_case." % full_path)
			linter_failed = true
		
		var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
		
		if file:
			var content: String = file.get_as_text().strip_edges()
			file.close()
			
			if content.is_empty():
				printerr("Linter Error: Script '%s' contains an empty class." % full_path)
				linter_failed = true
		else:
			printerr("Linter Error: Cannot open script file '%s'." % full_path)
			linter_failed = true


# Bad
extends EditorScript

const TARGET_DIRECTORY: String = "res://"

var linter_failed: bool = false


func _run() -> void:
	var dir: DirAccess = DirAccess.open(TARGET_DIRECTORY)
	
	if dir:
		# Bad: Fails to recurse into directories, does not use regex, and allows empty classes
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".gd") and file_name.to_lower() != file_name:
				print("Bad file: ", file_name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	
	# Bad: Always exits with code 0, masking style and structure validation failures in CI
	scene_tree.quit(0)
```

