# Lazy Resource
Efficient lazy loading for `Godot 4.x`. Reference resources without loading them into memory until you actually need them.

## ❔ Why Do I Need this?
### 🤔 The Problem Statement
In Godot, the standard way to reference a resource is via `@export var my_resource: Resource`. It’s fast, it’s visual, and you get a nice picker in the Inspector.

The Caveat: These are Hard References. When you load a scene containing that script, Godot is forced to load every single resource assigned in the Inspector into RAM immediately.
* Inventory Systems: 1,000 items in a database? Your game just loaded 1,000 textures on startup.
* Level Management: Want to reference "Level 2" from "Level 1"? Level 2 is now sitting in memory while you're still playing the first level.

### 🤓 The Usual Workaround (and why it's not enough)
The common solution is to export a `String` (file path) or a `UID`.

The Pro: It’s incredibly lightweight.

The Con: It’s a workflow killer. You lose the drag-and-drop experience, you lose type safety, and you end up "hardcoding" paths that break when files move. Paths don't break if you use UID, but good luck telling if you have the right resource referenced in your code by looking at the UID. That is not a great experience you're having right there.


### 💡 The Solution: LazyResource
`LazyResource` merges both approaches into a single, seamless workflow. It acts as a lightweight wrapper that stores a `UID` instead of a hard reference.

* ⚡ Lightweight: Avoids loading resources into memory until you explicitly ask for them.

* 🎨 Editor-First: Provides a custom Inspector experience that feels like native Godot—drag, drop, and browse with full type-safety.

* 🧵 Threaded by Default: Includes a built-in, non-blocking loading implementation so you don't have to write your own background-thread logic.


## 📦 Installation
* Download the latest release.
* Extract the `lazy_resources` folder into your project's `addons/` directory.
* Enable the plugin in Project > Project Settings > Plugins.


## 🚀 Usage
### 1. Basic Usage
Use the `LazyResource` type in your scripts. The inspector will show a custom picker.
``` GDScript
extends Node

# This variable holds a reference (UID) only. 
# The actual scene is NOT loaded yet.
@export var next_level: LazyResource 

func _on_portal_entered():
    # Load it when you actually need it
    var scene := await next_level.load_resource_threaded() as PackedScene
    get_tree().change_scene_to_packed(scene)
```


### 2. Type Restrictions (Recommended)
To prevent assigning a Sound to a Level slot, define strict subclasses.

Create a script `lazy_scene.gd`:
``` GDScript
class_name LazyScene extends LazyResource

static func get_lazy_type() -> String:
    return "PackedScene" # Only allow Scenes
```

Use it in your code:

``` GDScript
@export var level: LazyScene # Inspector will now reject Textures/Audio
```

### 3. Loading with Progress
``` GDScript
extends Node2D

@export var my_resource: LazyResource

func _ready() -> void:
	my_resource.started_loading.connect(func():
		while my_resource.get_load_progress() < 1.0:
			var progress := my_resource.get_load_progress()
			await get_tree().process_frame
		
		var packed_scene := my_resource.load_resource() as PackedScene
		var node := packed_scene.instantiate() as Node
		add_child(node)
		)
	
	my_resource.request_load()
```
