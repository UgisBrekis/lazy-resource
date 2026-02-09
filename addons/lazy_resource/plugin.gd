@tool
extends EditorPlugin

const LazyInspectorPlugin = preload("inspector_plugin.gd")

var _inspector_plugin : LazyInspectorPlugin

var _class_cache: Dictionary[String, String]


func _enter_tree():
	var file_system := EditorInterface.get_resource_filesystem()
	if not file_system.filesystem_changed.is_connected(_update_class_cache):
		file_system.filesystem_changed.connect(_update_class_cache)
		
	_inspector_plugin = LazyInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)
	
	_update_class_cache()


func _exit_tree():
	var file_system := EditorInterface.get_resource_filesystem()
	if file_system.filesystem_changed.is_connected(_update_class_cache):
		file_system.filesystem_changed.disconnect(_update_class_cache)
	
	remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin = null


func _update_class_cache() -> void:
	_class_cache.clear()
	
	var global_class_list := ProjectSettings.get_global_class_list()
	
	# Build an inheritance map { "MyClass": "ParentClass" }
	# This allows us to walk up the tree instantly.
	var inheritance_map: Dictionary[String, String] = {}
	
	for data in global_class_list:
		inheritance_map[data.class] = data.base

	# Only keep classes that inherit from LazyResource
	for data in global_class_list:
		var global_class_name := data.class as String
		
		if global_class_name == "LazyResource":
			_class_cache[global_class_name] = data.path
			continue

		# Check ancestors until we hit LazyResource or run out
		var candidate := global_class_name
		var is_lazy := false
		
		while candidate in inheritance_map:
			var parent := inheritance_map[candidate]
			
			if parent == "LazyResource":
				is_lazy = true
				break
			
			candidate = parent
		
		if is_lazy:
			_class_cache[global_class_name] = data.path

	if not _inspector_plugin:
		return
	
	_inspector_plugin.set_class_cache(_class_cache)
	
	
