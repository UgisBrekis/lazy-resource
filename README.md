# Lazy Resource
Efficient lazy loading for `Godot 4.x`. Reference resources without loading them into memory until you actually need them.


Godot Lazy Resource is a plugin that introduces a `LazyResource` wrapper. It allows you to assign any Resource(Scenes, Textures, Audio, etc.) in the inspector without triggering a load operation. This is essential for:

* Inventory Systems: Reference 1000 items without loading 1000 textures.
* Level Management: Store references to "Level 2" without loading it into RAM while playing Level 1.
* Soft References: A Godot implementation of Unreal's TSoftObjectPtr or Unity's Addressables.


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
    var scene = await next_level.load_resource_threaded()
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

@export var my_resource : LazyResource

func _ready() -> void:
	my_resource.started_loading.connect(func():
		while my_resource.get_load_progress() < 1.0:
			var progress := my_resource.get_load_progress()
			print(progress * 100.0, "%")
			await get_tree().process_frame
		
		var packed_scene := my_resource.load_resource() as PackedScene
		var node = packed_scene.instantiate()
		add_child(node)
		)
	
	my_resource.request_load()
```
