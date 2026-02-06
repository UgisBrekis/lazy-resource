@tool
extends EditorPlugin

const LazyPicker = preload("picker.gd")
const LazyEditorProperty = preload("editor_property.gd")

var plugin_instance

func _enter_tree():
	plugin_instance = LazyInspectorPlugin.new()
	add_inspector_plugin(plugin_instance)

func _exit_tree():
	remove_inspector_plugin(plugin_instance)


# --- The Inspector Hook ---
class LazyInspectorPlugin extends EditorInspectorPlugin:
	func _can_handle(object):
		return true

	func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
		# Fix: We check our custom helper instead of ClassDB
		if type == TYPE_OBJECT and _is_lazy_resource(hint_string):    
			var restricted_type = "Resource"
			var script_path = _get_path_for_class(hint_string)
			if script_path:
				var script = load(script_path)
				if script and script.has_method("get_lazy_type"):
					restricted_type = script.get_lazy_type()

			add_property_editor(name, LazyEditorProperty.new(restricted_type, hint_string))
			return true
		return false

	# --- NEW HELPER FUNCTION ---
	func _is_lazy_resource(class_name_str: String) -> bool:
		# 1. Is it the base class itself?
		if class_name_str == "LazyResource": 
			return true

		# 2. Look up the script path for this class name
		var path = _get_path_for_class(class_name_str)
		if path == "": 
			return false
			
		var script = load(path)
		if not script: 
			return false

		# 3. Walk up the inheritance chain
		# We loop through parent scripts until we hit the top or find "LazyResource"
		var current_script = script
		while current_script:
			if current_script.get_global_name() == "LazyResource":
				return true
			current_script = current_script.get_base_script()
			
		return false

	func _get_path_for_class(class_name_str: String) -> String:
		for data in ProjectSettings.get_global_class_list():
			if data["class"] == class_name_str:
				return data["path"]
		return ""
	
	
