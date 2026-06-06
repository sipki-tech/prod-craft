# CI/CD and Automated Testing in Godot

Continuous integration and automated test workflows for Godot 4. This guide covers headless test runner configuration, GitHub Actions integration, memory leak validation, and clean build exports.

## 1. Headless Test Execution
- **Reason:** CI environments do not have a display server (X11/Wayland/Quartz) or GPU drivers installed. Running Godot without the `--headless` flag in such environments will cause the engine to crash on startup.

```text
# Good
# Headless execution command for GUT tests in CI/CD pipelines:
godot --headless --path . -s addons/gut/gut_cmdline.gd -gdir=res://tests -gexit

# Headless execution command for GdUnit4 tests:
godot --headless --path . -s addons/gdunit4/src/cmd/CmdCommandHandler.gd --run-tests res://tests

# Bad
# Running tests in CI without headless mode:
godot --path . -s addons/gut/gut_cmdline.gd
```

## 2. Cross-Platform CI Setup
- **Reason:** Docker-based CI runs are locked to Linux environments. Using setup actions like `chickensoft-games/setup-godot` allows executing the same test suites across Windows, macOS, and Linux runners to check for platform-specific pathing or API discrepancies while providing easy version caching.

```yaml
# Good
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v2
        with:
          version: 4.2.1

      - name: Run GUT Tests
        run: |
          godot --headless --path . -s addons/gut/gut_cmdline.gd -gdir=res://tests -gexit

# Bad
name: Test Suite
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Download Godot
        run: |
          curl -L -o godot.zip https://downloads.tuxfamily.org/godotengine/4.2.1/Godot_v4.2.1-stable_linux.x86_64.zip
          unzip godot.zip
          mv Godot_v4.2.1-stable_linux.x86_64 /usr/local/bin/godot
      - name: Run Tests
        run: godot --path . -s addons/gut/gut_cmdline.gd
```

## 3. Orphan Node Detection
- **Reason:** Orphan nodes (nodes instantiated but never freed or attached to the scene tree) indicate memory leaks. In CI, enabling strict leak validation ensures that pull requests leaking memory will fail the build, preventing degradation from reaching production.

```text
# Good
# GUT headless execution with strict orphan node checks and error exit codes:
godot --headless --path . -s addons/gut/gut_cmdline.gd -gdir=res://tests -gexit -glog=3 -gprint_orphans

# GdUnit4 automatically tracks orphan nodes and will exit with a non-zero exit code if leaks are detected:
godot --headless --path . -s addons/gdunit4/src/cmd/CmdCommandHandler.gd --run-tests res://tests

# Bad
# Disabling output or suppressing runner exit codes, allowing memory leaks to slide by:
godot --headless --path . -s addons/gut/gut_cmdline.gd -gdir=res://tests || true
```

## 4. Test Exclusion Filters
- **Reason:** Exporting test scenes, test assets, and testing scripts increases build size, exposes debug interfaces to players, and can introduce security vulnerabilities or cheats in production packages.

```ini
# Good
[preset.0]
name="Linux/X11"
platform="Linux/X11"
runnable=true
export_filter="all_files"
exclude_filter="tests/*,addons/gut/*,addons/gdunit4/*"

# Bad
# Exporting everything, including tests and test assets, to production builds:
[preset.0]
name="Linux/X11"
export_filter="all_files"
# No exclude_filter defined
```

## 5. gdignore for Tests
- **Reason:** Godot automatically scans and generates `.import` files for all files inside the project directory, which slows down project load times and bloats the repository. A `.gdignore` file tells the Godot Editor to completely ignore the folder and its contents.

```text
# Good
File structure:
  res://
    ├── tests/
    │    ├── .gdignore        # Prevents Godot from importing test mock JSONs/textures
    │    └── test_calculator.gd
    └── project.godot

# Bad
res://
  ├── tests/
  │    ├── mock_data.json       # Godot automatically imports this, creating mock_data.json.import
  │    ├── test_icon.png        # Godot automatically imports this, generating assets unnecessarily
  │    └── test_calculator.gd
  └── project.godot
```


## 6. Programmatic CI Runner
- **Reason:** Automated CI pipelines should run unit tests using a dedicated script that programmatically initializes the testing framework, manages option settings, and checks for memory issues. Relying only on raw shell commands might succeed even when test dependencies fail or orphan nodes are leaked in the background. A programmatic `EditorScript` allows full validation of test counts and object lifetimes, exiting with non-zero on any issue.

```gdscript
# Good
extends EditorScript

const TEST_DIRECTORY: String = "res://tests"

var exit_code: int = 0
var initial_orphans: int = 0


func _run() -> void:
	initial_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var gut_script: Script = load("res://addons/gut/gut.gd") as Script
	var gut: Node = gut_script.new() as Node
	
	# Configure GUT options programmatically
	gut.set("select_directory", TEST_DIRECTORY)
	gut.set("double_strategy", 1)
	gut.set("log_level", 3)
	
	scene_tree.root.add_child(gut)
	
	if gut.has_method("test_all"):
		gut.call("test_all")
	else:
		printerr("Error: GUT instance missing 'test_all' method.")
		exit_code = 1
	
	var fail_count: int = 0
	if gut.has_method("get_fail_count"):
		fail_count = gut.call("get_fail_count") as int
	else:
		printerr("Error: GUT instance missing 'get_fail_count' method.")
		exit_code = 1
		
	var has_failed: bool = fail_count > 0
	var has_orphans: bool = check_for_orphan_nodes()
	
	if has_failed or has_orphans:
		exit_code = 1
	
	gut.queue_free()
	scene_tree.quit(exit_code)


func check_for_orphan_nodes() -> bool:
	var current_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var orphan_delta: int = current_orphans - initial_orphans
	
	if orphan_delta > 0:
		printerr("Memory Leak Warning: Found %d new orphan nodes!" % orphan_delta)
		return true
	
	return false


# Bad
extends EditorScript

const TEST_DIRECTORY: String = "res://tests"

var exit_code: int = 0


func _run() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var gut_script: Script = load("res://addons/gut/gut.gd") as Script
	var gut: Node = gut_script.new() as Node
	
	# Bad: Hardcoded configuration, no orphan check, and ignores failures by quitting with 0
	scene_tree.root.add_child(gut)
	gut.call("test_all")
	scene_tree.quit(0)
```

