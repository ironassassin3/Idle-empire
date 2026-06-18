extends RefCounted
## Shared helper for the headless soak / probe tools.
##
## Running a script via `godot -s` uses a custom SceneTree main loop, in which
## Godot does NOT initialize the project autoloads. Any scene or script that
## depends on GameState / GameConfig / FormatUtil / etc. would then dereference
## null every frame. Call install() once, before loading such scenes.
##
## Keep AUTOLOADS in sync with the [autoload] section of project.godot.

const AUTOLOADS := [
	["GameConfig", "res://scripts/autoload/game_config.gd"],
	["FormatUtil", "res://scripts/autoload/format_util.gd"],
	["GameState", "res://scripts/autoload/game_state.gd"],
	["SaveManager", "res://scripts/autoload/save_manager.gd"],
	["AudioManager", "res://scripts/autoload/audio_manager.gd"],
]


static func install(tree: SceneTree) -> void:
	var root := tree.root
	for entry in AUTOLOADS:
		var node_name: String = entry[0]
		if root.has_node(NodePath(node_name)):
			continue
		var node: Node = (load(entry[1]) as GDScript).new()
		node.name = node_name
		root.add_child(node)
		# Bind the bare `GameState` / `GameConfig` identifiers for scripts that
		# were compiled against the project autoloads.
		Engine.register_singleton(node_name, node)
