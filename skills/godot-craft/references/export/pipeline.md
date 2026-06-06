# Export and CI/CD Pipeline

This guide covers automated game export builds using Godot's CLI, code validation checks in pipelines, and automated delivery integrations for distribution networks.

## Enforce Quality Gates in Continuous Integration Pipelines
All automated CI pipelines must execute code quality tasks (`gdformat` and `gdlint`) and unit/integration tests (`GUT` or `GdUnit4`) sequentially. The pipeline must halt immediately if any checks fail.
- **Reason:** Prevents broken code, broken tests, or syntax regressions from being compiled into distribution builds.

```yaml
# Good
# Example of a secure CI configuration segment (.github/workflows/ci.yml)
name: Continuous Integration

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Install Python and gdtoolkit
        run: |
          pip install gdtoolkit

      - name: Lint GDScript
        run: |
          gdlint .

      - name: Check Formatting
        run: |
          gdformat --check .

      - name: Run Tests (Headless)
        run: |
          # Use headless Godot to run GUT tests and fail if tests fail
          godot --headless -s addons/gut/gut_cmdline.gd --write_results

# Bad
# Build job that exports the game directly without executing linter or test checks
name: Unsafe Build Pipeline

on: [push]

jobs:
  export_game:
    runs-on: ubuntu-latest
    steps:
      - name: Export Directly
        run: |
          godot --headless --export-release "Windows Desktop" build/game.exe
```

## Use Headless Export Commands with Relative Output Directories
Execute exports headlessly in CI and scripts using `--headless` and specify output paths relative to the project workspace directory. Avoid absolute file system paths.
- **Reason:** GUI modes and local absolute file paths fail to run or target output paths correctly across different worker containers.

```bash
# Good
# Relative export path within the workspace structure
godot --headless --export-release "Linux/X11" ./builds/linux/game.x86_64

# Bad
# Running export with absolute path or relying on GUI rendering configurations
godot --export "Windows Desktop" C:\Users\Dev\Projects\game\builds\game.exe
```

## Automate Release Deployments using Platform CLI Tools
Post-export pipeline stages must use environment secrets alongside specific upload platforms (such as `butler` for itch.io or `steamcmd` for SteamPipe) to push game assets automatically.
- **Reason:** Manual builds and uploads waste development cycles and increase the chance of mismatching files or publishing bad versions.

```yaml
# Good
# Butler upload automated job in CI
deploy_itch:
  runs-on: ubuntu-latest
  needs: validate
  steps:
    - name: Download Build Artifacts
      uses: actions/download-artifact@v4
      with:
        name: linux-build
        path: ./builds/linux/

    - name: Install Butler
      run: |
        curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
        unzip butler.zip
        chmod +x butler

    - name: Push to itch.io
      env:
        BUTLER_API_KEY: ${{ secrets.ITCH_IO_API_KEY }}
      run: |
        ./butler push ./builds/linux/ developer/game-title:linux-beta

# Bad
# Relying on manual developer steps to deploy game packages
deploy_manual:
  runs-on: ubuntu-latest
  steps:
    - name: Print Reminder
      run: |
        echo "Please download the build artifact and manually upload it via the browser dashboard!"
```


## 4. Export Config Validation
Validating export configurations programmatically prevents build workflows from packaging internal tools and development assets. This verification is triggered prior to compiling distribution packages.
- **Reason:** Relying only on manual verification or string matches of export files can lead to shipping testing assets or debugging features. An `EditorScript` using `ConfigFile` parses preset parameters structurally to guarantee compliance.

```gdscript
# Good
extends EditorScript

const PRESETS_PATH: String = "res://export_presets.cfg"

var validation_failed: bool = false


func _run() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(PRESETS_PATH)
	
	if err != OK:
		printerr("Export Validator Error: Could not load export presets configuration.")
		validation_failed = true
	else:
		validate_presets(config)
	
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	
	if validation_failed:
		scene_tree.quit(1)
	else:
		scene_tree.quit(0)


func validate_presets(config: ConfigFile) -> void:
	var sections: PackedStringArray = config.get_sections()
	
	for section: String in sections:
		var name: String = config.get_value(section, "name", "") as String
		
		# If it's a release export preset, enforce strict safety checks
		if name.to_lower().contains("release") or config.get_value(section, "export_filter", "") == "all_files":
			# Ensure tests and development addons are explicitly excluded
			var exclude_filter: String = config.get_value(section, "exclude_filter", "") as String
			
			if not exclude_filter.contains("tests/*") or not exclude_filter.contains("addons/gut/*"):
				printerr("Export Validator Error: Preset '%s' does not exclude tests/GUT addons." % name)
				validation_failed = true
			
			# Ensure debug options are disabled for production safety
			if config.has_section_key(section, "custom_features"):
				var features: String = config.get_value(section, "custom_features", "") as String
				
				if features.contains("debug") or features.contains("tests"):
					printerr("Export Validator Error: Preset '%s' has active debug/test features." % name)
					validation_failed = true


# Bad
extends EditorScript

const PRESETS_PATH: String = "res://export_presets.cfg"

var validation_failed: bool = false


func _run() -> void:
	var config: ConfigFile = ConfigFile.new()
	var _err: Error = config.load(PRESETS_PATH)
	
	# Bad: Only prints configuration sections without checking filters, custom features, or test exclusions
	var sections: PackedStringArray = config.get_sections()
	
	for section: String in sections:
		var name: String = config.get_value(section, "name", "") as String
		print("Preset Name: ", name)
	
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	
	# Bad: Unconditionally returns 0, failing to block unsafe release builds in CI pipelines
	scene_tree.quit(0)
```

